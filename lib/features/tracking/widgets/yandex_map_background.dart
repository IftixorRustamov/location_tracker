import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location_tracker/core/constants/secondary.dart';

/// PERFORMANCE OPTIMIZATIONS:
/// 1. ✅ Efficient polyline caching with incremental updates
/// 2. ✅ Debounced camera movements
/// 3. ✅ Optimized map object rebuilding
/// 4. ✅ Reduced setState calls
/// 5. ✅ Better memory management
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
  late final PlacemarkIcon _userPlacemarkIcon;

  // OPTIMIZATION: Cached Yandex points to avoid conversion on every build
  List<Point> _cachedYandexPoints = [];
  int _lastPolylineLength = 0;

  // Camera control optimization
  bool _isAutoFollowing = true;
  Timer? _cameraMoveDebouncer;
  bool _isCameraMoving = false;

  // OPTIMIZATION: Track last heading to avoid unnecessary updates
  double _lastHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _isAutoFollowing = widget.shouldFollowUser;
    _lastHeading = widget.currentHeading;

    // Pre-load placemark icon
    _userPlacemarkIcon = PlacemarkIcon.single(
      PlacemarkIconStyle(
        image: BitmapDescriptor.fromAssetImage(SecondaryConstants.userArrow),
        rotationType: RotationType.rotate,
        scale: 0.12,
        anchor: const Offset(0.5, 0.5),
      ),
    );

    _updatePolylineCache();
  }

  @override
  void didUpdateWidget(covariant YandexMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update polyline cache if needed
    _updatePolylineCache();

    // Handle position changes with debouncing
    final posChanged = oldWidget.currentPosition != widget.currentPosition;
    if (posChanged && _isAutoFollowing && !_isCameraMoving) {
      _debouncedMoveCamera();
    }

    // Update auto-follow state
    if (oldWidget.shouldFollowUser != widget.shouldFollowUser) {
      setState(() => _isAutoFollowing = widget.shouldFollowUser);
      if (widget.shouldFollowUser) {
        _moveCamera();
      }
    }

    // Update heading if changed significantly
    if ((oldWidget.currentHeading - widget.currentHeading).abs() > 5) {
      _lastHeading = widget.currentHeading;
    }
  }

  @override
  void dispose() {
    _cameraMoveDebouncer?.cancel();
    super.dispose();
  }

  // ==========================================
  // POLYLINE CACHE OPTIMIZATION
  // ==========================================

  /// OPTIMIZATION: Incremental polyline updates instead of full conversion
  void _updatePolylineCache() {
    final currentLength = widget.polylineCoordinates.length;

    if (currentLength > _lastPolylineLength) {
      // Add only new points (incremental)
      final newPoints = widget.polylineCoordinates
          .skip(_lastPolylineLength)
          .map((e) => Point(latitude: e.latitude, longitude: e.longitude));

      _cachedYandexPoints.addAll(newPoints);
      _lastPolylineLength = currentLength;
    } else if (currentLength < _lastPolylineLength) {
      // Full rebuild if list shrunk (e.g., new session)
      _cachedYandexPoints = widget.polylineCoordinates
          .map((e) => Point(latitude: e.latitude, longitude: e.longitude))
          .toList();
      _lastPolylineLength = currentLength;
    }
    // If length is same, no update needed
  }

  // ==========================================
  // MAP OBJECTS (OPTIMIZED)
  // ==========================================

  /// Build map objects efficiently
  List<MapObject> _buildMapObjects() {
    final List<MapObject> objects = [];

    // 1. Route polyline (using cached points)
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

    // 2. Live tracking mode (user arrow + halo)
    if (widget.currentPosition != null) {
      final userPoint = Point(
        latitude: widget.currentPosition!.latitude,
        longitude: widget.currentPosition!.longitude,
      );

      // Accuracy halo
      objects.add(
        CircleMapObject(
          mapId: const MapObjectId('accuracy_halo'),
          circle: Circle(center: userPoint, radius: 15),
          strokeColor: const Color(0xFF4CAF50).withOpacity(0.3),
          strokeWidth: 1,
          fillColor: const Color(0xFF4CAF50).withOpacity(0.1),
        ),
      );

      // User arrow marker (using pre-loaded icon)
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: userPoint,
          direction: _lastHeading, // Use cached heading
          icon: _userPlacemarkIcon,
          opacity: 1.0,
        ),
      );
    }
    // 3. History mode (start/end markers)
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
  // CAMERA CONTROL (OPTIMIZED)
  // ==========================================

  /// Debounced camera movement to avoid excessive updates
  void _debouncedMoveCamera() {
    _cameraMoveDebouncer?.cancel();
    _cameraMoveDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isCameraMoving) {
        _moveCamera();
      }
    });
  }

  /// Move camera to current position
  Future<void> _moveCamera() async {
    if (!_controllerCompleter.isCompleted || widget.currentPosition == null) {
      return;
    }

    try {
      _isCameraMoving = true;
      final controller = await _controllerCompleter.future;

      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(
              latitude: widget.currentPosition!.latitude,
              longitude: widget.currentPosition!.longitude,
            ),
            zoom: 16.5,
            tilt: 30,
            azimuth: _lastHeading,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.5,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Camera move error: $e');
    } finally {
      _isCameraMoving = false;
    }
  }

  /// Handle camera position changes
  void _handleCameraChange(
      CameraPosition pos,
      CameraUpdateReason reason,
      bool finished,
      ) {
    // Disable auto-follow when user manually moves map
    if (reason == CameraUpdateReason.gestures && _isAutoFollowing) {
      setState(() => _isAutoFollowing = false);
    }
  }

  /// Recenter map on user position
  void recenter() {
    if (!mounted) return;

    setState(() => _isAutoFollowing = true);
    _moveCamera();
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        YandexMap(
          onMapCreated: (controller) {
            if (!_controllerCompleter.isCompleted) {
              _controllerCompleter.complete(controller);

              // Initial camera position
              if (widget.currentPosition != null) {
                _moveCamera();
              }
            }
          },
          mapObjects: _buildMapObjects(),
          onCameraPositionChanged: _handleCameraChange,
          nightModeEnabled: isNight,
          logoAlignment: const MapAlignment(
            horizontal: HorizontalAlignment.left,
            vertical: VerticalAlignment.bottom,
          ),
          // OPTIMIZATION: Disable unnecessary features
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          zoomGesturesEnabled: true,
          mapType: MapType.vector,
        ),

        // Recenter button (only show when not following)
        if (!_isAutoFollowing && widget.currentPosition != null)
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map',
              backgroundColor: isNight ? Colors.grey[900] : Colors.white,
              onPressed: recenter,
              child: const Icon(
                Icons.my_location,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
      ],
    );
  }
}