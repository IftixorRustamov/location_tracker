import 'dart:async';
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

import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';
import 'package:location_tracker/features/tracking/widgets/yandex_map_background.dart';
import 'package:location_tracker/features/tracking/logic/tracking_manager.dart';

import '../widgets/tracking_hud.dart';
import '../widgets/tracking_fab.dart';
import '../widgets/profile_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, TrackingManager {

  // --- Controllers ---
  final Location _location = Location();

  // --- Data ---
  List<LatLng> _polylineCoordinates = [];
  List<LatLng> _smoothCoordinates = [];

  String? _username;
  LatLng? _currentPosition;
  double _currentHeading = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // --- NEW: Live Stats ---
  double _totalDistanceMeters = 0.0;
  double _currentSpeedKmph = 0.0;
  double _currentAccuracy = 0.0; // Added this to track signal strength
  int? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _centerOnUser();
    _initCompass();
  }

  @override
  void dispose() {
    stopAllStreams();
    _compassSubscription?.cancel();
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
      }
    } catch (_) {}
  }

  // --- 2. Tracking Logic ---
  Future<void> _toggleTracking() async {
    if (isTracking) {
      await _stopSession();
    } else {
      await _startSession();
    }
  }

  Future<void> _startSession() async {
    setState(() => isBusy = true);

    if (!await checkLocationPermissions(_location)) {
      setState(() => isBusy = false);
      return;
    }

    final result = await sl<ApiService>().startTrackingSession();

    if (result['success']) {
      final newSessionId = await LocalDatabase.instance.createSession();

      setState(() {
        _currentSessionId = newSessionId; // Save ID
        isTracking = true;
        sessionDuration = Duration.zero;
        _polylineCoordinates = [];
        _smoothCoordinates = [];
        _totalDistanceMeters = 0.0;
        _currentSpeedKmph = 0.0;
        _currentAccuracy = 0.0;
      });

      await toggleScreenAwake(true);
      await toggleBackgroundMode(true);

      _startServices();
    } else {
      _showSnack(result['message'] ?? 'Failed to start', isError: true);
    }
    setState(() => isBusy = false);
  }

  Future<void> _stopSession() async {
    setState(() => isBusy = true);

    // 1. Stop Hardware & Streams
    await toggleScreenAwake(false);
    await toggleBackgroundMode(false);
    stopAllStreams(); // This stops GPS, Timers, etc.

    if (_currentSessionId != null) {
      await LocalDatabase.instance.updateSessionStats(
        _currentSessionId!,
        _totalDistanceMeters / 1000.0, // Convert meters to KM
        sessionDuration.inSeconds,     // Save duration in seconds
      );
    }

    // 3. Final Polish
    await _refinePath(); // Run map matching one last time
    await _performSync(); // Upload remaining points to server

    // 4. API Stop
    await sl<ApiService>().stopTrackingSession();

    // 5. Reset UI State
    setState(() {
      isTracking = false;
      _currentSessionId = null; // Clear the session ID so we don't accidentally update it later
      isBusy = false;
    });

    _showSnack('Session Saved!', isError: false);
  }

  // --- 3. GPS & Sync Logic ---
  void _startServices() {
    sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => sessionDuration += const Duration(seconds: 1));
    });

    syncTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _performSync(),
    );

    snapTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _refinePath(),
    );

    _location.changeSettings(
      accuracy: LocationAccuracy.navigation,
      interval: 1000,
      distanceFilter: 5,
    );

    gpsSubscription = _location.onLocationChanged.listen((loc) async {
      if (loc.latitude == null) return;
      if ((loc.accuracy ?? 100) > 15) return;

      // Filter: Stop if standing still
      if ((loc.speed ?? 0) < 0.5) {
        if (mounted && _currentSpeedKmph > 0) {
          setState(() => _currentSpeedKmph = 0);
        }
        return;
      }

      final newPos = LatLng(loc.latitude!, loc.longitude!);

      // --- Stats Calculation ---
      if (_polylineCoordinates.isNotEmpty) {
        final double dist = const Distance().as(
            LengthUnit.Meter,
            _polylineCoordinates.last,
            newPos
        );
        if (dist > 2) {
          _totalDistanceMeters += dist;
        }
      }

      // Speed (m/s -> km/h)
      double rawSpeed = loc.speed ?? 0;
      if (rawSpeed < 0) rawSpeed = 0;

      // Update local values for DB
      final speedKmph = rawSpeed * 3.6;
      final accuracy = loc.accuracy ?? 0;

      final point = data.LocationPoint(
        lat: loc.latitude!,
        lon: loc.longitude!,
        accuracy: accuracy,
        speed: loc.speed ?? 0, // Store as m/s in DB (standard)
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );

      await LocalDatabase.instance.insertPoint(point,_currentSessionId!);

      if (mounted) {
        setState(() {
          _currentPosition = newPos;
          _polylineCoordinates.add(newPos);
          _currentSpeedKmph = speedKmph;
          _currentAccuracy = accuracy; // Update UI accuracy
        });
      }
    });
  }

  Future<void> _refinePath() async {
    if (_polylineCoordinates.length < 5) return;
    try {
      final snapped = await sl<MapMatchingService>().getSnappedRoute(
        _polylineCoordinates,
      );
      if (mounted && snapped.isNotEmpty) {
        setState(() => _smoothCoordinates = snapped);
      }
    } catch (_) {}
  }

  Future<void> _performSync() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      if (!isOffline && mounted) setState(() => isOffline = true);
      return;
    }
    if (isOffline && mounted) setState(() => isOffline = false);

    final rawData = await LocalDatabase.instance.getUnsyncedRaw(50);
    if (rawData.isEmpty) return;

    final points = rawData.map((e) => data.LocationPoint.fromJson(e)).toList();
    final ids = rawData.map((e) => e['id'] as int).toList();

    try {
      final result = await sl<ApiService>().sendLocationData(points);
      if (result['success']) await LocalDatabase.instance.clearPointsByIds(ids);
    } catch (_) {}
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
            YandexMapBackground(
              polylineCoordinates: _smoothCoordinates.isNotEmpty
                  ? _smoothCoordinates
                  : _polylineCoordinates,
              currentHeading: _currentHeading,
              currentPosition: _currentPosition,
            ),

            // FIX: Pass the new stats variables here!
            TrackingHUD(
              isTracking: isTracking,
              isOffline: isOffline,
              sessionDuration: sessionDuration,
              username: _username,
              // New params:
              distanceKm: _totalDistanceMeters / 1000.0, // Convert to KM
              speedKmph: _currentSpeedKmph,
              accuracy: _currentAccuracy,
              onProfileTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => ProfileSheet(username: _username),
              ),
            ),
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
}