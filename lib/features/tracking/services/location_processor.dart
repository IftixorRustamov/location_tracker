import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:location_tracker/data/models/location_point.dart';

class LocationProcessor {
  final Function(LatLng position, LocationData data) onValidLocation;
  final Function(LocationPoint point) onPointBuffered;

  LocationData? _latestLocationData;

  // 🛠️ RELAXED SETTINGS FOR TESTING
  static const double _minAccuracy = 200.0; // Increased from 25.0 to allow indoor GPS
  static const double _minSpeed = 0.0;      // Reduced to capture stationary points
  static const double _minDistance = 0.0;   // Reduced from 2.0 to capture stationary points

  LocationProcessor({
    required this.onValidLocation,
    required this.onPointBuffered,
  });

  void processLocationData(LocationData loc, List<LatLng> currentPolyline) {
    // 1. Check Quality
    if (!_isValidLocation(loc)) {
      // Log failure reason
      if ((loc.accuracy ?? 999) > _minAccuracy) {
        debugPrint("⚠️ GPS Skipped: Low Accuracy (${loc.accuracy}m > $_minAccuracy)");
      }
      return;
    }

    _latestLocationData = loc;
    final newPos = LatLng(loc.latitude!, loc.longitude!);

    // 2. Check Movement (Always true now for testing)
    if (_shouldAddPoint(currentPolyline, newPos)) {
      onValidLocation(newPos, loc);
      _bufferPoint(loc);
    } else {
      debugPrint("⚠️ GPS Skipped: Didn't move enough");
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
    // DEBUG LOG
    debugPrint("✅ GPS ACCEPTED: ${point.lat}, ${point.lon}");
    onPointBuffered(point);
  }

  LocationData? get latestLocationData => _latestLocationData;

  double calculateSpeedKmh(LocationData loc) {
    final speed = loc.speed ?? 0;
    return speed < _minSpeed ? 0.0 : speed * 3.6;
  }

  double updateDistance(
      List<LatLng> polyline,
      LatLng newPos,
      LocationData loc,
      double currentDistance,
      ) {
    if (polyline.isEmpty) return currentDistance;
    final dist = const Distance().as(LengthUnit.Meter, polyline.last, newPos);

    // Only add distance if accuracy is decent, otherwise distance jumps around
    final errorMargin = (loc.accuracy ?? 5.0).clamp(2.5, 50.0);
    return dist > errorMargin ? currentDistance + dist : currentDistance;
  }
}