import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final bool isAdmin;

  const UserAvatar({super.key, required this.name, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // 1. Creative Gradients
    final Gradient backgroundGradient = isAdmin
        ? const LinearGradient(
      colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : const LinearGradient(
      colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final Color accentColor = isAdmin ? Colors.redAccent : Colors.blueAccent;
    final String initials = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Stack(
      children: [
        // Main Avatar Circle
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: backgroundGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: accentColor,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
            ),
          ),
        ),

        // Optional: Admin Badge / Status Dot
        if (isAdmin)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  )
                ],
              ),
              child: const Icon(
                Icons.star,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}