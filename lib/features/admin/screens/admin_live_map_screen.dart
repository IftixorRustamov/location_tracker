import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:location_tracker/core/constants/secondary.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/features/admin/widgets/live_map/driver_info_card.dart';
import 'package:location_tracker/features/admin/widgets/live_map/map_header.dart';
import 'package:location_tracker/features/admin/widgets/live_map/recenter_button.dart';

/// Original implementation with initial zoom fix
class AdminLiveMapScreenDirect extends StatefulWidget {
  final AdminSession? targetSession;
  final AdminApiService apiService;

  const AdminLiveMapScreenDirect({
    super.key,
    this.targetSession,
    required this.apiService,
  });

  @override
  State<AdminLiveMapScreenDirect> createState() => _AdminLiveMapScreenDirectState();
}

class _AdminLiveMapScreenDirectState extends State<AdminLiveMapScreenDirect> {
  final Completer<YandexMapController> _controllerCompleter = Completer();

  // State
  StreamSubscription<LiveLocationUpdate>? _streamSubscription;
  final Map<String, LiveLocationUpdate> _activeSessions = {};

  String? _selectedSessionId;
  String? _selectedDriverName;
  bool _isFollowing = true;
  bool _isConnected = false;
  bool _hasPerformedInitialZoom = false; // NEW: Track if initial zoom is done

  @override
  void initState() {
    super.initState();
    if (widget.targetSession != null) {
      _selectedSessionId = widget.targetSession!.id;
      _selectedDriverName = widget.targetSession!.name;
    }
    _startPolling();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _startPolling() {
    setState(() => _isConnected = true);

    _streamSubscription = widget.apiService.streamAllLiveLocations().listen(
          (update) {
        if (!mounted) return;

        setState(() {
          // 🎯 FIX: Check if this is the FIRST TIME seeing the target session
          final isFirstTimeSeenTarget = widget.targetSession != null &&
              update.sessionId == widget.targetSession!.id &&
              !_activeSessions.containsKey(update.sessionId) &&
              !_hasPerformedInitialZoom;

          _activeSessions[update.sessionId] = update;

          // 🚀 Initial Zoom: When we first see our target, zoom to them
          if (isFirstTimeSeenTarget && _isFollowing) {
            _hasPerformedInitialZoom = true;
            debugPrint("🎯 Initial zoom to target: ${update.username}");
            _animateCamera(Point(latitude: update.lat, longitude: update.lon));
          }
          // 🔄 Auto-follow: Continue following if enabled
          else if (_isFollowing && _selectedSessionId == update.sessionId) {
            _animateCamera(Point(latitude: update.lat, longitude: update.lon));
          }
        });
      },
      onError: (e) => setState(() => _isConnected = false),
    );
  }

  // 🛠️ CAMERA LOGIC
  Future<void> _animateCamera(Point point) async {
    try {
      final controller = await _controllerCompleter.future;

      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: point,
            zoom: 17.0, // High zoom to see the street
            tilt: 0,
            azimuth: 0,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.5,
        ),
      );
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // 🛠️ RECENTER BUTTON ACTION
  void _onRecenterPressed() async {
    final controller = await _controllerCompleter.future;

    if (_selectedSessionId != null && _activeSessions.containsKey(_selectedSessionId)) {
      // CASE 1: Lock onto selected driver
      setState(() => _isFollowing = true);
      final user = _activeSessions[_selectedSessionId]!;

      // 🚀 ACTION: Move Immediately!
      _animateCamera(Point(latitude: user.lat, longitude: user.lon));

    } else if (_activeSessions.isNotEmpty) {
      // CASE 2: Fit all drivers
      double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;

      for (var s in _activeSessions.values) {
        if (s.lat < minLat) minLat = s.lat;
        if (s.lat > maxLat) maxLat = s.lat;
        if (s.lon < minLon) minLon = s.lon;
        if (s.lon > maxLon) maxLon = s.lon;
      }

      await controller.moveCamera(
        CameraUpdate.newBounds(
          BoundingBox(
            northEast: Point(latitude: maxLat, longitude: maxLon),
            southWest: Point(latitude: minLat, longitude: minLon),
          ),
          focusRect: const ScreenRect(
            topLeft: ScreenPoint(x: 50, y: 50),
            bottomRight: ScreenPoint(x: 50, y: 50),
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.8,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapObjects = _activeSessions.values.map((session) {
      final isSelected = session.sessionId == _selectedSessionId;

      return PlacemarkMapObject(
        mapId: MapObjectId('user_${session.sessionId}'),
        point: Point(latitude: session.lat, longitude: session.lon),
        zIndex: isSelected ? 10 : 1,
        opacity: 1.0,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage(SecondaryConstants.carIcon),
            scale: isSelected ? 1.2 : 0.8,
            rotationType: RotationType.rotate,
          ),
        ),
        // 🛠️ MARKER TAP ACTION
        onTap: (obj, point) {
          setState(() {
            _selectedSessionId = session.sessionId;
            _selectedDriverName = session.username;
            _isFollowing = true;
          });
          // 🚀 ACTION: Move Immediately on Tap!
          _animateCamera(Point(latitude: session.lat, longitude: session.lon));
        },
      );
    }).toList();

    final selectedUpdate = _selectedSessionId != null
        ? _activeSessions[_selectedSessionId]
        : null;

    return Scaffold(
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (c) {
              _controllerCompleter.complete(c);

              // 🎯 FIX: If data already exists when map loads, zoom to it
              if (widget.targetSession != null && !_hasPerformedInitialZoom) {
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (_activeSessions.containsKey(widget.targetSession!.id)) {
                    final update = _activeSessions[widget.targetSession!.id]!;
                    _hasPerformedInitialZoom = true;
                    _animateCamera(Point(
                      latitude: update.lat,
                      longitude: update.lon,
                    ));
                    debugPrint("🎯 Initial zoom from onMapCreated");
                  }
                });
              }
            },
            mapObjects: mapObjects,
            onCameraPositionChanged: (pos, reason, finished) {
              if (reason == CameraUpdateReason.gestures) {
                setState(() => _isFollowing = false);
              }
            },
            onMapTap: (_) => setState(() => _isFollowing = false),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: MapHeader(
              title: _selectedDriverName != null
                  ? "Tracking: $_selectedDriverName"
                  : "Active Fleet (${_activeSessions.length})",
              onBackPressed: () => Navigator.pop(context),
            ),
          ),

          Positioned(
            right: 16,
            bottom: selectedUpdate != null ? 220 : 40,
            child: RecenterButton(
              onPressed: _onRecenterPressed,
            ),
          ),

          if (selectedUpdate != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: DriverInfoCard(
                driverName: _selectedDriverName ?? "Unknown",
                status: _getTimeAgo(selectedUpdate.timestamp),
                lastUpdated: DateFormat('HH:mm:ss').format(DateTime.now()),
              ),
            ),

          // Connection status indicator
          if (!_isConnected)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.signal_wifi_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Connection Lost',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final diff = DateTime.now().toUtc().difference(date);
      if (diff.inSeconds < 60) return "Updated ${diff.inSeconds}s ago";
      if (diff.inMinutes < 60) return "Updated ${diff.inMinutes}m ago";
      return "Updated ${diff.inHours}h ago (STALE)";
    } catch (e) {
      return "Live";
    }
  }
}