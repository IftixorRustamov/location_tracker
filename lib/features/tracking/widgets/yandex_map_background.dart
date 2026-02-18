import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:yandex_mapkit/yandex_mapkit.dart';

class YandexMapBackground extends StatefulWidget {
  // We take the raw list from the controller
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

  bool _isAutoFollowing = true;
  bool _isCameraMoving = false;

  @override
  void initState() {
    super.initState();
    _isAutoFollowing = widget.shouldFollowUser;
  }

  @override
  void didUpdateWidget(covariant YandexMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update Follow Mode
    if (widget.shouldFollowUser != oldWidget.shouldFollowUser) {
      setState(() => _isAutoFollowing = widget.shouldFollowUser);
    }

    // Move Camera if following
    if (_isAutoFollowing && widget.currentPosition != oldWidget.currentPosition) {
      _moveCamera();
    }
  }

  Future<void> _moveCamera() async {
    if (!_controllerCompleter.isCompleted || widget.currentPosition == null) return;
    if (_isCameraMoving) return;

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
            zoom: 18.0, // Close zoom for indoor testing
            tilt: 0,
            azimuth: widget.currentHeading,
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.linear, duration: 0.2),
      );
    } catch (_) {
    } finally {
      _isCameraMoving = false;
    }
  }

  List<MapObject> _buildMapObjects() {
    final List<MapObject> objects = [];

    if (widget.polylineCoordinates.isNotEmpty) {
      final List<Point> points = widget.polylineCoordinates
          .map((e) => Point(latitude: e.latitude, longitude: e.longitude))
          .toList();

      objects.add(
        PolylineMapObject(
          mapId: const MapObjectId('route_line'),
          polyline: Polyline(points: points),
          strokeColor: const Color(0xFF2196F3),
          strokeWidth: 6.0,
          outlineColor: Colors.white,
          outlineWidth: 2.0,
        ),
      );
    }

    return objects;
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(
      onMapCreated: (controller) async {
        _controllerCompleter.complete(controller);
        await controller.toggleUserLayer(visible: true);
        if (widget.currentPosition != null) _moveCamera();
      },
      onUserLocationAdded: (UserLocationView view) async => view,
      mapObjects: _buildMapObjects(),
      onCameraPositionChanged: (pos, reason, finished) {
        if (reason == CameraUpdateReason.gestures) {
          setState(() => _isAutoFollowing = false);
        }
      },
    );
  }
}