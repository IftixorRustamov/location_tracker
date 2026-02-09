import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/core/services/map_matching_service.dart';
import 'package:location_tracker/data/models/location_point.dart' as data;
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';

import '../widgets/map_background.dart';
import '../widgets/tracking_hud.dart';
import '../widgets/tracking_fab.dart';
import '../widgets/profile_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // --- Controllers ---
  final MapController _mapController = MapController();
  final Location _location = Location();

  // --- Streams & Timers ---
  StreamSubscription<LocationData>? _gpsSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _sessionTimer;
  Timer? _syncTimer;
  Timer? _snapTimer;

  // --- Data ---
  List<LatLng> _polylineCoordinates = [];
  List<LatLng> _smoothCoordinates = [];

  Duration _sessionDuration = Duration.zero;
  String? _username;
  LatLng? _currentPosition;
  double _currentHeading = 0.0;

  // --- UI State ---
  bool _isTracking = false;
  bool _isBusy = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _centerOnUser();
    _initCompass();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _compassSubscription?.cancel();
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    _snapTimer?.cancel(); // Cancel snap timer
    _mapController.dispose();
    super.dispose();
  }

  // --- 1. Init Logic ---
  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _currentHeading = event.heading!);
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final name = await sl<ApiService>().getUsername();
    if (mounted) setState(() => _username = name);
  }

  Future<void> _centerOnUser() async {
    try {
      final loc = await _location.getLocation();
      if (loc.latitude != null && loc.longitude != null) {
        final pos = LatLng(loc.latitude!, loc.longitude!);
        setState(() => _currentPosition = pos);
        _mapController.move(pos, 16);
      }
    } catch (_) {}
  }

  // --- 2. Tracking Logic ---
  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _stopSession();
    } else {
      await _startSession();
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _isTracking = true;
      _sessionDuration = Duration.zero;
      _polylineCoordinates = [];
      _smoothCoordinates = [];
    });

    if (!await _checkPermissions()) {
      setState(() => _isBusy = false);
      return;
    }

    final result = await sl<ApiService>().startTrackingSession();
    if (result['success']) {
      setState(() {
        _isTracking = true;
        _sessionDuration = Duration.zero;
        _polylineCoordinates = []; // Reset list
      });
      _startTimer();
      _startHighPrecisionGPS();
      _startBackgroundSync();
      _startMapMatching(); // Start smoothing the lines
    } else {
      _showSnack(result['message'] ?? 'Failed to start', isError: true);
    }
    setState(() => _isBusy = false);
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }
    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) return false;
    }
    return true;
  }

  Future<void> _stopSession() async {
    setState(() => _isBusy = true);
    _gpsSubscription?.cancel();
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    _snapTimer?.cancel();

    // Final smooth & sync
    await _refinePath();
    await _performSync();

    await sl<ApiService>().stopTrackingSession();

    setState(() => _isTracking = false);
    _showSnack('Session Saved!', isError: false);
    setState(() => _isBusy = false);
  }

  // --- 3. GPS & Sync Logic ---
  void _startHighPrecisionGPS() {
    _location.changeSettings(
      accuracy: LocationAccuracy.navigation,
      interval: 1000,
      distanceFilter: 5,
    );
    _gpsSubscription = _location.onLocationChanged.listen((loc) async {
      if (loc.latitude == null) return;

      // Indoor Filter: Ignore bad accuracy (>15m)
      if ((loc.accuracy ?? 100) > 15) return;
      // Static Filter: Ignore standing still (<0.5m/s)
      if ((loc.speed ?? 0) < 0.5) return;

      final newPos = LatLng(loc.latitude!, loc.longitude!);

      final point = data.LocationPoint(
        lat: loc.latitude!,
        lon: loc.longitude!,
        accuracy: loc.accuracy ?? 0,
        speed: loc.speed ?? 0,
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      await LocalDatabase.instance.insertPoint(point);

      if (mounted) {
        setState(() {
          _currentPosition = newPos;
          _polylineCoordinates.add(newPos);
        });
        _mapController.move(newPos, 17);
      }
    });
  }

  void _startBackgroundSync() {
    _syncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _performSync(),
    );
  }

  void _startMapMatching() {
    _snapTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refinePath(),
    );
  }

  Future<void> _refinePath() async {
    if (_polylineCoordinates.length < 5) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      final snapped = await sl<MapMatchingService>().getSnappedRoute(
        _polylineCoordinates,
      );
      if (mounted && snapped.isNotEmpty) {
        setState(() {
          _smoothCoordinates = snapped;
        });
      }
    } catch (e) {
      debugPrint("Map matching failed (ignoring): $e");
    }
  }

  Future<void> _performSync() async {
    final connectivity = await Connectivity().checkConnectivity();
    final bool hasNoInternet = connectivity.contains(ConnectivityResult.none);

    if (hasNoInternet) {
      if (!_isOffline && mounted) setState(() => _isOffline = true);
      return;
    }

    if (_isOffline && mounted) setState(() => _isOffline = false);

    final List<Map<String, dynamic>> rawData = await LocalDatabase.instance
        .getUnsyncedRaw(50);
    if (rawData.isEmpty) return;

    final List<data.LocationPoint> pointsToSync = rawData
        .map((e) => data.LocationPoint.fromJson(e))
        .toList();
    final List<int> pointIds = rawData.map((e) => e['id'] as int).toList();

    try {
      final result = await sl<ApiService>().sendLocationData(pointsToSync);

      if (result['success']) {
        await LocalDatabase.instance.clearPointsByIds(pointIds);
        debugPrint(
          "SYNC: Successfully uploaded and cleared ${pointIds.length} points.",
        );
      }
    } catch (e) {
      log(
        "SYNC ERROR: Failed to upload batch. Data remains in local storage. $e",
      );
    }
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _sessionDuration += const Duration(seconds: 1));
    });
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileSheet(username: _username),
    );
  }

  // --- 4. BUILD ---
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Map
            MapBackground(
              mapController: _mapController,
              polylineCoordinates: _polylineCoordinates,
              currentPosition: _currentPosition,
              currentHeading: _currentHeading,
            ),
            // 2. HUD
            TrackingHUD(
              isTracking: _isTracking,
              isOffline: _isOffline,
              sessionDuration: _sessionDuration,
              username: _username,
              onProfileTap: _showProfileSheet,
            ),
          ],
        ),
        // 3. FAB
        floatingActionButton: TrackingFab(
          isTracking: _isTracking,
          isBusy: _isBusy,
          onPressed: _toggleTracking,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
