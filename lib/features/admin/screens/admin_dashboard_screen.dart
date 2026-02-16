import 'package:flutter/material.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/features/admin/screens/admin_live_map_screen.dart';
import 'package:location_tracker/features/admin/screens/user_management_screen.dart';
import 'package:location_tracker/features/admin/widgets/dashboard/dashboard_empty_state.dart';
import 'package:location_tracker/features/admin/widgets/dashboard/dashboard_summary_card.dart';
import 'package:location_tracker/features/admin/widgets/dashboard/session_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminApiService _api;

  List<AdminSession> _sessions = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _api = sl<AdminApiService>();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300)); // Animation delay

    final result = await _api.getSessions(date: _selectedDate);

    if (mounted) {
      setState(() {
        _sessions = result?.content ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: SecondaryConstants.kPrimaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchSessions();
    }
  }

  void _navigateToLiveMap(AdminSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminLiveMapScreen(apiService: _api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SecondaryConstants.kBackgroundStart,
              SecondaryConstants.kBackgroundEnd,
            ],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: innerBoxIsScrolled
                  ? Colors.white
                  : Colors.transparent,
              elevation: innerBoxIsScrolled ? 2 : 0,
              iconTheme: const IconThemeData(
                color: SecondaryConstants.kBlackText,
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.people,
                      color: SecondaryConstants.kPrimaryGreen,
                    ),
                    tooltip: "Manage Team",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserManagementScreen(apiService: _api),
                        ),
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 80),
                title: Text(
                  "Fleet Dashboard",
                  style: TextStyle(
                    color: SecondaryConstants.kBlackText,
                    fontWeight: FontWeight.bold,
                    fontSize: innerBoxIsScrolled ? 20 : 24,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -20,
                      top: 40,
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: 140,
                        color: SecondaryConstants.kPrimaryGreen.withOpacity(
                          0.05,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: DashboardSummaryCard(
                        selectedDate: _selectedDate,
                        sessionCount: _sessions.length,
                        onDateTap: _pickDate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: SecondaryConstants.kPrimaryGreen,
                  ),
                )
              : RefreshIndicator(
                  color: SecondaryConstants.kPrimaryGreen,
                  onRefresh: _fetchSessions,
                  child: _sessions.isEmpty
                      ? DashboardEmptyState(onRefresh: _fetchSessions)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                          itemCount: _sessions.length,
                          separatorBuilder: (c, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 300 + (index * 50),
                              ),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: SessionCard(
                                session: _sessions[index],
                                onTap: () =>
                                    _navigateToLiveMap(_sessions[index]),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }
}
