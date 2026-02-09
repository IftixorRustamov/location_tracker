import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

mixin TrackingManager<T extends StatefulWidget> on State<T> {
  StreamSubscription<LocationData>? gpsSubscription;
  Timer? sessionTimer;
  Timer? syncTimer;
  Timer? snapTimer;

  bool isTracking = false;
  bool isBusy = false;
  bool isOffline = false;
  Duration sessionDuration = Duration.zero;

  void stopAllStreams() {
    gpsSubscription?.cancel();
    sessionTimer?.cancel();
    syncTimer?.cancel();
    snapTimer?.cancel();
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours > 0 ? "${twoDigits(d.inHours)}:" : "";
    return "$hours${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // DRY: Reusable permission check
  Future<bool> checkLocationPermissions(Location location) async {
    bool enabled = await location.serviceEnabled();
    if (!enabled) {
      enabled = await location.requestService();
      if (!enabled) return false;
    }
    PermissionStatus status = await location.hasPermission();
    if (status == PermissionStatus.denied) {
      status = await location.requestPermission();
      if (status != PermissionStatus.granted) return false;
    }
    return true;
  }
}
