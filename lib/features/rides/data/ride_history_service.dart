import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../domain/ride_model.dart';

class RideHistoryService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<List<RideModel>> streamRideHistory(String uid, {bool isRider = false}) {
    final db = _db;
    if (db == null) {
      return Stream.value([]);
    }

    final queryField = isRider ? 'riderId' : 'userId';
    return db.ref('rides').orderByChild(queryField).equalTo(uid).onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries.map<RideModel>((e) {
          return RideModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), rideId: e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      return [];
    });
  }

  Future<List<RideModel>> getRideHistory(String uid, {bool isRider = false}) async {
    final db = _db;
    if (db == null) return [];
    try {
      final queryField = isRider ? 'riderId' : 'userId';
      final snap = await db.ref('rides').orderByChild(queryField).equalTo(uid).get();
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        final list = data.entries.map<RideModel>((e) {
          return RideModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), rideId: e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (_) {}
    return [];
  }
}
