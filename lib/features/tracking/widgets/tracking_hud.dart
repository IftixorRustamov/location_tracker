import 'dart:ui';
import 'package:flutter/material.dart';

class TrackingHUD extends StatelessWidget {
  final bool isTracking;
  final bool isOffline;
  final Duration sessionDuration;
  final String? username;
  final VoidCallback onProfileTap;

  // NEW: Stats
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
            // --- 1. TOP BAR (Timer + GPS + Profile) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Timer & GPS Signal
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimerPanel(isTracking: isTracking, duration: sessionDuration),

                    if (isTracking) ...[
                      const SizedBox(height: 8),
                      _GpsSignalBadge(accuracy: accuracy),
                    ]
                  ],
                ),

                // Right Side: Profile
                _ProfileButton(username: username, onTap: onProfileTap),
              ],
            ),

            // --- 2. OFFLINE BADGE ---
            if (isOffline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "Offline Mode",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // --- 3. BOTTOM DASHBOARD (Live Stats) ---
            if (isTracking)
              Container(
                margin: const EdgeInsets.only(bottom: 80), // Make room for FAB
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                        label: "DISTANCE",
                        value: distanceKm.toStringAsFixed(2),
                        unit: "km"
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade300), // Divider
                    _StatItem(
                        label: "SPEED",
                        value: speedKmph.toStringAsFixed(0),
                        unit: "km/h"
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

// -----------------------------------------------------------------------------
// --- SUB-WIDGETS ---
// -----------------------------------------------------------------------------

class _TimerPanel extends StatelessWidget {
  final bool isTracking;
  final Duration duration;

  const _TimerPanel({required this.isTracking, required this.duration});

  @override
  Widget build(BuildContext context) {
    if (!isTracking) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
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
    // Logic: <10m = Excellent, <20m = Good, >20m = Poor
    Color color;
    String label;
    int bars;

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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 3,
                height: 4.0 + (index * 3), // Ascending height bars
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
                color: color
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

  const _StatItem({required this.label, required this.value, required this.unit});

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
                  color: Colors.black87
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey
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
              letterSpacing: 1.0
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
        height: 50, width: 50,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Center(
          child: Text(
            (username?.isNotEmpty == true) ? username![0].toUpperCase() : 'U',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF4CAF50)
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
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
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
    );
  }
}