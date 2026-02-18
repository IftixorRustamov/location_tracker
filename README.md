📍 Flutter Location Tracker (Yandex MapKit)
A production-ready Flutter application for real-time location tracking, supporting both high-speed driving and low-speed indoor walking.

This project uses Yandex MapKit for visualization and a robust Offline-First architecture with SQLite buffering to ensure no data is lost, even without internet.

🚀 Key Features
🗺️ Mapping & Visualization

Yandex MapKit Integration: High-performance vector maps with detailed building footprints.

Native User Layer: Uses Yandex’s native blue arrow/dot for smooth rotation and accuracy halos.

Reactive Polyline: Draws the user's path in real-time without screen flicker (optimized via ValueListenableBuilder).

Smart Camera: Auto-follows the user. Disables follow mode on drag; re-enables on "Center" button press.

🧠 Advanced Tracking Logic

Indoor/Pedestrian Mode:

High Sensitivity: Captures movements as small as 0.5 meters.

No Road Snapping: Draws exact path (perfect for off-road or inside buildings) instead of snapping to streets.

Walking Support: Accepts speeds down to 0 km/h (no minimum speed gate).

Drift Filter: Intelligently ignores "ghost movement" (sensor noise) when the device is stationary on a table.

Hybrid Heading System:

Driving (>3 km/h): Uses GPS bearing for accurate direction.

Stopped/Slow: Falls back to the Compass sensor for accurate facing direction.

💾 Data & Sync (Offline-First)

SQLite Buffer: All GPS points are stored locally immediately.

Background Sync: Uploads data in chunks via a background Isolate to prevent UI lag.

Crash-Proof Sessions: Database schema V2 uses end_time to strictly define finished sessions, preventing "zombie sessions" from auto-starting on app restart.

Robust Error Handling: REST API polling with auto-retry. If upload fails, data remains safe in the local DB.

🛠️ Tech Stack
Framework: Flutter (Dart)

Maps: yandex_mapkit

Location: location + flutter_compass

Database: sqflite (Local storage)

State Management: ChangeNotifier + ValueNotifier

Background: wakelock_plus + isolate (for heavy parsing)

Connectivity: connectivity_plus

Android (android/app/src/main/AndroidManifest.xml):

XML
<application ...>
    <meta-data
        android:name="com.yandex.android.map.API_KEY"
        android:value="YOUR_API_KEY_HERE" />
</application>
iOS (ios/Runner/AppDelegate.swift):

Swift
YMKMapKit.setApiKey("YOUR_API_KEY_HERE")
2. Permissions

Android (AndroidManifest.xml):

XML
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
iOS (Info.plist):

XML
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track your route.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location to track you while the phone is locked.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
🐛 Common Issues & Fixes
1. App Crashes on "Start Tracking"

Cause: Android 11/12+ "Permission Denied Forever".

Fix: The code includes a try-catch block around enableBackgroundMode. If it fails, the app continues in foreground mode instead of crashing.

2. Map Line Not Drawing

Cause: Data type mismatch (LatLng vs Point) or caching bugs.

Fix: Ensure MapViewLayer is wrapping YandexMapBackground in a ValueListenableBuilder. The map widget now rebuilds explicitly when points change.

3. "Infinite Loading" on Stop

Cause: Waiting for a 10s sync timeout or Map Matching service.

Fix: stopSession now has a strict 2-second timeout. If sync is slow, it saves locally and closes immediately.
