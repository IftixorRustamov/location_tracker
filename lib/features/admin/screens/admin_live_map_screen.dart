import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/features/admin/widgets/live_map/driver_info_card.dart';
import 'package:location_tracker/features/admin/widgets/live_map/map_header.dart';
import 'package:location_tracker/features/admin/widgets/live_map/recenter_button.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class AdminLiveMapScreen extends StatefulWidget {
  // Make these optional. If provided, we "lock" onto this driver initially.
  final String? initialSessionId;
  final String? initialDriverName;
  final AdminApiService apiService;

  const AdminLiveMapScreen({
    super.key,
    this.initialSessionId,
    this.initialDriverName,
    required this.apiService,
  });

  @override
  State<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _AdminLiveMapScreenState extends State<AdminLiveMapScreen> {
  final Completer<YandexMapController> _controllerCompleter = Completer();

  // Stream & Data
  StreamSubscription<LiveLocationUpdate>? _streamSubscription;
  final Map<String, LiveLocationUpdate> _activeSessions = {};

  // Selection State
  String? _selectedSessionId;
  String? _selectedDriverName; // Store name if available
  bool _isFollowing = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    // If opened for a specific user, select them immediately
    if (widget.initialSessionId != null) {
      _selectedSessionId = widget.initialSessionId;
      _selectedDriverName = widget.initialDriverName;
    }

    _startLiveStream();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _startLiveStream() {
    setState(() => _isConnected = true);

    _streamSubscription = widget.apiService.streamAllLiveLocations().listen(
          (update) {
        if (!mounted) return;

        setState(() {
          // Update the specific session in our map
          _activeSessions[update.sessionId] = update;

          // If we are following a specific user, move camera
          if (_isFollowing && _selectedSessionId == update.sessionId) {
            _moveCameraToPoint(Point(latitude: update.lat, longitude: update.lon));
          }
        });
      },
      onError: (e) {
        debugPrint("❌ Stream Error: $e");
        setState(() => _isConnected = false);
        // Retry logic could go here
      },
      onDone: () {
        debugPrint("⚠️ Stream Closed");
        setState(() => _isConnected = false);
      },
    );
  }

  Future<void> _moveCameraToPoint(Point point) async {
    final controller = await _controllerCompleter.future;
    controller.moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 17)),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
    );
  }

  void _onMarkerTap(LiveLocationUpdate update) {
    setState(() {
      _selectedSessionId = update.sessionId;
      // If the update object had a name field, we would use it here.
      // For now, if it matches the initial session, use that name, else show ID.
      if (update.sessionId == widget.initialSessionId) {
        _selectedDriverName = widget.initialDriverName;
      } else {
        final id = update.sessionId;
        _selectedDriverName = "Session #${id.length >= 4 ? id.substring(0, 4) : id}";
      }
      _isFollowing = true;
    });
    _moveCameraToPoint(Point(latitude: update.lat, longitude: update.lon));
  }

  void _recenter() {
    if (_selectedSessionId != null && _activeSessions.containsKey(_selectedSessionId)) {
      // 1. Follow Selected Driver
      setState(() => _isFollowing = true);
      final user = _activeSessions[_selectedSessionId]!;
      _moveCameraToPoint(Point(latitude: user.lat, longitude: user.lon));
    } else {
      // 2. Or Fit All Drivers (Zoom Out)
      _fitAllDrivers();
    }
  }

  Future<void> _fitAllDrivers() async {
    if (_activeSessions.isEmpty) return;

    // Simple logic: just zoom out to a city level or calculate bounds if needed
    // For simplicity, let's just zoom out to default city view
    final controller = await _controllerCompleter.future;
    // You can implement calculateBounds logic here if you have latlong2 package
    // For now, let's just reset zoom.
    controller.moveCamera(
      CameraUpdate.zoomTo(12),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prepare Markers
    final mapObjects = _activeSessions.values.map((session) {
      final isSelected = session.sessionId == _selectedSessionId;

      return PlacemarkMapObject(
        mapId: MapObjectId('session_${session.sessionId}'),
        point: Point(latitude: session.lat, longitude: session.lon),
        opacity: 1.0,
        zIndex: isSelected ? 10 : 1, // Selected sits on top
        // Scale up if selected
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage(SecondaryConstants.carIcon),
            scale: isSelected ? 1.0 : 0.7,
            rotationType: RotationType.rotate,
          ),
        ),
        onTap: (obj, point) => _onMarkerTap(session),
      );
    }).toList();

    // Data for Bottom Card
    final selectedUpdate = _selectedSessionId != null
        ? _activeSessions[_selectedSessionId]
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // 1. MAP LAYER
          YandexMap(
            onMapCreated: (c) => _controllerCompleter.complete(c),
            mapObjects: mapObjects,
            onCameraPositionChanged: (cameraPosition, reason, finished) {
              if (reason == CameraUpdateReason.gestures) {
                // Stop following if user drags the map
                setState(() => _isFollowing = false);
              }
            },
            // Tap on empty map to deselect
            onMapTap: (_) {
              setState(() {
                _selectedSessionId = null;
                _isFollowing = false;
              });
            },
          ),

          // 2. HEADER
          Align(
            alignment: Alignment.topCenter,
            child: MapHeader(
              title: _selectedSessionId != null
                  ? "Tracking: $_selectedDriverName"
                  : "Live Fleet (${_activeSessions.length} Active)",
              onBackPressed: () => Navigator.pop(context),
            ),
          ),

          // 3. CONNECTION STATUS INDICATOR
          if (!_isConnected)
            Positioned(
              top: 100,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Connecting to Live Stream...",
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // 4. RECENTER BUTTON
          Positioned(
            right: 16,
            bottom: selectedUpdate != null ? 220 : 40,
            child: RecenterButton(
              onPressed: _recenter,
              // Change icon based on mode (Follow vs Fit All)
              // You can pass an icon parameter to RecenterButton if you update it
            ),
          ),

          // 5. BOTTOM INFO CARD
          if (selectedUpdate != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: DriverInfoCard(
                driverName: _selectedDriverName ?? "Unknown Driver",
                status: "Speed: ${selectedUpdate.speed.toStringAsFixed(1)} km/h",
                lastUpdated: DateFormat('hh:mm:ss a').format(DateTime.now()),
              ),
            ),
        ],
      ),
    );
  }
}