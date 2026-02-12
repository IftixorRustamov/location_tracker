import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_tracker/features/tracking/widgets/yandex_map_background.dart';

class SessionMapScreen extends StatelessWidget {
  final int sessionId;
  final DateTime date;
  final List<LatLng> routePoints;
  final double totalDistanceKm;

  const SessionMapScreen({
    super.key,
    required this.sessionId,
    required this.date,
    required this.routePoints,
    this.totalDistanceKm = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Smart Distance Fallback:
    // If 0.0 was passed, calculate it manually from the points.
    final double displayDistance = (totalDistanceKm > 0)
        ? totalDistanceKm
        : _calculateDistance(routePoints);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)]
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
        ),
      ),
      body: Stack(
        children: [
          // 2. The Map (History Mode)
          // passing null for currentPosition triggers "History Mode" (Fit Route)
          YandexMapBackground(
            polylineCoordinates: routePoints,
            currentPosition: null,
            currentHeading: 0.0,
          ),

          // 3. Bottom Summary Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Session #$sessionId",
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)
                        ),
                        child: const Text(
                          "COMPLETED",
                          style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat("DISTANCE", "${displayDistance.toStringAsFixed(2)} km"),
                      _buildStat("POINTS", "${routePoints.length}"),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
        ),
        const SizedBox(height: 2),
        Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.blue)
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} • ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // Helper: Calculate total distance if DB didn't save it
  double _calculateDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    const distance = Distance();
    for (int i = 0; i < points.length - 1; i++) {
      total += distance.as(LengthUnit.Kilometer, points[i], points[i + 1]);
    }
    return total;
  }
}