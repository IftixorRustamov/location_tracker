import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

///
/// This service handles:
/// - Location permission checks
/// - GPS settings configuration
/// - Background mode management
/// - Wake lock management
/// - Permission status
class HardwareManager {
  final Location _location = Location();

  bool _isBackgroundModeEnabled = false;
  bool _isWakeLockEnabled = false;

  // ============================================================
  // PERMISSIONS
  // ============================================================

  /// Check if location permissions are granted
  Future<bool> hasLocationPermission() async {
    try {
      final status = await _location.hasPermission();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('❌ Permission check error: $e');
      return false;
    }
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      final status = await _location.hasPermission();

      if (status == PermissionStatus.granted) {
        debugPrint('✅ Location permission already granted');
        return true;
      }

      if (status == PermissionStatus.deniedForever) {
        debugPrint('🚫 Location permission denied forever');
        return false;
      }

      final result = await _location.requestPermission();
      final granted = result == PermissionStatus.granted;

      debugPrint(
        granted
            ? '✅ Location permission granted'
            : '🚫 Location permission denied',
      );

      return granted;
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
      return false;
    }
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _location.serviceEnabled();
    } catch (e) {
      debugPrint('❌ Service check error: $e');
      return false;
    }
  }

  /// Request to enable location service
  Future<bool> requestLocationService() async {
    try {
      final enabled = await _location.serviceEnabled();

      if (enabled) {
        debugPrint('✅ Location service already enabled');
        return true;
      }

      final result = await _location.requestService();

      debugPrint(
        result
            ? '✅ Location service enabled'
            : '🚫 Location service disabled by user',
      );

      return result;
    } catch (e) {
      debugPrint('❌ Service request error: $e');
      return false;
    }
  }

  /// Complete permission check (service + permission)
  Future<bool> checkAndRequestPermissions() async {
    // Check and request location service
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      final serviceRequested = await requestLocationService();
      if (!serviceRequested) {
        debugPrint('🚫 Location service not enabled');
        return false;
      }
    }

    // Check and request permission
    final hasPermission = await hasLocationPermission();
    if (!hasPermission) {
      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        debugPrint('🚫 Location permission not granted');
        return false;
      }
    }

    debugPrint('✅ All location permissions granted');
    return true;
  }

  // ============================================================
  // GPS CONFIGURATION
  // ============================================================

  /// Configure GPS settings
  Future<void> configureGPS({
    LocationAccuracy accuracy = LocationAccuracy.navigation,
    int intervalMillis = 1000,
    double distanceFilterMeters = 3.0,
  }) async {
    try {
      await _location.changeSettings(
        accuracy: accuracy,
        interval: intervalMillis,
        distanceFilter: distanceFilterMeters,
      );

      debugPrint('📡 GPS configured: '
          'accuracy=$accuracy, '
          'interval=${intervalMillis}ms, '
          'filter=${distanceFilterMeters}m');
    } catch (e) {
      debugPrint('❌ GPS configuration error: $e');
    }
  }

  // ============================================================
  // BACKGROUND MODE
  // ============================================================

  /// Enable background location tracking
  Future<bool> enableBackgroundMode() async {
    if (_isBackgroundModeEnabled) {
      debugPrint('ℹ️ Background mode already enabled');
      return true;
    }

    try {
      await _location.enableBackgroundMode(enable: true);
      _isBackgroundModeEnabled = true;
      debugPrint('🔋 Background mode enabled');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to enable background mode: $e');
      return false;
    }
  }

  /// Disable background location tracking
  Future<bool> disableBackgroundMode() async {
    if (!_isBackgroundModeEnabled) {
      debugPrint('ℹ️ Background mode already disabled');
      return true;
    }

    try {
      await _location.enableBackgroundMode(enable: false);
      _isBackgroundModeEnabled = false;
      debugPrint('🪫 Background mode disabled');
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to disable background mode: $e');
      return false;
    }
  }

  /// Check if background mode is enabled
  Future<bool> isBackgroundModeEnabled() async {
    try {
      return await _location.isBackgroundModeEnabled();
    } catch (e) {
      debugPrint('❌ Background mode check error: $e');
      return false;
    }
  }

  // ============================================================
  // WAKE LOCK
  // ============================================================

  /// Enable wake lock (keep screen awake)
  Future<bool> enableWakeLock() async {
    if (_isWakeLockEnabled) {
      debugPrint('ℹ️ Wake lock already enabled');
      return true;
    }

    try {
      await WakelockPlus.enable();
      _isWakeLockEnabled = true;
      debugPrint('📱 Wake lock enabled');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to enable wake lock: $e');
      return false;
    }
  }

  /// Disable wake lock (allow screen sleep)
  Future<bool> disableWakeLock() async {
    if (!_isWakeLockEnabled) {
      debugPrint('ℹ️ Wake lock already disabled');
      return true;
    }

    try {
      await WakelockPlus.disable();
      _isWakeLockEnabled = false;
      debugPrint('💤 Wake lock disabled');
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to disable wake lock: $e');
      return false;
    }
  }

  /// Check if wake lock is enabled
  Future<bool> isWakeLockEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      debugPrint('❌ Wake lock check error: $e');
      return false;
    }
  }

  // ============================================================
  // BULK OPERATIONS
  // ============================================================

  /// Start all hardware services
  Future<bool> startAll() async {
    debugPrint('🚀 Starting all hardware services...');

    final permissionsOk = await checkAndRequestPermissions();
    if (!permissionsOk) {
      return false;
    }

    await configureGPS();
    await enableBackgroundMode();
    await enableWakeLock();

    debugPrint('✅ All hardware services started');
    return true;
  }

  /// Stop all hardware services
  Future<void> stopAll() async {
    debugPrint('🛑 Stopping all hardware services...');

    await disableBackgroundMode();
    await disableWakeLock();

    debugPrint('✅ All hardware services stopped');
  }

  // ============================================================
  // STATUS
  // ============================================================

  /// Get current hardware status
  Future<Map<String, bool>> getStatus() async {
    return {
      'has_permission': await hasLocationPermission(),
      'service_enabled': await isLocationServiceEnabled(),
      'background_mode': await isBackgroundModeEnabled(),
      'wake_lock': await isWakeLockEnabled(),
    };
  }

  /// Print current status (for debugging)
  Future<void> printStatus() async {
    final status = await getStatus();
    debugPrint('📊 Hardware Status:');
    debugPrint('  ✓ Permission: ${status['has_permission']}');
    debugPrint('  ✓ Service: ${status['service_enabled']}');
    debugPrint('  ✓ Background: ${status['background_mode']}');
    debugPrint('  ✓ Wake Lock: ${status['wake_lock']}');
  }
}