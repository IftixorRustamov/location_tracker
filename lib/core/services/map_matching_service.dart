import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class MapMatchingService {
  final Dio _dio;

  MapMatchingService(this._dio);


  final String _baseUrl = 'https://router.project-osrm.org/match/v1/driving';

  Future<List<LatLng>> getSnappedRoute(List<LatLng> rawPoints) async {
    if (rawPoints.length < 2) return rawPoints;


    final List<LatLng> processingPoints = rawPoints.length > 40
        ? rawPoints.sublist(rawPoints.length - 40)
        : rawPoints;

    final String coordString = processingPoints
        .map((p) => "${p.longitude},${p.latitude}")
        .join(';');

    final String radiusString = List.filled(
      processingPoints.length,
      "25",
    ).join(';');

    try {
      final response = await _dio.get(
        '$_baseUrl/$coordString',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'radiuses': radiusString,
          'steps': 'false',
          'tidy': 'true',
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 'Ok') {
        final matchings = response.data['matchings'] as List;
        if (matchings.isNotEmpty) {
          final geometry = matchings[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
        }
      }
    } catch (e) {
      log("OSRM Map Match Failed: $e");
    }

    return rawPoints;
  }
}
