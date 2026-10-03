import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Auth Token
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: AppConstants.keyAuthToken);
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.keyRefreshToken);
  }

  // User ID
  Future<void> saveUserId(String uid) async {
    if (_prefs == null) await init();
    await _prefs?.setString(AppConstants.keyUserId, uid);
  }

  String? getUserId() {
    return _prefs?.getString(AppConstants.keyUserId);
  }

  // User Role
  Future<void> saveUserRole(String role) async {
    if (_prefs == null) await init();
    await _prefs?.setString(AppConstants.keyUserRole, role);
  }

  String? getUserRole() {
    return _prefs?.getString(AppConstants.keyUserRole);
  }

  // Clear all session on Logout
  Future<void> clearSession() async {
    if (_prefs == null) await init();
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}
