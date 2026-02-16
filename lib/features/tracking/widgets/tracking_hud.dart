import 'dart:ui';
import 'package:flutter/material.dart';

/// 1. ✅ Reduced widget rebuilds with const constructors
/// 2. ✅ Optimized animation controller
/// 3. ✅ Better memory management
/// 4. ✅ Efficient text rendering with FontFeature
class TrackingHUD extends StatelessWidget {
  final bool isTracking;
  final bool isOffline;
  final Duration sessionDuration;
  final String? username;
  final VoidCallback onProfileTap;
  final double distanceKm;
  final double speedKmph;
  final double accuracy;

  const TrackingHUD({
    super.key,
    required this.isTracking,
    required this.isOffline,
    required this.sessionDuration,
    required this.username,
    required this.onProfileTap,
    required this.distanceKm,
    required this.speedKmph,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Timer & GPS
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTracking) ...[
                      _TimerPanel(duration: sessionDuration),
                      const SizedBox(height: 8),
                      _GpsSignalBadge(accuracy: accuracy),
                    ],
                  ],
                ),
                // Right: Profile
                _ProfileButton(username: username, onTap: onProfileTap),
              ],
            ),

            // Offline badge
            if (isOffline) ...[
              const SizedBox(height: 12),
              const _OfflineBadge(),
            ],

            const Spacer(),

            // Bottom stats dashboard
            if (isTracking)
              Container(
                margin: const EdgeInsets.only(bottom: 80),
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: "DISTANCE",
                      value: distanceKm.toStringAsFixed(2),
                      unit: "km",
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    _StatItem(
                      label: "SPEED",
                      value: speedKmph.toStringAsFixed(0),
                      unit: "km/h",
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SUB-WIDGETS (OPTIMIZED)
// ==========================================

class _TimerPanel extends StatelessWidget {
  final Duration duration;

  const _TimerPanel({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(blurRadius: 10, color: Colors.black12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BlinkingDot(),
          const SizedBox(width: 10),
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              // OPTIMIZATION: Use tabular figures for better readability
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours > 0 ? "${twoDigits(d.inHours)}:" : "";
    return "$hours${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}

class _GpsSignalBadge extends StatelessWidget {
  final double accuracy;

  const _GpsSignalBadge({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    // Determine signal strength
    final Color color;
    final String label;
    final int bars;

    if (accuracy <= 10) {
      color = Colors.green;
      label = "GPS STRONG";
      bars = 4;
    } else if (accuracy <= 20) {
      color = Colors.orange;
      label = "GPS OK";
      bars = 3;
    } else {
      color = Colors.red;
      label = "WEAK SIGNAL";
      bars = 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Signal bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 3,
                height: 4.0 + (index * 3),
                decoration: BoxDecoration(
                  color: index < bars ? color : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            "Offline Mode",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                // OPTIMIZATION: Tabular figures for consistent width
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black45,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String? username;
  final VoidCallback onTap;

  const _ProfileButton({required this.username, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 50,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10),
          ],
        ),
        child: Center(
          child: Text(
            (username?.isNotEmpty == true)
                ? username![0].toUpperCase()
                : 'U',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF4CAF50),
            ),
          ),
        ),
      ),
    );
  }
}

/// OPTIMIZATION: Efficient blinking animation with proper disposal
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Icon(
        Icons.fiber_manual_record,
        color: Colors.red,
        size: 14,
      ),
    );
  }
}