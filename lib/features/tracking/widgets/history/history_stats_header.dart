import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class HistoryStatsHeader extends StatelessWidget {
  final int totalTrips;
  final double totalDistanceKm;
  final int totalDurationSeconds;

  const HistoryStatsHeader({
    super.key,
    required this.totalTrips,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final avgDistance = totalTrips > 0
        ? (totalDistanceKm / totalTrips).toStringAsFixed(1)
        : '0.0';

    final totalHours = totalDurationSeconds / 3600;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SecondaryConstants.kPrimaryGreen,
            SecondaryConstants.kPrimaryGreen.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SecondaryConstants.kPrimaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stats Grid
          Row(
            children: [
              // Total Trips
              Expanded(
                child: _StatsCard(
                  icon: Icons.directions_car,
                  value: totalTrips.toString(),
                  label: 'Trips',
                ),
              ),
              const SizedBox(width: 12),

              // Total Distance
              Expanded(
                child: _StatsCard(
                  icon: Icons.straighten,
                  value: totalDistanceKm.toStringAsFixed(1),
                  label: 'Total km',
                ),
              ),
              const SizedBox(width: 12),

              // Total Time
              Expanded(
                child: _StatsCard(
                  icon: Icons.schedule,
                  value: totalHours.toStringAsFixed(1),
                  label: 'Hours',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Average Distance Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.show_chart, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Avg: $avgDistance km per trip',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STATS CARD
// ==========================================

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatsCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
