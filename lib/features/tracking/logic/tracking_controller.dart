import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // Required for 'compute'
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/core/services/map_matching_service.dart';
import 'package:location_tracker/data/models/location_point.dart' as data;
import 'package:location_tracker/features/tracking/services/database_buffer.dart';
import 'package:location_tracker/features/tracking/services/location_processor.dart';
import 'package:location_tracker/features/tracking/services/session_manager.dart';

// -----------------------------------------------------------------------------
// TOP-LEVEL FUNCTION (Runs in Background Isolation)
// -----------------------------------------------------------------------------
// This MUST be outside the class to prevent "Illegal argument in isolate message"
Map<String, dynamic> _parsePointsInBackground(List<Map<String, dynamic>> rawData) {
  return {
    'points': rawData.map((e) => data.LocationPoint.fromJson(e)).toList(),
    'ids': rawData.map((e) => e['id'] as int).toList(),
  };
}

// -----------------------------------------------------------------------------
// CONTROLLER
// -----------------------------------------------------------------------------
class TrackingController extends ChangeNotifier {
  // === SERVICES ===
  late final DatabaseBuffer _dbBuffer;
  late final SessionManager _sessionManager;
  late final LocationProcessor _locationProcessor;
  final Location _location = Location();

  // === SUBSCRIPTIONS ===
  StreamSubscription<LocationData>? _gpsSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;

  // === STATE NOTIFIERS ===
  final ValueNotifier<List<LatLng>> polylineNotifier = ValueNotifier([]);
  final ValueNotifier<List<LatLng>> smoothPolylineNotifier = ValueNotifier([]);
  final ValueNotifier<LatLng?> currentPositionNotifier = ValueNotifier(null);
  final ValueNotifier<double> speedNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> accuracyNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier(0.0);

  // === INTERNAL STATE ===
  bool _isConnected = true;
  bool _isBusy = false;

  bool _isCompassActive = false;

  String? username;

  // === GETTERS ===
  bool get isBusy => _isBusy;
  bool get isTracking => _sessionManager.isTracking;
  bool get isOffline => !_isConnected;
  Duration get sessionDuration => _sessionManager.sessionDuration;
  double get distanceKm => _sessionManager.totalDistanceKm;

  // ============================================================
  // INITIALIZATION
  // ============================================================
  Future<void> initialize(Function(String, bool) onMessage) async {
    _dbBuffer = DatabaseBuffer();
    _sessionManager = SessionManager(
      dbBuffer: _dbBuffer,
      onShowMessage: onMessage,
    );

    _locationProcessor = LocationProcessor(
      onValidLocation: _handleValidLocation,
      onPointBuffered: (point) {
        _dbBuffer.addPoint(point);
        _dbBuffer.flushIfNeeded();
      },
    );

    await _loadUserInfo();
    _initCompass();
    _initConnectivity();
    await _sessionManager.restoreSession();

    if (isTracking) {
      _resumeHardwareServices();
      notifyListeners();
    }
  }

  void disposeController() {
    _cleanupHardwareServices();
    polylineNotifier.dispose();
    smoothPolylineNotifier.dispose();
    currentPositionNotifier.dispose();
    speedNotifier.dispose();
    accuracyNotifier.dispose();
    headingNotifier.dispose();
    _sessionManager.dispose();
  }

  // ============================================================
  // USER ACTIONS
  // ============================================================
  Future<void> toggleTracking(Function(String, bool) onMessage) async {
    if (isTracking) {
      await stopSession(onMessage);
    } else {
      await startSession(onMessage);
    }
  }

