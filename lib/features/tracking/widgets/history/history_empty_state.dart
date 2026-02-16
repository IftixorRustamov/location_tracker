import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off_rounded,
              size: 64,
              color: SecondaryConstants.kPrimaryGreen.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No trips recorded yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start driving to see your history here.",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
