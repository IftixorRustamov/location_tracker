import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_event.dart';
import 'package:location_tracker/features/auth/bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  // Animations
  late final Animation<double> _distanceAnim;
  late final Animation<double> _rotationAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rippleAnim;

  // State Management
  bool _isAnimationDone = false;
  String? _determinedRoute; // Where we should go ('/home' or '/login')

  // Constants
  static const Color _brandGreen = Color(0xFF00C853);
  static const double _petalSize = 56.0;
  static const double _petalRadius = 22.0; // Updated to your preferred radius

  @override
  void initState() {
    super.initState();
    _initAnimations();

    // 1. Trigger the Auth Check immediately
    context.read<AuthBloc>().add(AppStarted());

    // 2. Start Animation Sequence
    _runSequence();
  }

  void _initAnimations() {
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _distanceAnim = Tween<double>(begin: 200.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _rotationAnim = Tween<double>(begin: -math.pi, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _rippleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  void _runSequence() async {
    await _entryController.forward();
    _pulseController.repeat(reverse: true);

    // 3. Minimum Splash Duration (3 seconds)
    Timer(const Duration(seconds: 3), () {
      _isAnimationDone = true;
      _tryNavigate(); // Check if we are ready to go
    });
  }

  // 4. Central Navigation Logic
  void _tryNavigate() {
    // Only navigate if BOTH the animation is done AND we know where to go
    if (_isAnimationDone && _determinedRoute != null && mounted) {
      Navigator.of(context).pushReplacementNamed(_determinedRoute!);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // 5. Listen for Auth Decision
        if (state is Authenticated) {
          _determinedRoute = '/home';
        } else if (state is Unauthenticated) {
          _determinedRoute = '/login';
        }

        // Try to navigate (will wait if animation isn't done yet)
        _tryNavigate();
      },
      child: Scaffold(
        backgroundColor: _brandGreen,
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildShockwave(),
              _buildLogoAssembly(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShockwave() {
    return AnimatedBuilder(
      animation: _rippleAnim,
      builder: (context, child) {
        final opacity = (1.0 - _rippleAnim.value).clamp(0.0, 1.0);
        final size = 110 + (_rippleAnim.value * 150);

        return Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(opacity * 0.5),
                width: 4,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoAssembly() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _pulseController]),
      builder: (context, child) {
        final double pulseScale = _entryController.isCompleted
            ? 1.0 + (_pulseController.value * 0.05)
            : 1.0;

        return Transform.scale(
          scale: pulseScale,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  _Petal(align: Alignment.topLeft, anim: this),
                  _Petal(align: Alignment.topRight, anim: this),
                  _Petal(align: Alignment.bottomLeft, anim: this),
                  _Petal(align: Alignment.bottomRight, anim: this),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Petal extends StatelessWidget {
  final Alignment align;
  final _SplashScreenState anim;

  const _Petal({required this.align, required this.anim});

  @override
  Widget build(BuildContext context) {
    final double dx = align.x;
    final double dy = align.y;

    return Align(
      alignment: align,
      child: Transform.translate(
        offset: Offset(dx * anim._distanceAnim.value, dy * anim._distanceAnim.value),
        child: Transform.rotate(
          angle: anim._rotationAnim.value * dx * dy,
          child: Transform.scale(
            scale: anim._scaleAnim.value,
            child: Container(
              width: _SplashScreenState._petalSize,
              height: _SplashScreenState._petalSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _getBorderRadius(),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    const radius = Radius.circular(_SplashScreenState._petalRadius);

    return BorderRadius.all(radius).copyWith(
      bottomRight: align == Alignment.topLeft ? Radius.zero : null,
      bottomLeft: align == Alignment.topRight ? Radius.zero : null,
      topRight: align == Alignment.bottomLeft ? Radius.zero : null,
      topLeft: align == Alignment.bottomRight ? Radius.zero : null,
    );
  }
}