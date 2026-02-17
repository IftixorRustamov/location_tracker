import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class HistoryEmptyState extends StatefulWidget {
  const HistoryEmptyState({super.key});

  @override
  State<HistoryEmptyState> createState() => _HistoryEmptyStateState();
}

class _HistoryEmptyStateState extends State<HistoryEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
                        SecondaryConstants.kPrimaryGreen.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.route,
                    size: 80,
                    color: SecondaryConstants.kPrimaryGreen.withOpacity(0.6),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                "No trips yet",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                "Start your first trip to see it here.\n"
                    "Track your routes, distance, and more!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Action Button
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate back to home screen
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SecondaryConstants.kPrimaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),

              const SizedBox(height: 32),

              // Tips Section
              _buildTipsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: SecondaryConstants.kPrimaryGreen,
              ),
              const SizedBox(width: 8),
              const Text(
                'Quick Tips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TipItem(
            icon: Icons.play_circle_outline,
            text: 'Tap the green button to start tracking',
          ),
          const SizedBox(height: 12),
          _TipItem(
            icon: Icons.gps_fixed,
            text: 'Keep GPS enabled for accurate tracking',
          ),
          const SizedBox(height: 12),
          _TipItem(
            icon: Icons.battery_charging_full,
            text: 'App runs in background to save battery',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TIP ITEM
// ==========================================

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: SecondaryConstants.kPrimaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}