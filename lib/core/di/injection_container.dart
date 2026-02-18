import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:location_tracker/core/network/dio_client.dart';
import 'package:location_tracker/core/services/admin_api_service.dart';
import 'package:location_tracker/core/services/api_service.dart';
import 'package:location_tracker/core/services/local_db_service.dart';
import 'package:location_tracker/core/services/map_matching_service.dart';
import 'package:location_tracker/features/auth/bloc/auth_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;
final log = Logger();

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  sl.registerLazySingleton<Dio>(() => DioClient(sl<SharedPreferences>()).dio);

  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase.instance);

  sl.registerLazySingleton<ApiService>(
    () => ApiService(sl<Dio>(), sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<AdminApiService>(
    () => AdminApiService(sl<Dio>()),
  );
  sl.registerLazySingleton<MapMatchingService>(
    () => MapMatchingService(sl<Dio>()),
  );

  sl.registerLazySingleton(() => AuthBloc(sl<ApiService>()));
}
