import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location_tracker/core/utils/app_logger.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../core/config/tracking_config.dart';
import '../../../core/services/admin_api_service.dart';

/// Simplified controller for admin live map
class AdminLiveMapController extends ChangeNotifier {
  final AdminApiService _apiService;
  final AdminSession? _targetSession;

  // Map controller
  final Completer<YandexMapController> mapControllerCompleter = Completer();

  // State
  StreamSubscription<LiveLocationUpdate>? _streamSubscription;
  final Map<String, LiveLocationUpdate> _activeSessions = {};

  String? _selectedSessionId;
  String? _selectedDriverName;
  bool _isFollowing = true;
  bool _isConnected = false;

  AdminLiveMapController({
    required AdminApiService apiService,
    AdminSession? targetSession,
  })  : _apiService = apiService,
        _targetSession = targetSession {
    if (_targetSession != null) {
      _selectedSessionId = _targetSession.id;
      _selectedDriverName = _targetSession.name;
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================

  Map<String, LiveLocationUpdate> get activeSessions => _activeSessions;
  String? get selectedSessionId => _selectedSessionId;
  String? get selectedDriverName => _selectedDriverName;
  bool get isFollowing => _isFollowing;
  bool get isConnected => _isConnected;
  int get activeDriverCount => _activeSessions.length;

  LiveLocationUpdate? get selectedUpdate =>
      _selectedSessionId != null ? _activeSessions[_selectedSessionId] : null;

  // ============================================================
  // PUBLIC METHODS
  // ============================================================

  /// Start streaming live locations
  void startStreaming() {
    if (_streamSubscription != null) {
      AppLogger.warning('Already streaming');
      return;
    }

    _isConnected = true;
    notifyListeners();

    _streamSubscription = _apiService.streamAllLiveLocations().listen(
      _handleLocationUpdate,
      onError: _handleStreamError,
      onDone: _handleStreamDone,
    );

    AppLogger.info('Live location streaming started');
  }

  /// Stop streaming
  void stopStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isConnected = false;
    notifyListeners();

    AppLogger.info('Live location streaming stopped');
  }

  /// Select a driver to track
  void selectDriver(String sessionId, String driverName) {
    _selectedSessionId = sessionId;
    _selectedDriverName = driverName;
    _isFollowing = true;
    notifyListeners();

    AppLogger.debug('Selected driver: $driverName');
  }

  /// Deselect current driver
  void deselectDriver() {
    _selectedSessionId = null;
    _selectedDriverName = null;
    _isFollowing = false;
    notifyListeners();
  }

  /// Toggle auto-follow mode
  void toggleFollow(bool enabled) {
    _isFollowing = enabled;
    notifyListeners();
  }

  /// Recenter map on selected driver or all drivers
  Future<void> recenterMap() async {
    final controller = await mapControllerCompleter.future;

    if (_selectedSessionId != null &&
        _activeSessions.containsKey(_selectedSessionId)) {
      // Center on selected driver
      _isFollowing = true;
      final update = _activeSessions[_selectedSessionId]!;
      await _animateToPoint(
        controller,
        Point(latitude: update.lat, longitude: update.lon),
      );
    } else if (_activeSessions.isNotEmpty) {
      // Fit all drivers
      await _fitAllDrivers(controller);
    }

    notifyListeners();
  }

  /// Initialize map (called after map creation)
  Future<void> initializeMap() async {
    if (_targetSession != null) {
      // Wait for map to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if we already have location data for the target
      if (_activeSessions.containsKey(_targetSession.id)) {
        final update = _activeSessions[_targetSession.id]!;
        final controller = await mapControllerCompleter.future;
        await _animateToPoint(
          controller,
          Point(latitude: update.lat, longitude: update.lon),
        );
        AppLogger.debug('Zoomed to existing target location');
      } else {
        // Data will arrive soon, zoom will happen in _handleLocationUpdate
        AppLogger.debug('Waiting for target location data...');
      }
    }
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  void _handleLocationUpdate(LiveLocationUpdate update) {
    // Check if this is the first time seeing the target session
    final isFirstTimeSeenTarget = _targetSession != null &&
        update.sessionId == _targetSession.id &&
        !_activeSessions.containsKey(update.sessionId);

    _activeSessions[update.sessionId] = update;

    // Initial zoom to target when first seen
    if (isFirstTimeSeenTarget && _isFollowing) {
      _followDriver(update);
      AppLogger.debug('Initial zoom to target: ${update.username}');
    }
    // Auto-follow selected driver
    else if (_isFollowing && _selectedSessionId == update.sessionId) {
      _followDriver(update);
    }

    notifyListeners();
  }

  void _handleStreamError(dynamic error) {
    AppLogger.error('Live location stream error: $error');
    _isConnected = false;
    notifyListeners();
  }

  void _handleStreamDone() {
    AppLogger.info('Live location stream closed');
    _isConnected = false;
    notifyListeners();
  }

  /// Handle camera movement by user (disables auto-follow)
  void onCameraPositionChanged(
      CameraPosition position,
      CameraUpdateReason reason,
      bool finished,
      ) {
    if (reason == CameraUpdateReason.gestures) {
      _isFollowing = false;
      notifyListeners();
    }
  }

  /// Handle map tap (disables auto-follow)
  void onMapTap(Point point) {
    _isFollowing = false;
    notifyListeners();
  }

  /// Handle marker tap (select driver)
  void onMarkerTap(String sessionId, String username) {
    selectDriver(sessionId, username);
  }

  // ============================================================
  // CAMERA CONTROL
  // ============================================================

  Future<void> _followDriver(LiveLocationUpdate update) async {
    try {
      final controller = await mapControllerCompleter.future;
      await _animateToPoint(
        controller,
        Point(latitude: update.lat, longitude: update.lon),
      );
    } catch (e) {
      AppLogger.error('Camera follow error: $e');
    }
  }

  Future<void> _animateToPoint(
      YandexMapController controller,
      Point point,
      ) async {
    await controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: TrackingConfig.trackingZoomLevel,
          tilt: 0,
          azimuth: 0,
        ),
      ),
      animation: MapAnimation(
        type: MapAnimationType.smooth,
        duration: TrackingConfig.mapAnimationDuration,
      ),
    );
  }

  Future<void> _fitAllDrivers(YandexMapController controller) async {
    if (_activeSessions.isEmpty) return;

    // Calculate bounds
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;

    for (var session in _activeSessions.values) {
      if (session.lat < minLat) minLat = session.lat;
      if (session.lat > maxLat) maxLat = session.lat;
      if (session.lon < minLon) minLon = session.lon;
      if (session.lon > maxLon) maxLon = session.lon;
    }

    await controller.moveCamera(
      CameraUpdate.newBounds(
        BoundingBox(
          northEast: Point(latitude: maxLat, longitude: maxLon),
          southWest: Point(latitude: minLat, longitude: minLon),
        ),
        focusRect: const ScreenRect(
          topLeft: ScreenPoint(x: 50, y: 50),
          bottomRight: ScreenPoint(x: 50, y: 50),
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.0,
      ),
    );
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  /// Get time since last update
  String getTimeSinceUpdate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final diff = DateTime.now().toUtc().difference(date);

      if (diff.inSeconds < 60) {
        return 'Updated ${diff.inSeconds}s ago';
      }
      if (diff.inMinutes < 60) {
        return 'Updated ${diff.inMinutes}m ago';
      }

      // Mark as stale
      return 'Updated ${diff.inHours}h ago (STALE)';
    } catch (e) {
      return 'Live';
    }
  }

  /// Check if data is stale
  bool isDataStale(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final diff = DateTime.now().toUtc().difference(date);
      return diff.inSeconds > TrackingConfig.staleDataThreshold;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
