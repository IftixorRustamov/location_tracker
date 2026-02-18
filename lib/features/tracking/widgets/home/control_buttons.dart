import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final bool shouldFollowUser;
  final VoidCallback onToggleFollow;
  final VoidCallback onCenter;

  const ControlButtons({
    super.key,
    required this.shouldFollowUser,
    required this.onToggleFollow,
    required this.onCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'follow_btn',
            backgroundColor: Colors.white,
            onPressed: onToggleFollow,
            child: Icon(
              shouldFollowUser ? Icons.near_me : Icons.near_me_disabled,
              color: shouldFollowUser ? Colors.blue : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'center_btn',
            backgroundColor: Colors.white,
            onPressed: onCenter,
            child: const Icon(Icons.my_location, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}