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
    final lat = json['lat'];
    final lon = json['lon'];
    if (lat == null || lon == null) {
      throw FormatException('LocationPoint requires lat and lon', json.toString());
    }
    return LocationPoint(
      lat: (lat as num).toDouble(),
      lon: (lon as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'accuracy': accuracy,
        'speed': speed,
        'timestamp': timestamp,
      };
}
