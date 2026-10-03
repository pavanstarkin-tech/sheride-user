class ApiConstants {
  ApiConstants._();

  // Hostinger PHP Backend Base URL
  static const String baseUrl = 'https://api.sheride.app/api';

  // Endpoints
  static const String registerUser = '$baseUrl/register_user.php';
  static const String registerRider = '$baseUrl/register_rider.php';
  static const String updateProfile = '$baseUrl/update_profile.php';

  // Mapbox Configuration
  static const String mapboxAccessToken = 
      'pk.eyJ1IjoicGF2YW5rdW1hcnN3YW15IiwiYSI6ImNtNnc1c3ZpdTBkdGgyanM5b25rN2Zqcnc' 
      'ifQ.Ls1e2W6rx3apoBsStWa5Ow';
  static const String mapboxStyleUrl = 'mapbox://styles/mapbox/streets-v12';

  // Realtime Database Nodes
  static const String nodeUsers = 'users';
  static const String nodeRiders = 'riders';
  static const String nodeRides = 'rides';
  static const String nodeLocations = 'locations';
}

class AppConstants {
  AppConstants._();

  static const String appName = 'SheRide';
  static const String appTagline = 'Women Ride Together';
  static const String subTagline = 'Safe Rides • Stronger Women • Brighter Cities';
  static const String heroTitle = 'Rides\nBy Women\nFor Women.';
  static const String heroSubtitle = 'A safer, kinder and more confident way to move.';

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';
}
