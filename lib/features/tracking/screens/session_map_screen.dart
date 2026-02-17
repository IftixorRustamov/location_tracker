import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location_tracker/core/constants/secondary.dart'; // Ensure you have your constants

class SessionMapScreen extends StatefulWidget {
  final int sessionId;
  final DateTime date;
  final List<latlong.LatLng> routePoints;
  final double totalDistanceKm;

  const SessionMapScreen({
    super.key,
    required this.sessionId,
    required this.date,
    required this.routePoints,
    required this.totalDistanceKm,
  });

  @override
  State<SessionMapScreen> createState() => _SessionMapScreenState();
}

class _SessionMapScreenState extends State<SessionMapScreen> {
  final Completer<YandexMapController> _controllerCompleter = Completer();

  @override
  Widget build(BuildContext context) {
    // Determine map style based on system theme
    final bool isNight = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Trip Details", style: TextStyle(fontSize: 16)),
            Text(
              "${widget.totalDistanceKm.toStringAsFixed(2)} km • ${widget.date.toString().split(' ')[0]}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (controller) {
              _controllerCompleter.complete(controller);
              // 🚀 AUTO-ZOOM: Trigger zoom when map is ready
              _zoomToRoute(controller);
            },
            mapObjects: _buildMapObjects(),
            nightModeEnabled: isNight,
            logoAlignment: const MapAlignment(
              horizontal: HorizontalAlignment.left,
              vertical: VerticalAlignment.bottom,
            ),
          ),

          // Optional: Floating Button to re-center if user pans away
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(Icons.center_focus_strong, color: Colors.black87),
              onPressed: () async {
                final controller = await _controllerCompleter.future;
                _zoomToRoute(controller);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🗺️ MAP OBJECTS (Polyline + Markers)
  // ==========================================
  List<MapObject> _buildMapObjects() {
    if (widget.routePoints.isEmpty) return [];

    final objects = <MapObject>[];

    // 1. The Route Line
    objects.add(
      PolylineMapObject(
        mapId: const MapObjectId('session_polyline'),
        polyline: Polyline(
          points: widget.routePoints
              .map((p) => Point(latitude: p.latitude, longitude: p.longitude))
              .toList(),
        ),
        strokeColor: Colors.blueAccent, // Or your brand color
        strokeWidth: 4.0,
        outlineColor: Colors.white,
        outlineWidth: 1.0,
      ),
    );

    // 2. Start Marker (Green Dot)
    objects.add(
      CircleMapObject(
        mapId: const MapObjectId('start_point'),
        circle: Circle(
          center: Point(
            latitude: widget.routePoints.first.latitude,
            longitude: widget.routePoints.first.longitude,
          ),
          radius: 8,
        ),
        strokeColor: Colors.white,
        strokeWidth: 2,
        fillColor: Colors.green,
      ),
    );

    // 3. End Marker (Red Dot)
    objects.add(
      CircleMapObject(
        mapId: const MapObjectId('end_point'),
        circle: Circle(
          center: Point(
            latitude: widget.routePoints.last.latitude,
            longitude: widget.routePoints.last.longitude,
          ),
          radius: 8,
        ),
        strokeColor: Colors.white,
        strokeWidth: 2,
        fillColor: Colors.red,
      ),
    );

    return objects;
  }

  // ==========================================
  // 🔍 AUTO-ZOOM LOGIC
  // ==========================================
  Future<void> _zoomToRoute(YandexMapController controller) async {
    if (widget.routePoints.isEmpty) return;

    // 1. Calculate Bounds
    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLon = widget.routePoints.first.longitude;
    double maxLon = widget.routePoints.first.longitude;

    for (var point in widget.routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    // 2. Create Bounding Box
    final boundingBox = BoundingBox(
      northEast: Point(latitude: maxLat, longitude: maxLon),
      southWest: Point(latitude: minLat, longitude: minLon),
    );

    // 3. Move Camera
    await controller.moveCamera(
      CameraUpdate.newBounds(
        boundingBox,
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
    );
  }
}