  Future<void> startSession(Function(String, bool) onMessage) async {
    if (_isBusy) return;
    _setBusy(true);

    try {
      if (!await _checkPermissions()) {
        onMessage('Location permissions required', true);
        return;
      }

      final success = await _sessionManager.startSession();
      if (success) {
        _resumeHardwareServices();
        _resetMapState();
        notifyListeners();
      } else {
        onMessage('Failed to start tracking', true);
      }
    } catch (e) {
      onMessage('Failed to start tracking', true);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> stopSession(Function(String, bool) onMessage, {bool isDead = false}) async {
    _setBusy(true); // Start loading

    try {
      _cleanupHardwareServices();

      // 2. Try a "Best Effort" Sync (Max 2 seconds)
      // If internet is slow, don't make the user wait. Data remains in DB.
      if (!isDead) {
        try {
          await _performSync(onMessage).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      // 3. Stop Session API (Required)
      await _sessionManager.stopSession(isDeadSession: isDead);

      notifyListeners();
    } catch (e) {
      onMessage('Error saving session', true);
    } finally {
      _setBusy(false); // Stop loading immediately
    }
  }

  Future<void> centerOnUser() async {
    if (!await _checkPermissions()) return;

    try {
      // 2. Fetch location with a timeout so it doesn't hang
      final loc = await _location.getLocation().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          throw TimeoutException("GPS timed out");
        },
      );

      if (loc.latitude != null && loc.longitude != null) {
        final newPos = LatLng(loc.latitude!, loc.longitude!);

        // 3. Force update the notifier
        currentPositionNotifier.value = newPos;
      }
    } catch (e) {
      // Fallback: If we already have a position in memory, just trigger the UI
      if (currentPositionNotifier.value != null) {
        // Re-assigning triggers the listeners even if value is same
        // (Use a new object to force equality check failure if needed)
        final current = currentPositionNotifier.value!;
        currentPositionNotifier.value = LatLng(current.latitude, current.longitude);
      }
    }
  }

  // ============================================================
  // LOCATION & HEADING LOGIC
  // ============================================================
  void _handleValidLocation(LatLng pos, LocationData data) {
    final currentList = polylineNotifier.value;
    polylineNotifier.value = [...currentList, pos];
    currentPositionNotifier.value = pos;

    final speedKmh = _locationProcessor.calculateSpeedKmh(data);
    speedNotifier.value = speedKmh;
    accuracyNotifier.value = data.accuracy ?? 0;

    // If moving > 3km/h, GPS heading is best.
    // 2. If stopped or emulator (no compass), use GPS heading.
    // 3. Otherwise, use Compass (handled in _initCompass)
    if (speedKmh > 3.0 && data.heading != null) {
      headingNotifier.value = data.heading!;
    } else if (!_isCompassActive && data.heading != null) {
      headingNotifier.value = data.heading!;
    }

    final dist = _locationProcessor.updateDistance(
        currentList, pos, data, _sessionManager.totalDistanceMeters
    );
    _sessionManager.updateDistance(dist - _sessionManager.totalDistanceMeters);
    notifyListeners();
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _isCompassActive = true;

        // Use compass only when stationary or very slow
        if (speedNotifier.value < 3.0) {
          headingNotifier.value = event.heading!;
        }
      }
    });
  }

  // ============================================================
  // SYNC OPERATIONS
  // ============================================================
  Future<void> _performSync(Function(String, bool) onMessage) async {
    if (!_isConnected || !isTracking) return;

    try {
      final result = await compute(_parsePointsInBackground, rawData);

      final points = result['points'] as List<data.LocationPoint>;
      final ids = result['ids'] as List<int>;

      final syncResult = await sl<ApiService>()
          .sendLocationData(points)
          .timeout(const Duration(seconds: 10), onTimeout: () => {'success': false, 'message': 'Timeout'});

      if (syncResult['success'] == true) {
        await LocalDatabase.instance.clearPointsByIds(ids);
      } else if (syncResult['statusCode'] == 404) {
        onMessage('Session expired', true);
        await LocalDatabase.instance.clearPointsByIds(ids);
        await stopSession(onMessage, isDead: true);
      }
    } catch (_) {}
  }

  // ============================================================
  // HARDWARE MANAGEMENT
  // ============================================================
  void _resumeHardwareServices() {
    WakelockPlus.enable();
    _location.enableBackgroundMode(enable: true);

    _location.changeSettings(
      accuracy: LocationAccuracy.navigation,
      interval: 1000,
      distanceFilter: 0,
    );

    _gpsSubscription = _location.onLocationChanged.listen(
          (loc) => _locationProcessor.processLocationData(loc, polylineNotifier.value),
    );

    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _performSync((_, __) {}));
  }

  void _cleanupHardwareServices() {
    _gpsSubscription?.cancel();
    _compassSubscription?.cancel();
    _syncTimer?.cancel();

    try {
      _location.enableBackgroundMode(enable: false);
      WakelockPlus.disable();
    } catch (_) {}

    _dbBuffer.flush();
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Future<void> _refinePath() async {
    final polyline = polylineNotifier.value;
    if (polyline.length < 5) return;

    try {
      final snapped = await sl<MapMatchingService>().getSnappedRoute(polyline);
      if (snapped.isNotEmpty) {
        smoothPolylineNotifier.value = snapped;
      }
    } catch (_) {}
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  void _resetMapState() {
    polylineNotifier.value = [];
    smoothPolylineNotifier.value = [];
    speedNotifier.value = 0;
    accuracyNotifier.value = 0;
    headingNotifier.value = 0;
  }

  Future<bool> _checkPermissions() async {
    final status = await _location.hasPermission();
    if (status == PermissionStatus.granted) return true;
    final result = await _location.requestPermission();
    return result == PermissionStatus.granted;
  }

  Future<void> _loadUserInfo() async {
    try {
      username = await sl<ApiService>().getUsername();
      notifyListeners();
    } catch (_) {}
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((res) {
      _isConnected = !res.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }
}