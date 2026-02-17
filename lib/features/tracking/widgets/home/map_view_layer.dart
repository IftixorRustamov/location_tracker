import 'package:flutter/material.dart';
import 'package:location_tracker/features/tracking/logic/tracking_controller.dart';
import 'package:location_tracker/features/tracking/widgets/yandex_map_background.dart';

class MapViewLayer extends StatelessWidget {
  final TrackingController controller;
  final bool shouldFollowUser;

  const MapViewLayer({
    super.key,
    required this.controller,
    required this.shouldFollowUser,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.smoothPolylineNotifier,
        controller.polylineNotifier,
        controller.currentPositionNotifier,
        controller.headingNotifier,
      ]),
      builder: (context, _) {
        return YandexMapBackground(
          polylineCoordinates:
              controller.smoothPolylineNotifier.value.isNotEmpty
              ? controller.smoothPolylineNotifier.value
              : controller.polylineNotifier.value,
          currentHeading: controller.headingNotifier.value,
          currentPosition: controller.currentPositionNotifier.value,
          shouldFollowUser: shouldFollowUser,
        );
      },
    );
  }
}
