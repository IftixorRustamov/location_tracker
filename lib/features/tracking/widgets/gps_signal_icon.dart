import 'package:flutter/material.dart';

class GpsSignalIcon extends StatelessWidget {
  final double accuracy; // Lower is better (in meters)

  const GpsSignalIcon({super.key, required this.accuracy});

  @override
  Widget build(BuildContext context) {
    // Determine Signal Strength
    // < 10m: Excellent (Green)
    // 10m - 20m: Good (Yellow)
    // > 20m: Poor (Red)

    Color color;
    int bars;

    if (accuracy <= 10) {
      color = Colors.green;
      bars = 4;
    } else if (accuracy <= 20) {
      color = Colors.orange;
      bars = 3;
    } else {
      color = Colors.red;
      bars = 1;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 4,
              height: 4 + (index * 4), // 4, 8, 12, 16 height
              decoration: BoxDecoration(
                color: index < bars ? color : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        Text(
          accuracy > 20 ? 'WEAK' : 'GPS',
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
        )
      ],
    );
  }
}