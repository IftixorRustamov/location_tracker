import 'package:flutter/material.dart';
import 'package:location_tracker/features/auth/widgets/auth_guard.dart';
import 'core/config/routes.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      builder: (context, child) {
        return AuthGuard(child: child!);
      },
    );
  }
}
