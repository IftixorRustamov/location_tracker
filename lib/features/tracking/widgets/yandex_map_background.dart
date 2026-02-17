import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location_tracker/core/constants/secondary.dart';

class YandexMapBackground extends StatefulWidget {
  final List<latlong.LatLng> polylineCoordinates;
  final latlong.LatLng? currentPosition;
  final double currentHeading;
  final bool shouldFollowUser;

  const YandexMapBackground({
    super.key,
    required this.polylineCoordinates,
    this.currentPosition,
    required this.currentHeading,
    this.shouldFollowUser = true,
  });

  @override
  State<YandexMapBackground> createState() => _YandexMapBackgroundState();
}

class _YandexMapBackgroundState extends State<YandexMapBackground> {
  final Completer<YandexMapController> _controllerCompleter = Completer();

  // 1. Cached Icon to prevent memory jitter
  late final PlacemarkIcon _userPlacemarkIcon;

  // Optimizations
  List<Point> _cachedYandexPoints = [];
  int _lastPolylineLength = 0;
  bool _isAutoFollowing = true;
  bool _isCameraMoving = false;
  Timer? _cameraMoveDebouncer;

  @override
  void initState() {
    super.initState();
    _isAutoFollowing = widget.shouldFollowUser;

    // 2. Initialize the icon ONCE here
    _userPlacemarkIcon = PlacemarkIcon.single(
      PlacemarkIconStyle(
        image: BitmapDescriptor.fromAssetImage(SecondaryConstants.userArrow),
        rotationType: RotationType.rotate, // ✅ CRITICAL: Allows arrow to turn
        scale: 0.12,
        anchor: const Offset(0.5, 0.5), // Center of the image
      ),
    );

    _updatePolylineCache();
  }

  @override
  void didUpdateWidget(covariant YandexMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    _updatePolylineCache();

    // Debounce camera moves to prevent stuttering
    if (widget.currentPosition != oldWidget.currentPosition && _isAutoFollowing) {
      _debouncedMoveCamera();
    }

    // Toggle follow mode
    if (widget.shouldFollowUser != oldWidget.shouldFollowUser) {
      setState(() => _isAutoFollowing = widget.shouldFollowUser);
      if (_isAutoFollowing) _moveCamera();
    }
  }

  @override
  void dispose() {
    _cameraMoveDebouncer?.cancel();
    super.dispose();
  }

  // ==========================================
  // OPTIMIZED POLYLINE CACHE
  // ==========================================
  void _updatePolylineCache() {
    final int currentLength = widget.polylineCoordinates.length;

    if (currentLength > _lastPolylineLength) {
      // Incremental: Only convert new points
      final newPoints = widget.polylineCoordinates
          .skip(_lastPolylineLength)
          .map((e) => Point(latitude: e.latitude, longitude: e.longitude));

      _cachedYandexPoints.addAll(newPoints);
      _lastPolylineLength = currentLength;
    } else if (currentLength < _lastPolylineLength) {
      // Reset: Full rebuild if list shrunk
      _cachedYandexPoints = widget.polylineCoordinates
          .map((e) => Point(latitude: e.latitude, longitude: e.longitude))
          .toList();
      _lastPolylineLength = currentLength;
    }
  }

  // ==========================================
  // MAP OBJECTS
  // ==========================================
  List<MapObject> _buildMapObjects() {
    final List<MapObject> objects = [];

    // 1. Route Polyline
    if (_cachedYandexPoints.isNotEmpty) {
      objects.add(
        PolylineMapObject(
          mapId: const MapObjectId('route_line'),
          polyline: Polyline(points: _cachedYandexPoints),
          strokeColor: const Color(0xFF4CAF50),
          strokeWidth: 4.5,
          outlineColor: Colors.white,
          outlineWidth: 1.5,
        ),
      );
    }

    // 2. Live Tracking Markers
    if (widget.currentPosition != null) {
      final userPoint = Point(
        latitude: widget.currentPosition!.latitude,
        longitude: widget.currentPosition!.longitude,
      );

      // Accuracy Halo (Transparent Green Circle)
      objects.add(
        CircleMapObject(
          mapId: const MapObjectId('accuracy_halo'),
          circle: Circle(center: userPoint, radius: 15),
          strokeColor: const Color(0xFF4CAF50).withOpacity(0.3),
          strokeWidth: 1,
          fillColor: const Color(0xFF4CAF50).withOpacity(0.1),
        ),
      );

      // User Arrow - ✅ Uses the Cached Icon!
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: userPoint,
          direction: (widget.currentHeading + 180) % 360,
          opacity: 1.0,
          icon: _userPlacemarkIcon, // Use the variable, don't recreate it
        ),
      );
    }
    // 3. Static Markers (History Mode)
    else if (_cachedYandexPoints.length >= 2) {
      final start = _cachedYandexPoints.first;
      final end = _cachedYandexPoints.last;

      objects.add(_buildCircleMarker('start_node', start, Colors.green));
      objects.add(_buildCircleMarker('end_node', end, Colors.red));
    }

    return objects;
  }

  CircleMapObject _buildCircleMarker(String id, Point pos, Color color) {
    return CircleMapObject(
      mapId: MapObjectId(id),
      circle: Circle(center: pos, radius: 5),
      strokeColor: Colors.white,
      strokeWidth: 2,
      fillColor: color,
    );
  }

  // ==========================================
  // CAMERA CONTROL
  // ==========================================
  void _debouncedMoveCamera() {
    if (_cameraMoveDebouncer?.isActive ?? false) return;

    _cameraMoveDebouncer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isCameraMoving) {
        _moveCamera();
      }
    });
  }

  Future<void> _moveCamera() async {
    if (!_controllerCompleter.isCompleted || widget.currentPosition == null) return;

    _isCameraMoving = true;
    try {
      final controller = await _controllerCompleter.future;
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(
              latitude: widget.currentPosition!.latitude,
              longitude: widget.currentPosition!.longitude,
            ),
            zoom: 17.5, // Good zoom level for driving
            tilt: 40,   // Tilted view for 3D effect
            azimuth: widget.currentHeading, // Rotates camera with car
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.linear, duration: 0.2),
      );
    } catch (e) {
      debugPrint("Camera move error: $e");
    } finally {
      _isCameraMoving = false;
    }
  }

  void _handleCameraChange(CameraPosition pos, CameraUpdateReason reason, bool finished) {
    // If user manually drags map, stop auto-following
    if (reason == CameraUpdateReason.gestures && _isAutoFollowing) {
      setState(() => _isAutoFollowing = false);
    }
  }

  void recenter() {
    setState(() => _isAutoFollowing = true);
    _moveCamera();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNight = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        YandexMap(
          onMapCreated: (controller) {
            _controllerCompleter.complete(controller);
            if (widget.currentPosition != null) _moveCamera();
          },
          mapObjects: _buildMapObjects(),
          onCameraPositionChanged: _handleCameraChange,
          nightModeEnabled: isNight,
          logoAlignment: const MapAlignment(
            horizontal: HorizontalAlignment.left,
            vertical: VerticalAlignment.bottom,
          ),
        ),

        // Recenter Button
        if (!_isAutoFollowing && widget.currentPosition != null)
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter_fab',
              backgroundColor: isNight ? Colors.grey[900] : Colors.white,
              onPressed: recenter,
              child: const Icon(Icons.my_location, color: Color(0xFF4CAF50)),
            ),
          ),
      ],
    );
  }
}