import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class DashboardEmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const DashboardEmptyState({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SecondaryConstants.kWhite,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          const Text(
            "No active trips found",
            style: TextStyle(
              fontSize: 18,
              color: SecondaryConstants.kBlackText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select a different date or refresh.",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh,
              color: SecondaryConstants.kPrimaryGreen,
            ),
            label: const Text(
              "Refresh Data",
              style: TextStyle(
                color: SecondaryConstants.kPrimaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
