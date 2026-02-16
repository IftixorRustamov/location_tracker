import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class MapHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;

  const MapHeader({
    super.key,
    required this.title,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Back Button
            Container(
              decoration: BoxDecoration(
                color: SecondaryConstants.kWhite,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: SecondaryConstants.kShadow, blurRadius: 10),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: SecondaryConstants.kBlackText,
                ),
                onPressed: onBackPressed,
              ),
            ),
            const SizedBox(width: 16),

            // Title Pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: SecondaryConstants.kWhite,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: SecondaryConstants.kShadow,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SecondaryConstants.kBlackText,
                      ),
                      overflow: TextOverflow.ellipsis,
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
