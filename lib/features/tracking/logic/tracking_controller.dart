import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/data/models/location_point.dart' as data;
import 'package:location_tracker/features/tracking/services/database_buffer.dart';
import 'package:location_tracker/features/tracking/services/location_processor.dart';
import 'package:location_tracker/features/tracking/services/session_manager.dart';

Map<String, dynamic> _parsePointsInBackground(
    List<Map<String, dynamic>> rawData) {
  return {
    'points': rawData.map((e) => data.LocationPoint.fromJson(e)).toList(),
    'ids': rawData.map((e) => e['id'] as int).toList(),
  };
}

class TrackingController extends ChangeNotifier {
  static final _log = Logger();

  final ApiService _apiService;

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
  final ValueNotifier<List<LatLng>> polylineNotifier  = ValueNotifier([]);
  final ValueNotifier<LatLng?> currentPositionNotifier = ValueNotifier(null);
  final ValueNotifier<double> speedNotifier            = ValueNotifier(0.0);
  final ValueNotifier<double> accuracyNotifier         = ValueNotifier(0.0);
  final ValueNotifier<double> headingNotifier          = ValueNotifier(0.0);

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

  TrackingController(this._apiService);

  // ──────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ──────────────────────────────────────────────────────────────

  Future<void> initialize(void Function(String, bool) onMessage) async {
    _dbBuffer = DatabaseBuffer();

    _sessionManager = SessionManager(
      apiService: _apiService,
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
      _resumeGpsAndSync();
      notifyListeners();
    }
  }

  void disposeController() {
    _cleanupGpsAndSync();
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _connectivitySubscription?.cancel();
    polylineNotifier.dispose();
    currentPositionNotifier.dispose();
    speedNotifier.dispose();
    accuracyNotifier.dispose();
    headingNotifier.dispose();
    _sessionManager.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // USER ACTIONS
  // ──────────────────────────────────────────────────────────────

  Future<void> toggleTracking(void Function(String, bool) onMessage) async {
    if (isTracking) {
      await stopSession(onMessage);
    } else {
      await startSession(onMessage);
    }
  }

  Future<void> startSession(void Function(String, bool) onMessage) async {
    if (_isBusy) return;
    _setBusy(true);

    try {
      if (!await _checkPermissions()) {
        onMessage('Location permissions required', true);
        return;
      }

      final success = await _sessionManager.startSession();
      if (success) {
        _resumeGpsAndSync();
        _resetMapState();
        notifyListeners();
      } else {
        onMessage('Failed to start tracking', true);
      }
    } catch (e) {
      _log.e('Start Session Error', error: e);
      onMessage('Failed to start tracking', true);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> stopSession(
      void Function(String, bool) onMessage, {
        bool isDead = false,
      }) async {
    _setBusy(true);

    try {
      // 1. Cut GPS immediately.
      _cleanupGpsAndSync();

      // 2. Best-effort final sync (2 s timeout).
      if (!isDead) {
        try {
          await _performSync().timeout(const Duration(seconds: 2));
        } catch (_) {
          _log.w('Final sync timed out — data saved locally.');
        }
      }

      // 3. Close session in DB and call stop API.
      await _sessionManager.stopSession(isDeadSession: isDead);
      notifyListeners();
    } catch (e) {
      _log.e('Stop Session Error', error: e);
      onMessage('Error saving session', true);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> centerOnUser() async {
    if (!await _checkPermissions()) return;

    try {
      final loc = await _location.getLocation().timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('GPS Timeout'),
      );

      if (loc.latitude != null && loc.longitude != null) {
        currentPositionNotifier.value = LatLng(loc.latitude!, loc.longitude!);
      }
    } catch (e) {
      _log.w('Center on user failed: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // LOCATION & HEADING
  // ──────────────────────────────────────────────────────────────

  void _handleValidLocation(LatLng pos, LocationData locationData) {
    final currentList = polylineNotifier.value;
    polylineNotifier.value = [...currentList, pos];
    currentPositionNotifier.value = pos;

    final speedKmh = _locationProcessor.calculateSpeedKmh(locationData);
    speedNotifier.value = speedKmh;
    accuracyNotifier.value = locationData.accuracy ?? 0;

    // Hybrid heading: GPS when moving fast, compass when stationary.
    if (speedKmh > 3.0 && locationData.heading != null) {
      headingNotifier.value = locationData.heading!;
    } else if (!_isCompassActive && locationData.heading != null) {
      headingNotifier.value = locationData.heading!;
    }

    final dist = _locationProcessor.updateDistance(
        currentList, pos, locationData, _sessionManager.totalDistanceMeters);
    _sessionManager.updateDistance(dist - _sessionManager.totalDistanceMeters);

    notifyListeners();
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _isCompassActive = true;
        if (speedNotifier.value < 3.0) {
          headingNotifier.value = event.heading!;
        }
      }
    });
  }

  // ──────────────────────────────────────────────────────────────
  // SYNC
  // ──────────────────────────────────────────────────────────────

  Future<void> _performSync() async {
    if (!_isConnected || !isTracking) return;

    try {
      final rawData = await LocalDatabase.instance.getUnsyncedRaw(100);
      if (rawData.isEmpty) return;

      final result = await compute(_parsePointsInBackground, rawData);
      final points = result['points'] as List<data.LocationPoint>;
      final ids    = result['ids'] as List<int>;

      final syncResult = await _apiService
          .sendLocationData(points)
          .timeout(const Duration(seconds: 10));

      if (syncResult['success'] == true) {
        await LocalDatabase.instance.clearPointsByIds(ids);
      } else if (syncResult['statusCode'] == 404) {
        _log.w('Sync: session 404 — treating as dead session.');
        await LocalDatabase.instance.clearPointsByIds(ids);
        await stopSession((_,  __) {}, isDead: true);
      }
    } catch (e) {
      _log.w('Sync skipped: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HARDWARE MANAGEMENT
  // ──────────────────────────────────────────────────────────────

  void _resumeGpsAndSync() {
    WakelockPlus.enable();

    try {
      _location.enableBackgroundMode(enable: true);
    } catch (_) {}

    _location.changeSettings(
      accuracy: LocationAccuracy.navigation,
      interval: 1000,
      distanceFilter: 0,
    );

    _gpsSubscription = _location.onLocationChanged.listen(
          (loc) => _locationProcessor.processLocationData(
          loc, polylineNotifier.value),
    );

    _syncTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _performSync(),
    );
  }

  void _cleanupGpsAndSync() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    _syncTimer?.cancel();
    _syncTimer = null;

    try {
      _location.enableBackgroundMode(enable: false);
      WakelockPlus.disable();
    } catch (_) {}

    _dbBuffer.flush();
  }

  // ──────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  void _resetMapState() {
    polylineNotifier.value = [];
    speedNotifier.value = 0;
    accuracyNotifier.value = 0;
    headingNotifier.value = 0;
  }

  Future<bool> _checkPermissions() async {
    try {
      var status = await _location.hasPermission();
      if (status == PermissionStatus.denied) {
        status = await _location.requestPermission();
      }
      return status == PermissionStatus.granted ||
          status == PermissionStatus.grantedLimited;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      username = _apiService.getUsername();
      notifyListeners();
    } catch (_) {}
  }

  void _initConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((res) {
          _isConnected = !res.contains(ConnectivityResult.none);
          notifyListeners();
        });
  }
}
