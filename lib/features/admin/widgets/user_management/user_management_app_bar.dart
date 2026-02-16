import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class UserManagementAppBar extends StatelessWidget {
  final bool innerBoxIsScrolled;

  const UserManagementAppBar({
    super.key,
    required this.innerBoxIsScrolled,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,

      // 1. Center the collapsed title
      centerTitle: true,
      backgroundColor: innerBoxIsScrolled ? Colors.white : Colors.transparent,
      elevation: innerBoxIsScrolled ? 2 : 0,
      iconTheme: IconThemeData(
        color: innerBoxIsScrolled ? Colors.black87 : Colors.black87,
      ),

      // 2. The Collapsed Title (Visible ONLY when scrolled)
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: innerBoxIsScrolled ? 1.0 : 0.0,
        child: const Text(
          "Team Members",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),

      flexibleSpace: FlexibleSpaceBar(
        // 3. Remove title/padding from here to avoid the crash
        title: null,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Watermark Icon
            Positioned(
              right: -20,
              top: 40,
              child: Icon(
                Icons.people,
                size: 140,
                color: SecondaryConstants.kPrimaryGreen.withOpacity(0.05),
              ),
            ),

            // 4. The Expanded Title (Part of the background now)
            // This mimics the "Large Title" look but scrolls away naturally
            const Positioned(
              left: 16,
              bottom: 70, // Matches your previous padding
              child: Text(
                "Team Members",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 24, // Larger font for expanded state
                ),
              ),
            ),

            // Search Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      "Search member...",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}