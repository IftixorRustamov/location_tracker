import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';

class SessionCard extends StatelessWidget {
  final AdminSession session;
  final VoidCallback onTap;

  const SessionCard({super.key, required this.session, required this.onTap});

  String _getSafeId(String? id) {
    if (id == null || id.isEmpty) return "N/A";
    if (id.length < 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SecondaryConstants.kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: SecondaryConstants.kShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.drive_eta, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 16),

                // Text Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name.isNotEmpty ? session.name : "Unknown Driver",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: SecondaryConstants.kBlackText
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.tag, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            "ID: ${_getSafeId(session.id)}",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontFamily: 'monospace'
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}