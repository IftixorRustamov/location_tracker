import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class MapBackground extends StatelessWidget {
  final MapController mapController;
  final List<LatLng> polylineCoordinates;
  final LatLng? currentPosition;
  final double currentHeading;

  const MapBackground({
    super.key,
    required this.mapController,
    required this.polylineCoordinates,
    required this.currentPosition,
    required this.currentHeading,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(41.31, 69.24),
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.location_tracker',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: polylineCoordinates,
              strokeWidth: 6,
              color: Colors.blueAccent,
              borderColor: const Color(0xFF1565C0),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        if (currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentPosition!,
                width: 80,
                height: 80,
                child: _buildRotatingMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRotatingMarker() {
    return Transform.rotate(
      angle: (currentHeading * (math.pi / 180) ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          const Icon(Icons.navigation, size: 40, color: Colors.blue),
        ],
      ),
    );
  }
}
