import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:intl/intl.dart';

class DashboardSummaryCard extends StatelessWidget {
  final DateTime selectedDate;
  final int sessionCount;
  final VoidCallback onDateTap;

  const DashboardSummaryCard({
    super.key,
    required this.selectedDate,
    required this.sessionCount,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy').format(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SecondaryConstants.kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: SecondaryConstants.kShadow,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          //* Date Picker Trigger
          InkWell(
            onTap: onDateTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SecondaryConstants.kPrimaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: SecondaryConstants.kPrimaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Selected Date",
                      style: TextStyle(
                        fontSize: 10,
                        color: SecondaryConstants.kGreyText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: SecondaryConstants.kBlackText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          //* Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SecondaryConstants.kPrimaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$sessionCount Active",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
