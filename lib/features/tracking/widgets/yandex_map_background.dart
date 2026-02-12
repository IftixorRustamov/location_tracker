import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location_tracker/core/constants/secondary.dart';

class YandexMapBackground extends StatefulWidget {
  final List<latlong.LatLng> polylineCoordinates;
  final latlong.LatLng? currentPosition;
  final double currentHeading;

  const YandexMapBackground({
    super.key,
    required this.polylineCoordinates,
    this.currentPosition,
    required this.currentHeading,
  });

  @override
  State<YandexMapBackground> createState() => _YandexMapBackgroundState();
}

class _YandexMapBackgroundState extends State<YandexMapBackground> {
  final Completer<YandexMapController> _controllerCompleter = Completer();

  // State
  BitmapDescriptor? _userIcon;
  bool _isAutoFollowing = true;

  // Cache
  MapObject? _routeLine;
  MapObject? _userMarker;
  MapObject? _accuracyCircle;

  @override
  void initState() {
    super.initState();
    _loadUserIcon();
  }

  Future<void> _loadUserIcon() async {
    try {
      // Ensure the key in your constants matches 'assets/user_arrow.png'
      final icon = BitmapDescriptor.fromAssetImage(SecondaryConstants.userArrow);
      setState(() => _userIcon = icon);
    } catch (e) {
      debugPrint("⚠️ Asset error: $e");
    }
  }

  @override
  void didUpdateWidget(covariant YandexMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool routeChanged = oldWidget.polylineCoordinates.length != widget.polylineCoordinates.length;
    bool posChanged = oldWidget.currentPosition != widget.currentPosition;
    bool headingChanged = (oldWidget.currentHeading - widget.currentHeading).abs() > 1.0;

    if (routeChanged || posChanged || headingChanged) {
      _updateMapObjects(routeChanged: routeChanged);
    }

    if (posChanged && _isAutoFollowing) {
      _moveCamera();
    }
  }

