abstract class ApiConstants {
  static const String baseUrl = 'http://192.168.20.188:8080';

  static const String api = '/api';
  static const String authPath = '/auth';
  static const String register = '$api$authPath/register';
  static const String login = '$api$authPath/login';
  static const String logout = '$api$authPath/logout';
  static const String refresh = '$api$authPath/refresh';
  static const String changePassword = '$api$authPath/change-password';

  // Tracking
  static const String startTracking = '$api/v1/users/tracking/sessions/start';
  static const String stopTracking = '$api/v1/users/tracking/sessions/stop';
  static const String updateLocation = '$api/v1/users/tracking/location';

}
