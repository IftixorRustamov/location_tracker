import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';

class RecenterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RecenterButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SecondaryConstants.kWhite,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: SecondaryConstants.kShadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: SecondaryConstants.kWhite,
        elevation: 0,
        child: const Icon(Icons.my_location, color: SecondaryConstants.kPrimaryGreen),
      ),
    );
  }
}