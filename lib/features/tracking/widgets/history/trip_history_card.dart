import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// IMPROVEMENTS:
/// 1. ✅ Shows distance and duration (like Strava)
/// 2. ✅ Average speed calculation
/// 3. ✅ Swipe-to-delete gesture
/// 4. ✅ Better visual hierarchy
/// 5. ✅ Loading state support
/// 6. ✅ Empty/invalid data handling
class TripHistoryCard extends StatelessWidget {
  final int sessionId;
  final DateTime date;
  final double? distanceKm;
  final int? durationSeconds;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isLoading;

  const TripHistoryCard({
    super.key,
    required this.sessionId,
    required this.date,
    required this.onTap,
    this.distanceKm,
    this.durationSeconds,
    this.onDelete,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(sessionId),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (_) async {
        // Show confirmation before delete
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Trip?'),
            content: const Text(
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return result ?? false;
      },
      onDismissed: (_) {
        onDelete?.call();
      },
      background: _buildDismissBackground(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isLoading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isLoading
                  ? _buildLoadingState()
                  : _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(date);
    final dateStr = DateFormat('MMM dd, yyyy').format(date);

    final distance = distanceKm ?? 0.0;
    final duration = durationSeconds ?? 0;
    final avgSpeed = duration > 0
        ? (distance / (duration / 3600)).clamp(0, 999)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CAF50),
                    const Color(0xFF66BB6A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.near_me_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Title & Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trip #$sessionId",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[300],
            ),
          ],
        ),

        // Stats Section (only if data exists)
        if (distance > 0 || duration > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Distance
                Expanded(
                  child: _StatItem(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: '${distance.toStringAsFixed(2)} km',
                    color: const Color(0xFF4CAF50),
                  ),
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),

                // Duration
                Expanded(
                  child: _StatItem(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: _formatDuration(duration),
                    color: const Color(0xFF2196F3),
                  ),
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),

                // Avg Speed
                Expanded(
                  child: _StatItem(
                    icon: Icons.speed,
                    label: 'Avg Speed',
                    value: '${avgSpeed.toStringAsFixed(1)} km/h',
                    color: const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 150,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(
        Icons.delete_outline,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '--';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${secs}s';
    }
  }
}

// ==========================================
// STAT ITEM WIDGET
// ==========================================

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}