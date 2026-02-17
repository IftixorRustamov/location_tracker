import 'dart:async';
import 'dart:isolate';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class TrackingController extends ChangeNotifier {
  // === STATE NOTIFIERS ===
  final ValueNotifier<List<LatLng>> polylineNotifier = ValueNotifier([]);
  final ValueNotifier<List<LatLng>> smoothPolylineNotifier = ValueNotifier([]);
  final ValueNotifier<LatLng?> currentPositionNotifier = ValueNotifier(null);
  final ValueNotifier<double> speedNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> accuracyNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier(0.0);

  // === INTERNAL SERVICES ===
  late final DatabaseBuffer _dbBuffer;
  late final SessionManager _sessionManager;
  late final LocationProcessor _locationProcessor;
  final Location _location = Location();

  // === SUBSCRIPTIONS ===
  StreamSubscription<LocationData>? _gpsSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  Timer? _snapTimer;

  bool _isConnected = true;
  bool _isBusy = false;

  // 🛠️ Tracks if the hardware compass is actually sending data
  bool _isCompassActive = false;

  String? username;

  bool get isBusy => _isBusy;
  bool get isTracking => _sessionManager.isTracking;
  bool get isOffline => !_isConnected;
  Duration get sessionDuration => _sessionManager.sessionDuration;
  double get distanceKm => _sessionManager.totalDistanceKm;

  // === INITIALIZATION ===
  Future<void> initialize(Function(String, bool) onMessage) async {
    _dbBuffer = DatabaseBuffer();
    _sessionManager = SessionManager(
      dbBuffer: _dbBuffer,
      onShowMessage: onMessage,
    );

    _locationProcessor = LocationProcessor(
      onValidLocation: _handleValidLocation,
      onPointBuffered: (point) {
        // DEBUG LOG: Point buffered
        debugPrint("💾 Buffering point: ${point.lat}, ${point.lon}");
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

  // === USER ACTIONS ===

  Future<void> toggleTracking(Function(String, bool) onMessage) async {
    if (isTracking) {
      await stopSession(onMessage);
    } else {
      await startSession(onMessage);
    }
  }

  Future<void> startSession(Function(String, bool) onMessage) async {
    debugPrint("🏁 Starting Session Request...");
    _setBusy(true);
    try {
      if (!await _checkPermissions()) {
        debugPrint("🚫 Permissions denied");
        return;
      }

      final success = await _sessionManager.startSession();
      if (success) {
        debugPrint("✅ Session Started Successfully");
        _resumeHardwareServices();
        _resetMapState();
        notifyListeners();
      } else {
        debugPrint("❌ Session Start Failed in Manager");
      }
    } catch (e) {
      debugPrint("❌ Start error: $e");
      onMessage('Failed to start tracking', true);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> stopSession(Function(String, bool) onMessage, {bool isDead = false}) async {
    _setBusy(true);
    try {
      _cleanupHardwareServices();
      await _refinePath();
      if (!isDead) await _performSync(onMessage); // One last sync

      await _sessionManager.stopSession(isDeadSession: isDead);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Stop error: $e");
      onMessage('Error saving session', true);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> centerOnUser() async {
    try {
      final loc = await _location.getLocation();
      if (loc.latitude != null && loc.longitude != null) {
        currentPositionNotifier.value = LatLng(loc.latitude!, loc.longitude!);
      }
    } catch (e) {
      debugPrint("Center error: $e");
    }
  }

  // === INTERNAL LOGIC ===

  void _handleValidLocation(LatLng pos, LocationData data) {
    debugPrint("📍 Valid Location Received: ${pos.latitude}, ${pos.longitude}");

    final currentList = polylineNotifier.value;
    polylineNotifier.value = [...currentList, pos];
    currentPositionNotifier.value = pos;

    final speedKmh = _locationProcessor.calculateSpeedKmh(data);
    speedNotifier.value = speedKmh;
    accuracyNotifier.value = data.accuracy ?? 0;

    // 🛠️ ROTATION LOGIC (Arrow Fix)
    // If moving fast (> 3km/h), GPS heading is better than compass.
    // If compass is dead (Emulator), ALWAYS use GPS heading.
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

  /// 🔍 SYNC LOGIC with DEBUG PRINTS
  Future<void> _performSync(Function(String, bool) onMessage) async {
    if (!_isConnected) {
      debugPrint("⚠️ Sync Skipped: No Internet");
      return;
    }
    if (!isTracking) return;

    try {
      final rawData = await LocalDatabase.instance.getUnsyncedRaw(100);
      if (rawData.isEmpty) {
        // Uncomment to debug idle state:
        // debugPrint("📭 Buffer Empty: No points to send.");
        return;
      }

      debugPrint("🚀 Attempting to sync ${rawData.length} points to server...");

      final result = await Isolate.run(() {
        return {
          'points': rawData.map((e) => data.LocationPoint.fromJson(e)).toList(),
          'ids': rawData.map((e) => e['id'] as int).toList(),
        };
      });

      final points = result['points'] as List<data.LocationPoint>;
      final ids = result['ids'] as List<int>;

      final syncResult = await sl<ApiService>()
          .sendLocationData(points)
          .timeout(const Duration(seconds: 10), onTimeout: () => {'success': false, 'message': 'Timeout'});

      if (syncResult['success'] == true) {
        debugPrint("✅ SUCCESS: Sent ${points.length} points!");
        await LocalDatabase.instance.clearPointsByIds(ids);
      } else if (syncResult['statusCode'] == 404) {
        debugPrint("🛑 Server returned 404: Session Expired");
        onMessage("Session expired", true);
        await LocalDatabase.instance.clearPointsByIds(ids);
        await stopSession(onMessage, isDead: true);
      } else {
        debugPrint("❌ Sync Failed: ${syncResult['statusCode']} - ${syncResult['message']}");
      }
    } catch (e) {
      debugPrint("❌ Sync Exception: $e");
    }
  }

  Future<void> _refinePath() async {
    final polyline = polylineNotifier.value;
    if (polyline.length < 5) return;

    try {
      final snapped = await sl<MapMatchingService>().getSnappedRoute(polyline);
      if (snapped.isNotEmpty) {
        smoothPolylineNotifier.value = snapped;
      }
    } catch (e) {
      debugPrint("Map matching error: $e");
    }
  }

  // === HELPERS ===

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

  void _resumeHardwareServices() {
    WakelockPlus.enable();
    _location.enableBackgroundMode(enable: true);

    _location.changeSettings(
      accuracy: LocationAccuracy.navigation,
      interval: 1000,
      distanceFilter: 3,
    );

    debugPrint("📡 GPS Services Resumed");

    _gpsSubscription = _location.onLocationChanged.listen(
          (loc) => _locationProcessor.processLocationData(loc, polylineNotifier.value),
    );

    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _performSync((_,__) {}));
    _snapTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refinePath());
  }

  void _cleanupHardwareServices() {
    debugPrint("🛑 Cleaning up hardware services...");
    _gpsSubscription?.cancel();
    _compassSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _snapTimer?.cancel();

    try {
      _location.enableBackgroundMode(enable: false);
      WakelockPlus.disable();
    } catch (_) {}

    _dbBuffer.flush();
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

  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _isCompassActive = true;

        // Use compass only at low speeds
        if (speedNotifier.value < 3.0) {
          headingNotifier.value = event.heading!;
        }
      }
    });
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((res) {
      _isConnected = !res.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }
}