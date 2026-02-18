import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/core/config/routes.dart';
import 'package:location_tracker/core/di/injection_container.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';
import 'package:location_tracker/features/tracking/logic/tracking_controller.dart';
import 'package:location_tracker/features/tracking/widgets/home/control_buttons.dart';
import 'package:location_tracker/features/tracking/widgets/home/map_view_layer.dart';
import 'package:location_tracker/features/tracking/widgets/profile_sheet.dart';
import 'package:location_tracker/features/tracking/widgets/tracking_fab.dart';
import 'package:location_tracker/features/tracking/widgets/tracking_hud.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TrackingController _controller;
  bool _shouldFollowUser = true;

  @override
  void initState() {
    super.initState();
    // ApiService is injected — no mid-method sl<> calls inside the controller.
    _controller = TrackingController(sl<ApiService>());
    _controller.initialize(_showSnack);
  }

  @override
  void dispose() {
    _controller.disposeController();
    super.dispose();
  }

  void _showSnack(String msg, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileSheet(username: _controller.username),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Scaffold(
            body: Stack(
              children: [
                // 1. MAP LAYER
                MapViewLayer(
                  controller: _controller,
                  shouldFollowUser: _shouldFollowUser,
                ),

                // 2. HUD LAYER
                TrackingHUD(
                  isTracking: _controller.isTracking,
                  isOffline: _controller.isOffline,
                  sessionDuration: _controller.sessionDuration,
                  username: _controller.username,
                  distanceKm: _controller.distanceKm,
                  speedKmph: _controller.speedNotifier.value,
                  accuracy: _controller.accuracyNotifier.value,
                  onProfileTap: _openProfile,
                ),

                // 3. MAP CONTROLS
                ControlButtons(
                  shouldFollowUser: _shouldFollowUser,
                  onToggleFollow: () =>
                      setState(() => _shouldFollowUser = !_shouldFollowUser),
                  onCenter: () {
                    setState(() => _shouldFollowUser = true);
                    _controller.centerOnUser();
                  },
                ),

                // 4. LOADING OVERLAY
                if (_controller.isBusy)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
            floatingActionButton: TrackingFab(
              isTracking: _controller.isTracking,
              isBusy: _controller.isBusy,
              onPressed: () => _controller.toggleTracking(_showSnack),
            ),
            floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }
}
