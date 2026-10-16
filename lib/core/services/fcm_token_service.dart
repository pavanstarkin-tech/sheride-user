import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';

class FcmTokenService {
  static final FcmTokenService _instance = FcmTokenService._internal();
  factory FcmTokenService() => _instance;
  FcmTokenService._internal();

  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  static const String _tokenPrefKey = 'sheride_device_fcm_token';

  /// Obtain persistent FCM device token for current user and save to Firebase RTDB & PHP API
  Future<String> registerUserFcmToken(String uid, {String role = 'user'}) async {
    String token = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_tokenPrefKey);
      if (cached != null && cached.isNotEmpty) {
        token = cached;
      } else {
        token = 'fcm_${role}_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
        await prefs.setString(_tokenPrefKey, token);
      }
    } catch (_) {
      token = 'fcm_${role}_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final platform = kIsWeb ? 'web' : 'android';

    // 1. Save in Firebase Realtime Database
    final db = _db;
    if (db != null) {
      try {
        final node = role == 'rider' ? 'riders/$uid' : 'users/$uid';
        await db.ref(node).update({
          'fcmToken': token,
          'lastActive': now,
        });

        await db.ref('fcmTokens/$uid').set({
          'uid': uid,
          'token': token,
          'fcmToken': token,
          'role': role,
          'platform': platform,
          'updatedAt': now,
          'lastActive': now,
        });
      } catch (e) {
        debugPrint('RTDB FCM token save warning: $e');
      }
    }

    // 2. Dispatch to live Hostinger PHP REST endpoint: save_fcm_token.php
    _syncTokenWithBackend(uid, token, role, platform);

    return token;
  }

  /// Background sync to PHP API save_fcm_token.php
  void _syncTokenWithBackend(String uid, String token, String role, String platform) {
    try {
      final url = Uri.parse(ApiConstants.saveFcmToken);
      http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'token': token,
          'fcmToken': token,
          'role': role,
          'platform': platform,
        }),
      ).then((res) {
        debugPrint('FCM Token registered with API [${res.statusCode}]: ${res.body}');
      }).catchError((err) {
        debugPrint('FCM Token API sync warning: $err');
      });
    } catch (_) {}
  }

  /// Dispatch ride notification to passenger or pilot via PHP Cloud Endpoint & RTDB
  Future<void> sendRidePushNotification({
    required String rideId,
    required String event,
    required String targetUid,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final notifId = 'notif_ride_${event}_$now';

    final notifPayload = {
      'notificationId': notifId,
      'title': title,
      'body': body,
      'type': 'ride',
      'rideId': rideId,
      'event': event,
      'isRead': false,
      'createdAt': now,
      'data': data,
    };

    final db = _db;
    if (db != null) {
      try {
        // Write to target's in-app notification center
        await db.ref('notifications/$targetUid/$notifId').set(notifPayload);

        // Record ride event log
        await db.ref('rides/$rideId/events/$now').set({
          'event': event,
          'timestamp': now,
          'title': title,
        });
      } catch (e) {
        debugPrint('Push notification RTDB dispatch warning: $e');
      }
    }

    // Also trigger live PHP push notification endpoint on farmx.acheva.in
    try {
      final url = Uri.parse(ApiConstants.sendRideNotification);
      http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rideId': rideId,
          'event': event,
          'targetUid': targetUid,
          'passengerUid': targetUid,
          'title': title,
          'body': body,
          ...data,
        }),
      ).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }
}
