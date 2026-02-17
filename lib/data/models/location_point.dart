class LocationPoint {
  final double lat;
  final double lon;
  final double accuracy;
  final double speed;
  final String timestamp;

  LocationPoint({
    required this.lat,
    required this.lon,
    required this.accuracy,
    required this.speed,
    required this.timestamp,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'accuracy': (accuracy.isNaN || accuracy.isInfinite) ? 0.0 : accuracy,
      'speed': (speed.isNaN || speed.isInfinite) ? 0.0 : speed,
      'timestamp': timestamp,
    };
  }
}