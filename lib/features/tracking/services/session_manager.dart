import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/features/tracking/services/database_buffer.dart';

class SessionManager {
  final ApiService apiService;
  final DatabaseBuffer dbBuffer;
  final void Function(String message, bool isError) onShowMessage;

  int? _currentSessionId;
  bool _isTracking = false;
  Duration _sessionDuration = Duration.zero;
  double _totalDistanceMeters = 0.0;
  Timer? _sessionTimer;

  // Getters
  bool get isTracking => _isTracking;

  Duration get sessionDuration => _sessionDuration;

  double get totalDistanceKm => _totalDistanceMeters / 1000.0;

  double get totalDistanceMeters => _totalDistanceMeters;

  SessionManager({
    required this.apiService,
    required this.dbBuffer,
    required this.onShowMessage,
  });

  Future<void> restoreSession() async {
    try {
      final activeId = await LocalDatabase.instance.getActiveSessionId();
      if (activeId != null) {
        _currentSessionId = activeId;
        _isTracking = true;
        _startSessionTimer();
        dbBuffer.setSessionId(activeId);
        onShowMessage('Active session recovered', false);
      }
    } catch (_) {}
  }

  /// Starts a new tracking session.
  Future<bool> startSession() async {
    try {
      final result = await apiService.startTrackingSession();

      if (result['success'] == true) {
        final newId = await LocalDatabase.instance.createSession();
        _initializeNewSession(newId);
        onShowMessage('Tracking started', false);
        return true;
      } else if (_is409Conflict(result)) {
        return await _handle409Conflict();
      } else {
        onShowMessage(result['message'] ?? 'Failed to start', true);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('409')) {
        return await _handle409Conflict();
      }
      onShowMessage('Failed to start tracking', true);
      return false;
    }
  }

  Future<void> stopSession({bool isDeadSession = false}) async {
    _stopSessionTimer();

    if (_currentSessionId != null) {
      await LocalDatabase.instance.closeSession(
        _currentSessionId!,
        totalDistanceKm,
        _sessionDuration.inSeconds,
      );
    }

    if (!isDeadSession) {
      try {
        await apiService.stopTrackingSession();
      } catch (_) {}
    }

    _isTracking = false;
    _currentSessionId = null;

    if (!isDeadSession) onShowMessage('Session Saved!', false);
  }

  void updateDistance(double deltaMeters) {
    if (deltaMeters > 0) {
      _totalDistanceMeters += deltaMeters;
    }
  }

  void dispose() {
    _stopSessionTimer();
  }

  void _initializeNewSession(int id) {
    _currentSessionId = id;
    _isTracking = true;
    _sessionDuration = Duration.zero;
    _totalDistanceMeters = 0.0;
    dbBuffer.setSessionId(id);
    _startSessionTimer();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionDuration += const Duration(seconds: 1);
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  bool _is409Conflict(Map<String, dynamic> result) {
    final msg = (result['message'] ?? '').toString().toLowerCase();
    return result['statusCode'] == 409 ||
        msg.contains('already active') ||
        msg.contains('already running');
  }

  Future<bool> _handle409Conflict() async {
    final activeLocalId = await LocalDatabase.instance.getActiveSessionId();

    if (activeLocalId != null) {
      await restoreSession();
      return true;
    } else {
      try {
        await apiService.stopTrackingSession();
        await Future.delayed(const Duration(milliseconds: 1000));
        return await startSession();
      } catch (e) {
        debugPrint('Zombie session fix failed: $e');
        onShowMessage('Failed to resolve conflict', true);
        return false;
      }
    }
  }
}
