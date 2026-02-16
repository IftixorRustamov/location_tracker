import 'dart:async';
import 'dart:isolate';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/core/services/map_matching_service.dart';
import 'package:location_tracker/data/models/location_point.dart' as data;

import 'package:location_tracker/core/config/routes.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';
import 'package:location_tracker/features/tracking/widgets/yandex_map_background.dart';
import 'package:location_tracker/features/tracking/logic/tracking_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../widgets/tracking_hud.dart';
import '../widgets/tracking_fab.dart';
import '../widgets/profile_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, TrackingManager, WidgetsBindingObserver {

  // --- Hardware Services ---
  final Location _location = Location();
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // --- Map State Notifiers ---
  final ValueNotifier<List<LatLng>> _polylineNotifier = ValueNotifier([]);
  final ValueNotifier<List<LatLng>> _smoothNotifier = ValueNotifier([]);
  final ValueNotifier<LatLng?> _currentPositionNotifier = ValueNotifier(null);
  final ValueNotifier<_TrackingStats> _statsNotifier = ValueNotifier(_TrackingStats());

  bool _shouldFollowUser = true;
  double _currentHeading = 0.0;

  // --- Location Processing ---
  final List<data.LocationPoint> _pointBuffer = [];
  LocationData? _latestLocationData;
  Timer? _uiUpdateTimer;
  Timer? _dbFlushTimer;

  static const int _minBufferSize = 20;
  static const int _maxBufferLimit = 1000;
  static const Duration _maxBufferAge = Duration(seconds: 30);
  static const Duration _uiUpdateInterval = Duration(milliseconds: 800);

  // --- Session Data ---
  String? _username;
  int? _currentSessionId;
  double _totalDistanceMeters = 0.0;
  Object? _error;
  bool _isConnected = true;

  DateTime _lastPositionUpdate = DateTime.now();
  static const Duration _minPositionUpdateInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🛑 CRITICAL FIX: Do NOT call _initialSetup() here directly.
    // It causes a race condition crashing the app.
    // Call _safeInit() instead.
    _safeInit();
  }

  /// 🛡️ SAFE INITIALIZATION SEQUENCE
  /// Prevents SecurityException by ensuring permissions exist
  /// BEFORE accessing hardware.
  Future<void> _safeInit() async {
    // 1. Load non-hardware data first
    await _loadUserInfo();

    // 2. CHECK PERMISSIONS
    // We strictly wait here. If denied, we do NOT proceed to touch the GPS.
    final hasPermission = await checkLocationPermissions();

    if (mounted && hasPermission) {
      // 3. Only now is it safe to touch the hardware
      _initCompass();
      _initConnectivityMonitoring();
      _startPeriodicTimers();

      // 4. Center map (Safe now)
      await _centerOnUser();

      // 5. Restore session
      await _restoreSessionState();
    } else {
      debugPrint("⚠️ Permissions denied on startup. Waiting for user action.");
    }
  }

  void _startPeriodicTimers() {
    _uiUpdateTimer = Timer.periodic(_uiUpdateInterval, (_) => _updateUI());
    _dbFlushTimer = Timer.periodic(_maxBufferAge, (_) => _flushBuffer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAllResources();
    _disposeNotifiers();
    super.dispose();
  }

  Future<void> _cleanupAllResources() async {
    debugPrint("🧹 Cleaning up all resources...");

    _uiUpdateTimer?.cancel();
    _dbFlushTimer?.cancel();

    await gpsSubscription?.cancel();
    await _compassSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    sessionTimer?.cancel();
    syncTimer?.cancel();
    snapTimer?.cancel();

    try {
      await _location.enableBackgroundMode(enable: false);
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint("⚠️ Error disabling hardware services: $e");
    }

    try {
      if (_pointBuffer.isNotEmpty && _currentSessionId != null) {
        // Fire and forget flush (don't await in dispose)
        _flushBuffer();
      }
    } catch (e) { debugPrint("Buffer flush error: $e"); }
  }

  void _disposeNotifiers() {
    _polylineNotifier.dispose();
    _smoothNotifier.dispose();
    _currentPositionNotifier.dispose();
    _statsNotifier.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !isTracking) {
      _compassSubscription?.pause();
      _uiUpdateTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _compassSubscription?.resume();
      if (_uiUpdateTimer?.isActive != true) {
        _uiUpdateTimer = Timer.periodic(_uiUpdateInterval, (_) => _updateUI());
      }
    }
  }

  void _initConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
        final wasOffline = !_isConnected;
        _isConnected = !results.contains(ConnectivityResult.none);
        if (mounted) setState(() => isOffline = !_isConnected);
        if (wasOffline && _isConnected && isTracking) _performSync();
      },
      onError: (e) => debugPrint("Connectivity error: $e"),
    );
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen(
          (event) {
        if (mounted && event.heading != null) {
          setState(() => _currentHeading = event.heading!);
        }
      },
      onError: (e) => debugPrint("Compass error: $e"),
    );
  }

  Future<void> _loadUserInfo() async {
    try {
      final name = await sl<ApiService>().getUsername();
      if (mounted) setState(() => _username = name);
    } catch (e) { debugPrint("Load user error: $e"); }
  }

  // 🛡️ CRITICAL FIX: Guarded Location Access
  Future<void> _centerOnUser() async {
    try {
      // 1. Double check permission before calling hardware
      final perm = await _location.hasPermission();
      if (perm == PermissionStatus.denied || perm == PermissionStatus.deniedForever) {
        return;
      }

      // 2. Safe to call
      final loc = await _location.getLocation();
      if (loc.latitude != null && loc.longitude != null) {
        _currentPositionNotifier.value = LatLng(loc.latitude!, loc.longitude!);
      }
    } catch (e) {
      debugPrint("⚠️ Failed to get initial location: $e");
    }
  }

  Future<void> _toggleTracking() async {
    if (isTracking) await _stopSession();
    else await _startSession();
  }

  Future<void> _restoreSessionState() async {
    try {
      final activeId = await LocalDatabase.instance.getActiveSessionId();
      if (activeId != null && mounted) {
        setState(() {
          _currentSessionId = activeId;
          isTracking = true;
        });
        _resumeHardwareServices();
        _showSnack("Active session recovered", isError: false);
      }
    } catch (e) { debugPrint("Restore error: $e"); }
  }

  Future<void> _startSession() async {
    _setLoading(true);
    try {
      if (!await checkLocationPermissions()) {
        _setLoading(false);
        return;
      }

      final result = await sl<ApiService>().startTrackingSession();

      if (result['success'] == true) {
        final newId = await LocalDatabase.instance.createSession();
        _initializeNewSession(newId);
        _resumeHardwareServices();
        _showSnack("Tracking started", isError: false);
      } else if (_is409Conflict(result)) {
        await _handle409Conflict();
      } else {
        _showSnack(result['message'] ?? 'Failed to start', isError: true);
      }
    } catch (e) {
      debugPrint("Start session error: $e");
      if (e.toString().contains("409")) {
        await _handle409Conflict();
      } else if (mounted) {
        _showSnack('Failed to start tracking', isError: true);
      }
    } finally {
      if (!isTracking && mounted) _setLoading(false);
    }
  }

  bool _is409Conflict(Map<String, dynamic> result) {
    if (result['statusCode'] == 409) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('already active') || msg.contains('already running');
  }

  Future<void> _handle409Conflict() async {
    debugPrint("⚠️ 409 Conflict: Server has active session");
    final activeLocalId = await LocalDatabase.instance.getActiveSessionId();

    if (activeLocalId != null) {
      debugPrint("✅ Local session found. Resuming...");
      await _restoreSessionState();
    } else {
      debugPrint("🧟 Zombie session detected! Force-stopping...");
      try {
        await sl<ApiService>().stopTrackingSession();
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) await _startSession();
      } catch (e) {
        debugPrint("Zombie fix failed: $e");
        if (mounted) _showSnack("Failed to resolve conflict", isError: true);
      }
    }
  }

  void _initializeNewSession(int id) {
    if (!mounted) return;
    setState(() {
      _currentSessionId = id;
      isTracking = true;
      sessionDuration = Duration.zero;
      _totalDistanceMeters = 0.0;
    });
    _polylineNotifier.value = [];
    _smoothNotifier.value = [];
    _statsNotifier.value = _TrackingStats();
  }

  Future<void> _stopSession({bool isDeadSession = false}) async {
    _setLoading(true);
    _cleanupHardwareServices();
    try {
      await _flushBuffer();
      if (_currentSessionId != null) {
        await LocalDatabase.instance.updateSessionStats(
          _currentSessionId!,
          _totalDistanceMeters / 1000.0,
          sessionDuration.inSeconds,
        );
      }
      await _refinePath();
      if (!isDeadSession) {
        await _performSync();
        await sl<ApiService>().stopTrackingSession();
      }
      if (mounted) {
        setState(() {
          isTracking = false;
          _currentSessionId = null;
        });
      }
      if (!isDeadSession) _showSnack('Session Saved!', isError: false);
    } catch (e) {
      debugPrint("Stop session error: $e");
      _showSnack('Error saving session', isError: true);
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  void _resumeHardwareServices() {
    toggleScreenAwake(true);
    toggleBackgroundMode(true);
    _startTrackingLoops();
  }

  void _cleanupHardwareServices() {
    toggleScreenAwake(false);
    toggleBackgroundMode(false);
    stopAllStreams();
  }

  void _startTrackingLoops() {
    sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => sessionDuration += const Duration(seconds: 1));
    });
    syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _performSync());
    snapTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refinePath());

    _location.changeSettings(accuracy: LocationAccuracy.navigation, interval: 1000, distanceFilter: 3);

    gpsSubscription = _location.onLocationChanged.listen(
      _processLocationData,
      onError: (e) => debugPrint("GPS Error: $e"),
    );
  }

  void _processLocationData(LocationData loc) {
    if (loc.latitude == null || loc.longitude == null || (loc.accuracy ?? 100) > 25) return;
    _latestLocationData = loc;
    final newPos = LatLng(loc.latitude!, loc.longitude!);

    final currentPolyline = _polylineNotifier.value;
    if (currentPolyline.isEmpty || _shouldAddPoint(currentPolyline.last, newPos)) {
      _polylineNotifier.value = [...currentPolyline, newPos];
      _updateStats(newPos, loc);
      _bufferPointForDb(loc);
    }
  }

  bool _shouldAddPoint(LatLng lastPos, LatLng newPos) {
    return const Distance().as(LengthUnit.Meter, lastPos, newPos) >= 2.0;
  }

  void _updateUI() {
    final loc = _latestLocationData;
    if (loc == null || !mounted) return;

    final speed = loc.speed ?? 0;
    final speedKmh = speed < 0.3 ? 0.0 : speed * 3.6;

    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate) >= _minPositionUpdateInterval) {
      _currentPositionNotifier.value = LatLng(loc.latitude!, loc.longitude!);
      _lastPositionUpdate = now;
    }

    _statsNotifier.value = _TrackingStats(
      speedKmph: speedKmh,
      accuracy: loc.accuracy ?? 0,
      distanceKm: _totalDistanceMeters / 1000.0,
    );
  }

  void _updateStats(LatLng newPos, LocationData loc) {
    final polyline = _polylineNotifier.value;
    if (polyline.isEmpty) return;
    final dist = const Distance().as(LengthUnit.Meter, polyline.last, newPos);
    final errorMargin = (loc.accuracy ?? 5.0).clamp(2.5, 10.0);
    if (dist > errorMargin) _totalDistanceMeters += dist;
  }

  void _bufferPointForDb(LocationData loc) {
    if (_currentSessionId == null) return;
    final point = data.LocationPoint(
      lat: loc.latitude!,
      lon: loc.longitude!,
      accuracy: loc.accuracy ?? 0,
      speed: loc.speed ?? 0,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    _pointBuffer.add(point);
    if (_pointBuffer.length >= _minBufferSize) _flushBuffer();
  }

  Future<void> _flushBuffer() async {
    if (_pointBuffer.isEmpty || _currentSessionId == null) return;
    final batch = List<data.LocationPoint>.from(_pointBuffer);
    _pointBuffer.clear();

    try {
      await LocalDatabase.instance.insertPointsBatch(batch, _currentSessionId!);
    } catch (e) {
      if (_pointBuffer.length + batch.length <= _maxBufferLimit) {
        _pointBuffer.insertAll(0, batch);
      }
    }
  }

  Future<void> _performSync() async {
    if (!_isConnected || _currentSessionId == null) return;
    try {
      final rawData = await LocalDatabase.instance.getUnsyncedRaw(100);
      if (rawData.isEmpty) return;

      final result = await Isolate.run(() {
        final points = rawData.map((e) => data.LocationPoint.fromJson(e)).toList();
        final ids = rawData.map((e) => e['id'] as int).toList();
        return {'points': points, 'ids': ids};
      });

      final points = (result['points'] as List).cast<data.LocationPoint>();
      final ids = (result['ids'] as List).cast<int>();

      final syncResult = await sl<ApiService>().sendLocationData(points)
          .timeout(const Duration(seconds: 10), onTimeout: () => {'success': false});

      if (syncResult['success'] == true) {
        await LocalDatabase.instance.clearPointsByIds(ids);
      } else if (syncResult['statusCode'] == 404) {
        if (mounted) _showSnack("Session expired.", isError: true);
        await LocalDatabase.instance.clearPointsByIds(ids);
        await _stopSession(isDeadSession: true);
      }
    } catch (e) { debugPrint("Sync error: $e"); }
  }

  Future<void> _refinePath() async {
    final polyline = _polylineNotifier.value;
    if (polyline.length < 5) return;
    try {
      final snapped = await sl<MapMatchingService>().getSnappedRoute(polyline);
      if (mounted && snapped.isNotEmpty) _smoothNotifier.value = snapped;
    } catch (e) { debugPrint("Map match error: $e"); }
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => isBusy = value);
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  void _openProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileSheet(username: _username),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              Text('Error: $_error'),
              ElevatedButton(onPressed: () => setState(() => _error = null), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([_smoothNotifier, _polylineNotifier, _currentPositionNotifier]),
              builder: (context, _) => YandexMapBackground(
                polylineCoordinates: _smoothNotifier.value.isNotEmpty ? _smoothNotifier.value : _polylineNotifier.value,
                currentHeading: _currentHeading,
                currentPosition: _currentPositionNotifier.value,
                shouldFollowUser: _shouldFollowUser,
              ),
            ),
            ValueListenableBuilder<_TrackingStats>(
              valueListenable: _statsNotifier,
              builder: (context, stats, _) => TrackingHUD(
                isTracking: isTracking,
                isOffline: isOffline,
                sessionDuration: sessionDuration,
                username: _username,
                distanceKm: stats.distanceKm,
                speedKmph: stats.speedKmph,
                accuracy: stats.accuracy,
                onProfileTap: _openProfileSheet,
              ),
            ),
            _buildMapToggles(),
          ],
        ),
        floatingActionButton: TrackingFab(
          isTracking: isTracking,
          isBusy: isBusy,
          onPressed: _toggleTracking,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildMapToggles() {
    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        children: [
          _CircleButton(
            icon: _shouldFollowUser ? Icons.near_me : Icons.near_me_disabled,
            color: _shouldFollowUser ? Colors.blue : Colors.grey,
            onTap: () => setState(() => _shouldFollowUser = !_shouldFollowUser),
          ),
          const SizedBox(height: 12),
          _CircleButton(icon: Icons.my_location, onTap: _centerOnUser),
        ],
      ),
    );
  }
}

class _TrackingStats {
  final double speedKmph;
  final double accuracy;
  final double distanceKm;
  _TrackingStats({this.speedKmph = 0.0, this.accuracy = 0.0, this.distanceKm = 0.0});
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      backgroundColor: Colors.white,
      onPressed: onTap,
      child: Icon(icon, color: color ?? Colors.black87),
    );
  }
}