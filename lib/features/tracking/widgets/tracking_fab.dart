import 'package:flutter/material.dart';

class TrackingFab extends StatelessWidget {
  final bool isTracking;
  final bool isBusy;
  final VoidCallback onPressed;

  const TrackingFab({
    super.key,
    required this.isTracking,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 56,
      child: FloatingActionButton.extended(
        onPressed: isBusy ? null : onPressed,
        backgroundColor: isTracking ? Colors.redAccent : const Color(0xFF4CAF50),
        elevation: 6,
        icon: isBusy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: isBusy
            ? const SizedBox.shrink()
            : Text(
          isTracking ? 'STOP' : 'START',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }
}