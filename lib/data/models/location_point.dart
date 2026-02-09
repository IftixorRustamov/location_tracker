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
      accuracy: (json['accuracy'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
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
