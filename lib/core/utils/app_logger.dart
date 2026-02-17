import 'package:flutter/foundation.dart';
import '../config/tracking_config.dart';

/// Centralized logging utility
class AppLogger {
  AppLogger._();

  static bool get _isEnabled => TrackingConfig.enableDebugLogging;

  /// Log debug messages (verbose)
  static void debug(String message) {
    if (_isEnabled && kDebugMode) {
      debugPrint('🔍 DEBUG: $message');
    }
  }

  /// Log informational messages
  static void info(String message) {
    if (_isEnabled) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log warnings
  static void warning(String message) {
    if (_isEnabled) {
      debugPrint('⚠️ WARNING: $message');
    }
  }

  /// Log errors
  static void error(String message, [Object? error, StackTrace? stack]) {
    debugPrint('❌ ERROR: $message');
    if (error != null) {
      debugPrint('   └─ $error');
    }
    if (stack != null && kDebugMode) {
      debugPrint('   └─ Stack: $stack');
    }
  }

  /// Log successful operations
  static void success(String message) {
    if (_isEnabled) {
      debugPrint('✅ SUCCESS: $message');
    }
  }

  /// Log network operations
  static void network(String message) {
    if (_isEnabled) {
      debugPrint('🌐 NETWORK: $message');
    }
  }

  /// Log GPS operations
  static void gps(String message) {
    if (_isEnabled && TrackingConfig.logGpsAccuracy) {
      debugPrint('📍 GPS: $message');
    }
  }

  /// Log session lifecycle
  static void session(String message) {
    if (_isEnabled) {
      debugPrint('🏁 SESSION: $message');
    }
  }

  /// Log sync operations
  static void sync(String message) {
    if (_isEnabled) {
      debugPrint('🔄 SYNC: $message');
    }
  }
}