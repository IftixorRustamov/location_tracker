import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';

class AdminLiveMapScreen extends StatefulWidget {
  final String sessionId;
  final String driverName;
  final AdminApiService apiService;

  const AdminLiveMapScreen({
    super.key,
    required this.sessionId,
    required this.driverName,
    required this.apiService,
  });

  @override
  State<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _AdminLiveMapScreenState extends State<AdminLiveMapScreen> {
  final Completer<YandexMapController> _controllerCompleter = Completer();
  Timer? _timer;
  Point? _lastPoint;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLocation());
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final data = await widget.apiService.getLiveSessionData(widget.sessionId);

    if (data != null && mounted) {
      print("LIVE DATA: $data");

      // 1. PARSE SAFE (Handle both 'lat' and 'latitude' keys)
      final double? lat = (data['latitude'] ?? data['lastLatitude'])?.toDouble();
      final double? lon = (data['longitude'] ?? data['lastLongitude'])?.toDouble();

      if (lat != null && lon != null) {
        // 2. Check if 0.0 (Invalid GPS)
        if (lat == 0 && lon == 0) return;

        final point = Point(latitude: lat, longitude: lon);

        setState(() => _lastPoint = point);

        // 3. Move Camera Only Once (or if user wants to follow)
        // logic: if camera hasn't moved yet, move it.
        _moveCamera(point);
      }
    }
  }

  Future<void> _moveCamera(Point point) async {
    final controller = await _controllerCompleter.future;
    controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: 17),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Tracking: ${widget.driverName}")),
      body: _lastPoint == null
          ? const Center(child: CircularProgressIndicator())
          : YandexMap(
        onMapCreated: (controller) => _controllerCompleter.complete(controller),
        mapObjects: [
          PlacemarkMapObject(
            mapId: const MapObjectId('driver_marker'),
            point: _lastPoint!,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(
                image: BitmapDescriptor.fromAssetImage('assets/car_icon.png'),
                scale: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}