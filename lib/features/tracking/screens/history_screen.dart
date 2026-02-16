import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/local_db_service.dart'; // Adjust path
import 'package:location_tracker/features/tracking/screens/session_map_screen.dart'; // Adjust path
import 'package:location_tracker/features/tracking/widgets/history/history_empty_state.dart';
import 'package:location_tracker/features/tracking/widgets/history/trip_history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final sessions = await LocalDatabase.instance.getAllSessions();

    if (mounted) {
      setState(() {
        _sessions = List.from(sessions.reversed);
        _isLoading = false;
      });
    }
  }

  Future<void> _onSessionTap(
    int sessionId,
    DateTime date,
    Map<String, dynamic> session,
  ) async {
    final pointsData = await LocalDatabase.instance.getPointsForSession(
      sessionId,
    );

    if (!mounted) return;

    if (pointsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No GPS data found for this trip."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final latLngList = pointsData.map((p) => LatLng(p.lat, p.lon)).toList();
    final distanceKm = (session['distance'] as num?)?.toDouble() ?? 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionMapScreen(
          sessionId: sessionId,
          date: date,
          routePoints: latLngList,
          totalDistanceKm: distanceKm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Collapsible App Bar
          const SliverAppBar(
            expandedHeight: 100.0,
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black87),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                "Trip History",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),

          // 2. List Content
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: SecondaryConstants.kPrimaryGreen,
                ),
              ),
            )
          else if (_sessions.isEmpty)
            const SliverFillRemaining(child: HistoryEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final session = _sessions[index];
                  final int id = session['id'] as int;
                  final String ts = session['timestamp'] ?? '';
                  final DateTime date = DateTime.tryParse(ts) ?? DateTime.now();

                  // Staggered Animation
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 400 + (index * 100)),
                    curve: Curves.easeOutQuad,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)), // Slide up
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: TripHistoryCard(
                      sessionId: id,
                      date: date,
                      onTap: () => _onSessionTap(id, date, session),
                    ),
                  );
                }, childCount: _sessions.length),
              ),
            ),
        ],
      ),
    );
  }
}
