class TrackingConfig {
  const TrackingConfig._();

  //* ============================================================
  //* GPS & LOCATION SETTINGS
  //* ============================================================

  static const int locationUpdateInterval = 5000;

  /// Minimum distance change to trigger update (meters)
  static const double distanceFilter = 3.0;

  /// GPS accuracy level
  static const LocationAccuracy gpsAccuracy = LocationAccuracy.navigation;

  /// Maximum age of cached location before requesting fresh (seconds)
  static const int maxLocationCacheAge = 5;

  //* ============================================================
  //* DATA VALIDATION
  //* ============================================================

  /// Minimum acceptable GPS accuracy (meters)
  /// Reject readings with worse accuracy
  static const double minAccuracyThreshold = 50.0;

  /// Maximum acceptable GPS accuracy for high-quality points (meters)
  static const double goodAccuracyThreshold = 15.0;

  /// Minimum speed to consider as "moving" (km/h)
  static const double movingSpeedThreshold = 1.0;

  /// Maximum realistic speed to prevent GPS spikes (km/h)
  static const double maxRealisticSpeed = 200.0;

  /// Minimum time between valid points (seconds)
  static const int minTimeBetweenPoints = 1;

  //* ============================================================
  //* SYNC & NETWORK
  //* ============================================================

  /// How often to sync data to server (seconds)
  static const int syncInterval = 10;

  /// Batch size for uploading points
  static const int syncBatchSize = 100;

  /// Network timeout for API calls (seconds)
  static const int networkTimeout = 10;

  /// Max retry attempts for failed syncs
  static const int maxSyncRetries = 3;

  /// Delay between retry attempts (seconds)
  static const int retryDelay = 5;

  //* ============================================================
  //* MAP MATCHING & SMOOTHING
  //* ============================================================

  /// How often to request map-matched path (seconds)
  static const int mapMatchingInterval = 15;

  /// Minimum points required before map matching
  static const int minPointsForMatching = 5;

  //* ============================================================
  //* BUFFER & STORAGE
  //* ============================================================

  /// Trigger flush when buffer reaches this size
  static const int bufferFlushThreshold = 50;

  /// Maximum points to keep in memory buffer
  static const int maxBufferSize = 500;

  /// How often to force flush buffer (seconds)
  static const int forceFlushInterval = 30;

  // ============================================================
  // SESSION MANAGEMENT
  // ============================================================

  /// Maximum session duration (hours)
  /// Auto-stop after this to prevent runaway sessions
  static const int maxSessionHours = 12;

  /// Minimum session duration to save (seconds)
  static const int minSessionDuration = 30;

  // ============================================================
  // BATTERY OPTIMIZATION
  // ============================================================

  /// Enable adaptive GPS based on speed
  static const bool enableAdaptiveGps = true;

  /// When stationary, reduce GPS frequency (seconds)
  static const int stationaryUpdateInterval = 5000;

  /// When moving fast, increase GPS frequency (seconds)
  static const int movingUpdateInterval = 1000;

  // ============================================================
  // UI & UX
  // ============================================================

  /// Map zoom level when tracking single user
  static const double trackingZoomLevel = 17.5;

  /// Map animation duration (seconds)
  static const double mapAnimationDuration = 0.8;

  /// Time to show "stale" warning (seconds)
  static const int staleDataThreshold = 60;

  // ============================================================
  // DEBUG
  // ============================================================

  /// Enable verbose logging
  static const bool enableDebugLogging = true;

  /// Log GPS accuracy for every point
  static const bool logGpsAccuracy = true;
}

enum GpsAccuracyTier {
  excellent(0, 10, 'Excellent'),
  good(10, 20, 'Good'),
  fair(20, 50, 'Fair'),
  poor(50, 100, 'Poor'),
  veryPoor(100, double.infinity, 'Very Poor');

  const GpsAccuracyTier(this.min, this.max, this.label);

  final double min;
  final double max;
  final String label;

  static GpsAccuracyTier fromAccuracy(double accuracy) {
    for (final tier in GpsAccuracyTier.values) {
      if (accuracy >= tier.min && accuracy < tier.max) {
        return tier;
      }
    }
    return GpsAccuracyTier.veryPoor;
  }
}

/// Location accuracy enum that matches Flutter's location package
enum LocationAccuracy { powerSave, low, balanced, high, navigation }
