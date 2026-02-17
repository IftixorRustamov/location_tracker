import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/features/tracking/screens/session_map_screen.dart';
import 'package:location_tracker/features/tracking/widgets/history/history_empty_state.dart';
import 'package:location_tracker/features/tracking/widgets/history/trip_history_card.dart';
import 'package:location_tracker/features/tracking/widgets/history/history_stats_header.dart';
import 'package:intl/intl.dart';

/// IMPROVEMENTS:
/// 1. ✅ Added stats summary header (like Strava)
/// 2. ✅ Pull-to-refresh functionality
/// 3. ✅ Delete trip with confirmation
/// 4. ✅ Filter by date range
/// 5. ✅ Better loading states
/// 6. ✅ Error handling
/// 7. ✅ Optimistic UI updates
/// 8. ✅ Search functionality
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _filteredSessions = [];

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // Stats
  double _totalDistanceKm = 0.0;
  int _totalDurationSeconds = 0;
  int _tripCount = 0;

  // Filters
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load sessions with stats calculation
  Future<void> _loadSessions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Small delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 300));

      final sessions = await LocalDatabase.instance.getAllSessions();

      if (!mounted) return;

      // Calculate stats
      double totalDistance = 0.0;
      int totalDuration = 0;
      int validTrips = 0;

      for (var session in sessions) {
        final distance = (session['distance'] as num?)?.toDouble() ?? 0.0;
        final duration = (session['duration'] as int?) ?? 0;

        if (distance > 0) {
          totalDistance += distance;
          totalDuration += duration;
          validTrips++;
        }
      }

      setState(() {
        _sessions = List.from(sessions.reversed);
        _filteredSessions = List.from(_sessions);
        _totalDistanceKm = totalDistance;
        _totalDurationSeconds = totalDuration;
        _tripCount = validTrips;
        _isLoading = false;
      });

      _applyFilters();

    } catch (e) {
      debugPrint('❌ Error loading sessions: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load trip history';
      });
    }
  }

  /// Pull to refresh
  Future<void> _onRefresh() async {
    await _loadSessions();
  }

  /// Apply search and date filters
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_sessions);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((session) {
        final id = session['id'].toString();
        final timestamp = session['timestamp'] ?? '';
        final date = DateTime.tryParse(timestamp);
        final dateStr = date != null
            ? DateFormat('MMM dd, yyyy').format(date)
            : '';

        return id.contains(_searchQuery) ||
            dateStr.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Date range filter
    if (_filterStartDate != null || _filterEndDate != null) {
      filtered = filtered.where((session) {
        final timestamp = session['timestamp'] ?? '';
        final date = DateTime.tryParse(timestamp);
        if (date == null) return false;

        if (_filterStartDate != null && date.isBefore(_filterStartDate!)) {
          return false;
        }
        if (_filterEndDate != null && date.isAfter(_filterEndDate!)) {
          return false;
        }

        return true;
      }).toList();
    }

    setState(() {
      _filteredSessions = filtered;
    });
  }

  /// Show date filter dialog
  Future<void> _showDateFilterDialog() async {
    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (context) => _DateFilterDialog(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      ),
    );

    if (result != null) {
      setState(() {
        _filterStartDate = result['start'];
        _filterEndDate = result['end'];
      });
      _applyFilters();
    }
  }

  /// Clear all filters
  void _clearFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  /// Navigate to trip detail
  Future<void> _onSessionTap(
      int sessionId,
      DateTime date,
      Map<String, dynamic> session,
      ) async {
    try {
      final pointsData = await LocalDatabase.instance.getPointsForSession(
        sessionId,
      );

      if (!mounted) return;

      if (pointsData.isEmpty) {
        _showSnackBar(
          "No GPS data found for this trip.",
          isError: true,
        );
        return;
      }

      final latLngList = pointsData.map((p) => LatLng(p.lat, p.lon)).toList();
      final distanceKm = (session['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (session['duration'] as int?) ?? 0;

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
    } catch (e) {
      debugPrint('❌ Error loading trip details: $e');
      _showSnackBar('Failed to load trip details', isError: true);
    }
  }

  /// Delete trip with confirmation
  Future<void> _deleteTrip(int sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: const Text(
          'This will permanently delete this trip and all its GPS data. '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Optimistic UI update
      setState(() {
        _sessions.removeWhere((s) => s['id'] == sessionId);
        _filteredSessions.removeWhere((s) => s['id'] == sessionId);
      });

      // Delete from database
      await LocalDatabase.instance.deleteSession(sessionId);

      _showSnackBar('Trip deleted', isError: false);

      // Refresh stats
      await _loadSessions();

    } catch (e) {
      debugPrint('❌ Error deleting trip: $e');
      _showSnackBar('Failed to delete trip', isError: true);

      // Reload to restore state
      await _loadSessions();
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _filterStartDate != null ||
        _filterEndDate != null ||
        _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: SecondaryConstants.kPrimaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // App Bar with Search
            SliverAppBar(
              expandedHeight: 100.0,
              floating: true,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black87),
              flexibleSpace: const FlexibleSpaceBar(
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
              actions: [
                // Filter button
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: hasActiveFilters
                        ? SecondaryConstants.kPrimaryGreen
                        : Colors.grey,
                  ),
                  onPressed: _showDateFilterDialog,
                ),
              ],
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by trip # or date...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _applyFilters();
                  },
                ),
              ),
            ),

            // Active Filters Chip
            if (hasActiveFilters)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_filterStartDate != null || _filterEndDate != null)
                        Chip(
                          label: Text(
                            _buildDateRangeText(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () {
                            setState(() {
                              _filterStartDate = null;
                              _filterEndDate = null;
                            });
                            _applyFilters();
                          },
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                      if (_searchQuery.isNotEmpty)
                        Chip(
                          label: Text(
                            'Search: $_searchQuery',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _applyFilters();
                          },
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear all'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Stats Header
            if (!_isLoading && !_hasError && _sessions.isNotEmpty)
              SliverToBoxAdapter(
                child: HistoryStatsHeader(
                  totalTrips: _tripCount,
                  totalDistanceKm: _totalDistanceKm,
                  totalDurationSeconds: _totalDurationSeconds,
                ),
              ),

            // Loading State
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: SecondaryConstants.kPrimaryGreen,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading trips...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )

            // Error State
            else if (_hasError)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'Something went wrong',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSessions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )

            // Empty State (no trips)
            else if (_sessions.isEmpty)
                const SliverFillRemaining(
                  child: HistoryEmptyState(),
                )

              // Empty Search Results
              else if (_filteredSessions.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No trips found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  )

                // Trip List
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final session = _filteredSessions[index];
                          final int id = session['id'] as int;
                          final String ts = session['timestamp'] ?? '';
                          final DateTime date = DateTime.tryParse(ts) ??
                              DateTime.now();
                          final double distance =
                              (session['distance'] as num?)?.toDouble() ?? 0.0;
                          final int duration = (session['duration'] as int?) ?? 0;

                          // Staggered animation
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 400 + (index * 50)),
                            curve: Curves.easeOutQuad,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: TripHistoryCard(
                              sessionId: id,
                              date: date,
                              distanceKm: distance,
                              durationSeconds: duration,
                              onTap: () => _onSessionTap(id, date, session),
                              onDelete: () => _deleteTrip(id),
                            ),
                          );
                        },
                        childCount: _filteredSessions.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _buildDateRangeText() {
    if (_filterStartDate != null && _filterEndDate != null) {
      return '${DateFormat('MMM d').format(_filterStartDate!)} - '
          '${DateFormat('MMM d').format(_filterEndDate!)}';
    } else if (_filterStartDate != null) {
      return 'From ${DateFormat('MMM d').format(_filterStartDate!)}';
    } else if (_filterEndDate != null) {
      return 'Until ${DateFormat('MMM d').format(_filterEndDate!)}';
    }
    return '';
  }
}

// ==========================================
// DATE FILTER DIALOG
// ==========================================

class _DateFilterDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  const _DateFilterDialog({
    this.startDate,
    this.endDate,
  });

  @override
  State<_DateFilterDialog> createState() => _DateFilterDialogState();
}

class _DateFilterDialogState extends State<_DateFilterDialog> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startDate;
    _end = widget.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Date'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(_start != null
                ? DateFormat('MMM dd, yyyy').format(_start!)
                : 'Start Date'),
            trailing: _start != null
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _start = null),
            )
                : null,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _start ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _start = date);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(_end != null
                ? DateFormat('MMM dd, yyyy').format(_end!)
                : 'End Date'),
            trailing: _end != null
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _end = null),
            )
                : null,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _end ?? DateTime.now(),
                firstDate: _start ?? DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _end = date);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'start': _start,
              'end': _end,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}