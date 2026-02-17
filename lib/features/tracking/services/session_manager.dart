import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/features/tracking/services/database_buffer.dart';

class SessionManager {
  final DatabaseBuffer dbBuffer;
  final Function(String message, bool isError) onShowMessage;

  // Session State
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
    required this.dbBuffer,
    required this.onShowMessage,
  });

  /// Restores an active session from local DB if one exists
  Future<void> restoreSession() async {
    try {
      final activeId = await LocalDatabase.instance.getActiveSessionId();
      if (activeId != null) {
        _currentSessionId = activeId;
        _isTracking = true;
        _startSessionTimer();

        // Link the buffer to this session ID so points can be saved
        dbBuffer.setSessionId(activeId);
        onShowMessage("Active session recovered", false);
      }
    } catch (e) {
      debugPrint("⚠️ Restore session error: $e");
    }
  }

  /// Starts a new tracking session
  Future<bool> startSession() async {
    try {
      // 1. API Call to start
      final result = await sl<ApiService>().startTrackingSession();

      if (result['success'] == true) {
        // 2. Local DB Creation
        final newId = await LocalDatabase.instance.createSession();
        _initializeNewSession(newId);
        onShowMessage("Tracking started", false);
        return true;
      } else if (_is409Conflict(result)) {
        return await _handle409Conflict();
      } else {
        onShowMessage(result['message'] ?? 'Failed to start', true);
        return false;
      }
    } catch (e) {
      debugPrint("❌ Start session exception: $e");
      if (e.toString().contains("409")) {
        return await _handle409Conflict();
      }
      onShowMessage('Failed to start tracking', true);
      return false;
    }
  }

  /// Stops the current session
  Future<void> stopSession({bool isDeadSession = false}) async {
    _stopSessionTimer();

    // Save final stats to DB before clearing ID
    if (_currentSessionId != null) {
      await LocalDatabase.instance.updateSessionStats(
        _currentSessionId!,
        totalDistanceKm,
        _sessionDuration.inSeconds,
      );
    }

    // API Stop (only if the session isn't already dead/404)
    if (!isDeadSession) {
      try {
        await sl<ApiService>().stopTrackingSession();
      } catch (e) {
        debugPrint("⚠️ API Stop error: $e");
      }
    }

    _isTracking = false;
    _currentSessionId = null;

    if (!isDeadSession) onShowMessage("Session Saved!", false);
  }

  void updateDistance(double deltaMeters) {
    if (deltaMeters > 0) {
      _totalDistanceMeters += deltaMeters;
    }
  }

  void dispose() {
    _stopSessionTimer();
  }

  // ==========================================
  // INTERNAL HELPERS
  // ==========================================

  void _initializeNewSession(int id) {
    _currentSessionId = id;
    _isTracking = true;
    _sessionDuration = Duration.zero;
    _totalDistanceMeters = 0.0;

    // CRITICAL: Tell buffer where to save points!
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
    final msg = result['message'].toString().toLowerCase();
    return result['statusCode'] == 409 ||
        msg.contains("already active") ||
        msg.contains("already running");
  }

  Future<bool> _handle409Conflict() async {
    debugPrint("⚠️ 409 Conflict: Server has active session");
    final activeLocalId = await LocalDatabase.instance.getActiveSessionId();

    if (activeLocalId != null) {
      debugPrint("✅ Local session found. Resuming...");
      await restoreSession();
      return true;
    } else {
      debugPrint("🧟 Zombie session detected! Force-stopping...");
      try {
        await sl<ApiService>().stopTrackingSession();
        // Wait briefly for server to process stop
        await Future.delayed(const Duration(milliseconds: 1000));
        // Retry start
        return await startSession();
      } catch (e) {
        debugPrint("Zombie fix failed: $e");
        onShowMessage("Failed to resolve conflict", true);
        return false;
      }
    }
  }
}