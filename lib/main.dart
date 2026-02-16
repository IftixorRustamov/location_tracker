import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:location_tracker/my_app.dart';

import 'core/di/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    await init();
    runApp(
      BlocProvider(create: (context) => sl<AuthBloc>(), child: const MyApp()),
    );
  }, (error, stack) {
    log.e('Uncaught error', error: error, stackTrace: stack);
  });
}