  void _updateMapObjects({bool routeChanged = false}) {
    // 1. ALWAYS Update Route Line (if coordinates exist)
    if (routeChanged && widget.polylineCoordinates.isNotEmpty) {
      _routeLine = PolylineMapObject(
        mapId: const MapObjectId('route_line'),
        polyline: Polyline(
          points: widget.polylineCoordinates
              .map((e) => Point(latitude: e.latitude, longitude: e.longitude))
              .toList(),
        ),
        strokeColor: Colors.blue,
        strokeWidth: 5.0,
        outlineColor: Colors.white,
        outlineWidth: 1.0,
      );
    }

    // 2. LOGIC SWITCH: Live Tracking vs. History View
    if (widget.currentPosition != null) {
      // --- A. LIVE MODE ---
      final point = Point(
        latitude: widget.currentPosition!.latitude,
        longitude: widget.currentPosition!.longitude,
      );

      // (i) Accuracy Halo
      _accuracyCircle = CircleMapObject(
        mapId: const MapObjectId('accuracy_halo'),
        circle: Circle(center: point, radius: 20),
        strokeColor: Colors.blue.withOpacity(0.3),
        strokeWidth: 1,
        fillColor: Colors.blue.withOpacity(0.15),
      );

      // (ii) User Arrow (or Fallback)
      if (_userIcon != null) {
        _userMarker = PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: point,
          direction: widget.currentHeading,
          opacity: 1,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: _userIcon!,
              rotationType: RotationType.rotate,
              scale: 0.3,
              anchor: const Offset(0.5, 0.5),
            ),
          ),
        );
      } else {
        _userMarker = CircleMapObject(
          mapId: const MapObjectId('user_location_fallback'),
          circle: Circle(center: point, radius: 8),
          strokeColor: Colors.white,
          strokeWidth: 2,
          fillColor: Colors.blue,
        );
      }
    }
    else if (widget.polylineCoordinates.isNotEmpty) {
      // --- B. HISTORY MODE (No User Position) ---
      // We hide the user arrow/halo and show Start/End flags instead.

      // Clear live objects to avoid ghosts
      _accuracyCircle = null;

      final startPoint = widget.polylineCoordinates.first;
      final endPoint = widget.polylineCoordinates.last;

      // (i) Start Marker (Green Dot)
      // Re-using _userMarker variable for the Start Point to save memory,
      // or you can create a new MapObject variable if you prefer.
      _userMarker = CircleMapObject(
        mapId: const MapObjectId('start_point'),
        circle: Circle(
            center: Point(latitude: startPoint.latitude, longitude: startPoint.longitude),
            radius: 6
        ),
        strokeColor: Colors.white,
        strokeWidth: 2,
        fillColor: Colors.green, // Green for Start
      );

      // (ii) End Marker (Red Dot)
      // Note: You need to add `MapObject? _endMarker;` to your state variables to use this!
      // If you haven't added it yet, add it to the top of the class.
      _accuracyCircle = CircleMapObject(
        mapId: const MapObjectId('end_point'), // Re-using accuracy circle slot for End Point
        circle: Circle(
            center: Point(latitude: endPoint.latitude, longitude: endPoint.longitude),
            radius: 6
        ),
        strokeColor: Colors.white,
        strokeWidth: 2,
        fillColor: Colors.red, // Red for Stop
      );
    }

    setState(() {});
  }

  Future<void> _moveCamera() async {
    final controller = await _controllerCompleter.future;

    // CASE 1: Live Tracking (Snap to User)
    if (widget.currentPosition != null) {
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(
              latitude: widget.currentPosition!.latitude,
              longitude: widget.currentPosition!.longitude,
            ),
            zoom: 17,
            tilt: 0,
            azimuth: widget.currentHeading,
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.linear, duration: 0.5),
      );
    }
    // CASE 2: History View (Fit Whole Route)
    else if (widget.polylineCoordinates.isNotEmpty) {
      // Create a geometry from the list of points
      final geometry = Geometry.fromPolyline(
        Polyline(
          points: widget.polylineCoordinates
              .map((e) => Point(latitude: e.latitude, longitude: e.longitude))
              .toList(),
        ),
      );

      // Move camera to fit the geometry (with padding)
      await controller.moveCamera(
        CameraUpdate.newGeometry(geometry),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
      );
    }
  }

  void _onMapCameraPositionChanged(CameraPosition position, CameraUpdateReason reason, bool finished) {
    if (reason == CameraUpdateReason.gestures) {
      if (_isAutoFollowing) {
        setState(() => _isAutoFollowing = false);
      }
    }
  }

  void recenter() {
    setState(() => _isAutoFollowing = true);
    _moveCamera();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Detect System Theme
    final bool isNightMode = MediaQuery.of(context).platformBrightness == Brightness.dark;

    final List<MapObject> mapObjects = [
      if (_routeLine != null) _routeLine!,
      if (_accuracyCircle != null) _accuracyCircle!,
      if (_userMarker != null) _userMarker!,
    ];

    return Stack(
      children: [
        YandexMap(
          onMapCreated: (controller) {
            _controllerCompleter.complete(controller);
            _updateMapObjects(routeChanged: true);
            if (widget.currentPosition != null) _moveCamera();
          },
          mapObjects: mapObjects,
          onCameraPositionChanged: _onMapCameraPositionChanged,

          // 2. Apply Dynamic Theme
          nightModeEnabled: isNightMode,

          logoAlignment: const MapAlignment(
            horizontal: HorizontalAlignment.left,
            vertical: VerticalAlignment.bottom,
          ),
        ),

        if (!_isAutoFollowing)
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton.small(
              // 3. Adaptive Button Colors
              backgroundColor: isNightMode ? const Color(0xFF333333) : Colors.white,
              onPressed: recenter,
              child: Icon(
                  Icons.my_location,
                  color: isNightMode ? Colors.blueAccent : Colors.blue
              ),
            ),
          ),
      ],
    );
  }
}