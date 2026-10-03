import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/notification_model.dart';

class NotificationService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  static final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
  static bool _isPluginInitialized = false;

  static final List<NotificationModel> _localNotifications = [
    NotificationModel(
      notificationId: 'notif_welcome',
      title: 'Welcome to SheRide 🌸',
      body: 'Your safe rides with 100% verified women captains start here.',
      type: 'system',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    ),
    NotificationModel(
      notificationId: 'notif_offer',
      title: 'Special Offer Available! 🎉',
      body: 'Get FLAT 50% OFF on your rides using coupon code SHERIDE50.',
      type: 'offer',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)).millisecondsSinceEpoch,
    ),
  ];

  static Future<void> initializeLocalNotifications() async {
    if (_isPluginInitialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifs.initialize(initSettings);
      _isPluginInitialized = true;
    } catch (_) {}
  }

  Future<void> showLocalAlert({required String title, required String body}) async {
    await initializeLocalNotifications();
    try {
      const androidDetails = AndroidNotificationDetails(
        'sheride_safety_channel',
        'SheRide Safety & Updates',
        channelDescription: 'Notifications for ride status and safety alerts',
        importance: Importance.max,
        priority: Priority.high,
      );
      await _localNotifs.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  Stream<List<NotificationModel>> streamNotifications(String uid) {
    final db = _db;
    if (db == null) {
      return Stream.value(List<NotificationModel>.from(_localNotifications));
    }

    return db.ref('notifications/$uid').onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries.map((e) {
          return NotificationModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      return List<NotificationModel>.from(_localNotifications);
    });
  }

  Future<void> sendNotification({
    required String targetUid,
    required String title,
    required String body,
    String type = 'system',
    Map<String, dynamic> data = const {},
  }) async {
    final notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final notif = NotificationModel(
      notificationId: notifId,
      title: title,
      body: body,
      type: type,
      data: data,
      isRead: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    _localNotifications.insert(0, notif);
    await showLocalAlert(title: title, body: body);

    final db = _db;
    if (db != null) {
      try {
        await db.ref('notifications/$targetUid/$notifId').set(notif.toMap());
      } catch (_) {}
    }
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    final idx = _localNotifications.indexWhere((n) => n.notificationId == notificationId);
    if (idx != -1) {
      _localNotifications[idx] = _localNotifications[idx].copyWith(isRead: true);
    }

    final db = _db;
    if (db != null) {
      try {
        await db.ref('notifications/$uid/$notificationId').update({'isRead': true});
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead(String uid) async {
    for (int i = 0; i < _localNotifications.length; i++) {
      _localNotifications[i] = _localNotifications[i].copyWith(isRead: true);
    }

    final db = _db;
    if (db != null) {
      try {
        final snap = await db.ref('notifications/$uid').get();
        if (snap.exists && snap.value != null) {
          final data = Map<dynamic, dynamic>.from(snap.value as Map);
          for (final key in data.keys) {
            await db.ref('notifications/$uid/$key').update({'isRead': true});
          }
        }
      } catch (_) {}
    }
  }
}
