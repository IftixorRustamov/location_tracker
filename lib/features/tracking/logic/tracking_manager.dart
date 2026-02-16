import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:location_tracker/core/di/injection_container.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

mixin TrackingManager<T extends StatefulWidget> on State<T> {
  final Location _locationManager = Location();

  StreamSubscription<LocationData>? gpsSubscription;
  Timer? sessionTimer;
  Timer? syncTimer;
  Timer? snapTimer;

  bool isTracking = false;
  bool isBusy = false;
  bool isOffline = false;
  Duration sessionDuration = Duration.zero;

  Future<void> toggleBackgroundMode(bool enable) async {
    try {
      bool bgEnabled = await _locationManager.isBackgroundModeEnabled();

      if (enable && !bgEnabled) {
        await _locationManager.enableBackgroundMode(enable: true);
        debugPrint("🔋 Background Mode: ENABLED");
      } else if (!enable && bgEnabled) {
        await _locationManager.enableBackgroundMode(enable: false);
        debugPrint("🪫 Background Mode: DISABLED");
      }
    } catch (e) {
      debugPrint("⚠️ Background Mode Error: $e");
    }
  }

  Future<void> toggleScreenAwake(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
        debugPrint("📱 Screen Wakelock: ENABLED");
      } else {
        await WakelockPlus.disable();
        debugPrint("💤 Screen Wakelock: DISABLED");
      }
    } catch (e) {
      debugPrint("⚠️ Wakelock error: $e");
    }
  }

  void stopAllStreams() {
    log.d("🛑 Stopping all tracking streams...");

    gpsSubscription?.cancel();
    gpsSubscription = null;

    sessionTimer?.cancel();
    sessionTimer = null;

    syncTimer?.cancel();
    syncTimer = null;

    snapTimer?.cancel();
    snapTimer = null;

    WakelockPlus.disable();
  }

  Future<bool> checkLocationPermissions() async {
    bool serviceEnabled = await _locationManager.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationManager.requestService();
      if (!serviceEnabled) {
        debugPrint("🚫 Location Services (GPS) disabled.");
        return false;
      }
    }

    PermissionStatus permissionGranted = await _locationManager.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationManager.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint("🚫 Location Permission denied.");
        return false;
      }
    }

    if (permissionGranted == PermissionStatus.deniedForever) {
      debugPrint("🚫 Location denied forever. User must open settings.");
      return false;
    }

    return true;
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(d.inMinutes.remainder(60));
    final String seconds = twoDigits(d.inSeconds.remainder(60));

    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }
}
