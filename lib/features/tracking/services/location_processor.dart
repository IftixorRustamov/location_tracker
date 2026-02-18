import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:location_tracker/data/models/location_point.dart';

class LocationProcessor {
  final Function(LatLng position, LocationData data) onValidLocation;
  final Function(LocationPoint point) onPointBuffered;

  LocationData? _latestLocationData;

  static const double _minAccuracy = 200.0;
  static const double _minDistance = 0.5;

  LocationProcessor({
    required this.onValidLocation,
    required this.onPointBuffered,
  });

  void processLocationData(LocationData loc, List<LatLng> currentPolyline) {
    // 1. Check Accuracy (Relaxed for indoors)
    if (!_isValidLocation(loc)) return;

    _latestLocationData = loc;
    final newPos = LatLng(loc.latitude!, loc.longitude!);

    // 2. Check Distance (Sensitivity)
    if (_shouldAddPoint(currentPolyline, newPos)) {
      onValidLocation(newPos, loc);
      _bufferPoint(loc);
    }
  }

  bool _isValidLocation(LocationData loc) {
    return loc.latitude != null &&
        loc.longitude != null &&
        (loc.accuracy ?? 100) <= _minAccuracy;
  }

  bool _shouldAddPoint(List<LatLng> polyline, LatLng newPos) {
    if (polyline.isEmpty) return true;
    final distance = const Distance().as(LengthUnit.Meter, polyline.last, newPos);
    return distance >= _minDistance;
  }

  void _bufferPoint(LocationData loc) {
    final point = LocationPoint(
      lat: loc.latitude!,
      lon: loc.longitude!,
      accuracy: loc.accuracy ?? 0,
      speed: loc.speed ?? 0,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    onPointBuffered(point);
  }

  LocationData? get latestLocationData => _latestLocationData;

  double calculateSpeedKmh(LocationData loc) {
    final rawSpeed = loc.speed ?? 0;
    return rawSpeed * 3.6;
  }

  double updateDistance(
      List<LatLng> polyline,
      LatLng newPos,
      LocationData loc,
      double currentDistance,
      ) {
    if (polyline.isEmpty) return currentDistance;
    final dist = const Distance().as(LengthUnit.Meter, polyline.last, newPos);

    return currentDistance + dist;
  }
}