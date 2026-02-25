# 📍 Flutter Location Tracker (Yandex MapKit)

![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=for-the-badge)


A production-grade Flutter application for real-time location tracking. This project has been migrated from OpenStreetMap to **Yandex MapKit** for superior performance, detailed building footprints, and reliable background tracking.

It features an **Offline-First** architecture with SQLite buffering, ensuring zero data loss even in poor network conditions.

---

## 🚀 Key Features

### 🗺️ Mapping & Visualization
* **Yandex MapKit Integration:** High-performance vector maps with detailed building footprints (essential for indoor tracking).
* **Native User Layer:** Uses Yandex’s native blue arrow/dot for smooth rotation and accuracy halos.
* **Reactive Polyline:** Draws the user's path in real-time without screen flicker (optimized via `ValueListenableBuilder`).
* **Smart Camera:** Auto-follows the user. Disables follow mode on drag; re-enables instantly on "Center" button press.

### 🧠 Advanced Tracking Logic
* **Indoor/Pedestrian Mode:**
    * **High Sensitivity:** Captures movements as small as **0.5 meters**.
    * **No Road Snapping:** Draws exact path (perfect for off-road or inside buildings) instead of snapping to streets.
    * **Walking Support:** Accepts speeds down to 0 km/h (no minimum speed gate).
* **Drift Filter:** Intelligently ignores "ghost movement" (sensor noise) when the device is stationary on a table.
* **Hybrid Heading System:**
    * **Driving (>3 km/h):** Uses GPS bearing for accurate direction.
    * **Stopped/Slow:** Falls back to the Compass sensor for accurate facing direction.

### 💾 Data & Sync (Offline-First)
* **SQLite Buffer:** All GPS points are stored locally immediately.
* **Background Sync:** Uploads data in chunks via a background Isolate to prevent UI lag.
* **Crash-Proof Sessions:** Database schema V2 uses `end_time` to strictly define finished sessions, preventing "zombie sessions" from auto-starting on app restart.
* **Robust Error Handling:** REST API polling with auto-retry. If upload fails, data remains safe in the local DB.

---

## 🛠️ Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart) | UI & Logic |
| **Maps** | `yandex_mapkit` | Vector Maps & User Layer |
| **Location** | `location` | Raw GPS Stream |
| **Database** | `sqflite` | Local Storage (V2 Schema) |
| **State** | `ChangeNotifier` | Reactive UI Updates |
| **Background** | `wakelock_plus` | Keeps CPU awake during tracking |
| **Parsing** | `isolate` | Heavy data processing off-thread |
