abstract class ApiConstants {
  static const String baseUrl = 'http://192.168.20.152:8080';
  // static const String baseUrl =
  //     'https://untensing-hendrix-unsentenced.ngrok-free.dev';

  static const String api = '/api';
  static const String authPath = '/auth';
  static const String users = '/users';
  static const String register = '$api$authPath/register';
  static const String login = '$api$authPath/login';
  static const String logout = '$api$authPath/logout';
  static const String refresh = '$api$authPath/refresh';
  static const String changePassword = '$api$authPath/change-password';

  static const String assignRoleToUser = '$api$users/add-role -to-user';
  static const String getLiveSessionData = '$api/v1/sessions/admin/live';
  static const String getSessions = '$api/v1/sessions/admin';
  static const String getUsers = '$api$users/all';

  // Tracking
  static const String startTracking = '$api/v1/users/tracking/sessions/start';
  static const String stopTracking = '$api/v1/users/tracking/sessions/stop';
  static const String updateLocation = '$api/v1/users/tracking/location';
}
