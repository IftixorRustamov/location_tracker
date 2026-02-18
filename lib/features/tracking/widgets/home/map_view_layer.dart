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
    // This builder listens to the LIST of points changing
    return ValueListenableBuilder(
      valueListenable: controller.polylineNotifier,
      builder: (context, polylineCoordinates, _) {

        return ValueListenableBuilder(
          valueListenable: controller.currentPositionNotifier,
          builder: (context, currentPosition, _) {

            return ValueListenableBuilder(
              valueListenable: controller.headingNotifier,
              builder: (context, heading, _) {

                return YandexMapBackground(
                  polylineCoordinates: polylineCoordinates, // Takes the fresh list
                  currentPosition: currentPosition,
                  currentHeading: heading,
                  shouldFollowUser: shouldFollowUser,
                );
              },
            );
          },
        );
      },
    );
  }
}