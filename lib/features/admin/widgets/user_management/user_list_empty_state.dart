import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class UserListEmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const UserListEmptyState({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
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
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No team members found",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try pulling down to refresh the list.",
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
              "Refresh List",
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
