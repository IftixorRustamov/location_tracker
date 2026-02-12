import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/features/tracking/screens/session_map_screen.dart';
// Note: Ensure this model import points to where you defined your 'Session' model.
// If you don't have a specific Session model, I assume the DB returns a Map or a similar object.
// For this example, I will assume the DB returns a list of Maps or a generic Session class.

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Store the list of sessions here
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// Fetch all unique sessions from the database
  Future<void> _loadSessions() async {
    // We assume your LocalDatabase has a method like 'getAllSessions'
    // If not, you might be grouping by 'sessionId' or similar logic.
    // This is a placeholder for however you retrieve the list of trips.
    final sessions = await LocalDatabase.instance.getAllSessions();

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          // Sorting newest first
          final session = _sessions[_sessions.length - 1 - index];

          // Parsing data (Adjust keys based on your actual DB schema)
          final int sessionId = session['id'] as int;
          // Handle timestamp parsing safely
          final String timestampStr = session['timestamp'] ?? DateTime.now().toIso8601String();
          final DateTime date = DateTime.tryParse(timestampStr) ?? DateTime.now();

          // Optional: If you stored distance/duration in DB, use it. Otherwise 0.
          // final double distance = session['distance'] ?? 0.0;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car, color: Colors.blue),
              ),
              title: Text(
                "Trip #$sessionId",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  _formatDate(date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),

              // --- ON TAP LOGIC ---
              onTap: () async {
                // Show loading indicator if query is slow?
                // Ideally, show a quick loader or just await.

                // 1. Fetch points for this session
                final points = await LocalDatabase.instance.getPointsForSession(sessionId);

                if (points.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No location data found for this trip.")),
                    );
                  }
                  return;
                }

                // 2. Convert to LatLng
                final latLngList = points.map((p) => LatLng(p.lat, p.lon)).toList();

                // 3. Navigate
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionMapScreen(
                      sessionId: sessionId,
                      date: date,
                      routePoints: latLngList,
                      // Pass stored distance if you have it, else 0.0 to let screen calc it
                      totalDistanceKm: 0.0,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No trips yet",
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Start a tracking session to see it here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    // Simple formatter to avoid extra dependencies, or use package:intl
    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final String month = months[dt.month - 1];
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    return "$month ${dt.day}, ${dt.year} at $hour:$minute";
  }
}