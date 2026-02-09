import 'package:flutter/material.dart';
import 'package:location_tracker/features/auth/screens/login_screen.dart';
import 'package:location_tracker/features/auth/screens/register_screen.dart';
import 'package:location_tracker/features/auth/screens/splash_screen.dart';
import 'package:location_tracker/features/tracking/screens/home_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
  };
}