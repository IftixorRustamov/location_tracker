import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

mixin TrackingManager<T extends StatefulWidget> on State<T> {
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
      final Location location = Location();

      bool bgEnabled = await location.isBackgroundModeEnabled();

      if (enable && !bgEnabled) {
        await location.enableBackgroundMode(enable: true);

        // Android specific config (requires distinct notification setup in native if customization needed)
        debugPrint("🔋 Background Mode: ENABLED");
      }
      else if (!enable && bgEnabled) {
        await location.enableBackgroundMode(enable: false);
        debugPrint("🪫 Background Mode: DISABLED");
      }
    } catch (e) {
      debugPrint("Background Mode Error: $e");
    }
  }

  void stopAllStreams() {
    gpsSubscription?.cancel();
    sessionTimer?.cancel();
    syncTimer?.cancel();
    snapTimer?.cancel();
    WakelockPlus.disable();
    toggleBackgroundMode(false);
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours > 0 ? "${twoDigits(d.inHours)}:" : "";
    return "$hours${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }



  Future<void> toggleScreenAwake(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
        debugPrint("📱 Screen Wakelock: ENABLED");
      } else {
        await WakelockPlus.disable();
        debugPrint("sz Screen Wakelock: DISABLED");
      }
    } catch (e) {
      debugPrint("Wakelock error: $e");
    }
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
