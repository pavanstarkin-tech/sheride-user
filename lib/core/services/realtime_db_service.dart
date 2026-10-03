import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../../features/auth/domain/user_model.dart';

class RealtimeDbService {
  final FirebaseDatabase _db;

  RealtimeDbService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  DatabaseReference get _usersRef => _db.ref(ApiConstants.nodeUsers);

  // Save User to /users/{uid}
  Future<void> saveUserData(UserModel user) async {
    try {
      await _usersRef.child(user.uid).set(user.toMap());
      debugPrint("User data saved successfully to /users/${user.uid}");
    } catch (e) {
      debugPrint("RealtimeDbService saveUserData error: $e");
      rethrow;
    }
  }

  // Get User from /users/{uid}
  Future<UserModel?> getUserData(String uid) async {
    try {
      final snapshot = await _usersRef.child(uid).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        return UserModel.fromMap(data, uid: uid);
      }
      return null;
    } catch (e) {
      debugPrint("RealtimeDbService getUserData error: $e");
      return null;
    }
  }

  // Listen to User Profile changes
  Stream<UserModel?> streamUserData(String uid) {
    return _usersRef.child(uid).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        return UserModel.fromMap(data, uid: uid);
      }
      return null;
    });
  }

  // Update Emergency Contact
  Future<void> updateEmergencyContact(String uid, String emergencyContact) async {
    try {
      await _usersRef.child(uid).update({
        'emergencyContact': emergencyContact,
      });
    } catch (e) {
      debugPrint("RealtimeDbService updateEmergencyContact error: $e");
      rethrow;
    }
  }
}
