import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../core/config/tracking_config.dart';
import '../../../core/services/admin_api_service.dart';
import 'package:logger/logger.dart';

/// Improved admin live map controller with better debugging
class AdminLiveMapController extends ChangeNotifier {
  static final _log = Logger();

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
  bool _hasPerformedInitialZoom = false;

  // Stats for debugging
  int _updateCount = 0;
  DateTime? _lastUpdateTime;

  AdminLiveMapController({
    required AdminApiService apiService,
    AdminSession? targetSession,
  })  : _apiService = apiService,
        _targetSession = targetSession {
    if (_targetSession != null) {
      _selectedSessionId = _targetSession.id;
      _selectedDriverName = _targetSession.name;
      _log.i('🎯 Target session set: ${_targetSession.name} (${_targetSession.id})');
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
  int get updateCount => _updateCount;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  LiveLocationUpdate? get selectedUpdate =>
      _selectedSessionId != null ? _activeSessions[_selectedSessionId] : null;

  // ============================================================
  // PUBLIC METHODS
  // ============================================================

  /// Start streaming live locations
  void startStreaming() {
    if (_streamSubscription != null) {
      _log.w('⚠️ Already streaming');
      return;
    }

    _log.i('🚀 Starting live location stream...');
    _isConnected = true;
    _updateCount = 0;
    notifyListeners();

    _streamSubscription = _apiService.streamAllLiveLocations().listen(
      _handleLocationUpdate,
      onError: _handleStreamError,
      onDone: _handleStreamDone,
      cancelOnError: false, // Keep streaming even on errors
    );

    _log.i('✅ Live location stream started');
  }

  /// Stop streaming
  void stopStreaming() {
    _log.i('🛑 Stopping live location stream...');

    _streamSubscription?.cancel();
    _streamSubscription = null;
    _isConnected = false;

    notifyListeners();

    _log.i('✅ Live location stream stopped');
  }

  /// Select a driver to track
  void selectDriver(String sessionId, String driverName) {
    _log.d('👤 Selected driver: $driverName ($sessionId)');

    _selectedSessionId = sessionId;
    _selectedDriverName = driverName;
    _isFollowing = true;

    notifyListeners();
  }

  /// Deselect current driver
  void deselectDriver() {
    _log.d('❌ Deselected driver');

    _selectedSessionId = null;
    _selectedDriverName = null;
    _isFollowing = false;

    notifyListeners();
  }

  /// Toggle auto-follow mode
  void toggleFollow(bool enabled) {
    _log.d('🔄 Auto-follow: ${enabled ? "ON" : "OFF"}');

    _isFollowing = enabled;
    notifyListeners();
  }

  /// Recenter map on selected driver or all drivers
  Future<void> recenterMap() async {
    _log.d('🎯 Recenter requested');

    final controller = await mapControllerCompleter.future;

    if (_selectedSessionId != null &&
        _activeSessions.containsKey(_selectedSessionId)) {
      // Center on selected driver
      _isFollowing = true;
      final update = _activeSessions[_selectedSessionId]!;

      _log.i('📍 Centering on ${update.username}');

      await _animateToPoint(
        controller,
        Point(latitude: update.lat, longitude: update.lon),
      );
    } else if (_activeSessions.isNotEmpty) {
      // Fit all drivers
      _log.i('🗺️ Fitting ${_activeSessions.length} drivers');
      await _fitAllDrivers(controller);
    } else {
      _log.w('⚠️ No active sessions to center on');
    }

    notifyListeners();
  }

  /// Initialize map (called after map creation)
  Future<void> initializeMap() async {
    _log.i('🗺️ Initializing map...');

    if (_targetSession != null) {
      // Wait for map to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if we already have location data for the target
      if (_activeSessions.containsKey(_targetSession.id)) {
        final update = _activeSessions[_targetSession.id]!;
        final controller = await mapControllerCompleter.future;

        _log.i('✅ Target data exists, zooming to ${update.username}');

        await _animateToPoint(
          controller,
          Point(latitude: update.lat, longitude: update.lon),
        );

        _hasPerformedInitialZoom = true;
      } else {
        // Data will arrive soon, zoom will happen in _handleLocationUpdate
        _log.d('⏳ Waiting for target location data...');
      }
    }

    _log.i('✅ Map initialization complete');
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  void _handleLocationUpdate(LiveLocationUpdate update) {
    _updateCount++;
    _lastUpdateTime = DateTime.now();

    // Validate update
    if (!update.hasValidCoordinates) {
      _log.w('⚠️ Invalid coordinates for ${update.username}: (${update.lat}, ${update.lon})');
      return;
    }

    // Check if this is the first time seeing the target session
    final isFirstTimeSeenTarget = _targetSession != null &&
        update.sessionId == _targetSession.id &&
        !_activeSessions.containsKey(update.sessionId) &&
        !_hasPerformedInitialZoom;

    // Check if this is a new session
    final isNewSession = !_activeSessions.containsKey(update.sessionId);

    _activeSessions[update.sessionId] = update;

    if (isNewSession) {
      _log.i('✨ New session: ${update.username} (${update.sessionId})');
    } else {
      _log.d('📍 Update #$_updateCount: ${update.username} @ (${update.lat}, ${update.lon})');
    }

    // Initial zoom to target when first seen
    if (isFirstTimeSeenTarget && _isFollowing) {
      _log.i('🎯 Initial zoom to target: ${update.username}');
      _hasPerformedInitialZoom = true;
      _followDriver(update);
    }
    // Auto-follow selected driver
    else if (_isFollowing && _selectedSessionId == update.sessionId) {
      _log.d('🔄 Following ${update.username}');
      _followDriver(update);
    }

    notifyListeners();
  }

  void _handleStreamError(dynamic error) {
    _log.e('❌ Live location stream error: $error');
    _isConnected = false;
    notifyListeners();
  }

  void _handleStreamDone() {
    _log.w('⚠️ Live location stream closed');
    _isConnected = false;
    notifyListeners();
  }

  /// Handle camera movement by user (disables auto-follow)
  void onCameraPositionChanged(
      CameraPosition position,
      CameraUpdateReason reason,
      bool finished,
      ) {
    if (reason == CameraUpdateReason.gestures && _isFollowing) {
      _log.d('👆 User gesture detected, disabling auto-follow');
      _isFollowing = false;
      notifyListeners();
    }
  }

  /// Handle map tap (disables auto-follow)
  void onMapTap(Point point) {
    if (_isFollowing) {
      _log.d('👆 Map tapped, disabling auto-follow');
      _isFollowing = false;
      notifyListeners();
    }
  }

  /// Handle marker tap (select driver)
  void onMarkerTap(String sessionId, String username) {
    _log.d('📌 Marker tapped: $username');
    selectDriver(sessionId, username);

    // Immediately zoom to the tapped marker
    if (_activeSessions.containsKey(sessionId)) {
      final update = _activeSessions[sessionId]!;
      _followDriver(update);
    }
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
      _log.e('❌ Camera follow error: $e');
    }
  }

  Future<void> _animateToPoint(
      YandexMapController controller,
      Point point,
      ) async {
    try {
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
    } catch (e) {
      _log.e('❌ Camera animation error: $e');
    }
  }

  Future<void> _fitAllDrivers(YandexMapController controller) async {
    if (_activeSessions.isEmpty) return;

    try {
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
    } catch (e) {
      _log.e('❌ Fit bounds error: $e');
    }
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

  /// Get debug info for troubleshooting
  Map<String, dynamic> getDebugInfo() {
    return {
      'is_connected': _isConnected,
      'is_following': _isFollowing,
      'active_sessions': _activeSessions.length,
      'selected_session': _selectedSessionId,
      'target_session': _targetSession?.id,
      'update_count': _updateCount,
      'last_update': _lastUpdateTime?.toString(),
      'has_initial_zoom': _hasPerformedInitialZoom,
    };
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _log.i('🧹 Disposing controller...');
    stopStreaming();
    super.dispose();
  }
}