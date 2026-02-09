import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:location_tracker/core/constants/api_constants.dart';
import 'package:location_tracker/core/interceptors/auth_interceptor.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  late final Dio dio;
  final SharedPreferences prefs;

  DioClient(this.prefs) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(dio, prefs),
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: true,
        error: true,
        compact: false,
        maxWidth: 90,
        logPrint: (object) => log(object.toString(), name: "LOCATION API"),
      ),
    ]);
  }
}
