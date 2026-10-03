import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../domain/emergency_contact_model.dart';
import '../domain/live_sharing_model.dart';
import '../domain/sos_model.dart';

class SafetyService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String get currentUid => _auth?.currentUser?.uid ?? 'guest_user';

  // In-memory fallback
  static final List<EmergencyContactModel> _localContacts = [
    const EmergencyContactModel(contactId: 'ct_1', name: 'Mother (Sunita)', phone: '+91 98480 12345', relation: 'Mother'),
    const EmergencyContactModel(contactId: 'ct_2', name: 'Sister (Ananya)', phone: '+91 98480 67890', relation: 'Sister'),
  ];
  static SosModel? _localSos;
  static final Map<String, LiveSharingModel> _localSharing = {};

  Future<SosModel> triggerSos({
    required String uid,
    String? rideId,
    required double lat,
    required double lng,
    String type = 'emergency',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sosId = 'sos_${now}_${uid.hashCode.abs().toString().substring(0, 4)}';
    final sos = SosModel(
      sosId: sosId,
      uid: uid,
      rideId: rideId,
      lat: lat,
      lng: lng,
      timestamp: now,
      status: 'active',
      type: type,
    );

    _localSos = sos;

    final db = _db;
    if (db != null) {
      try {
        await db.ref('safety/sos/$sosId').set(sos.toMap());
      } catch (_) {}
    }
    return sos;
  }

  Future<bool> resolveSos(String sosId) async {
    if (_localSos?.sosId == sosId) {
      _localSos = null;
    }
    final db = _db;
    if (db != null) {
      try {
        await db.ref('safety/sos/$sosId').update({'status': 'resolved'});
      } catch (_) {}
    }
    return true;
  }

  Stream<SosModel?> streamActiveSos(String uid) {
    final db = _db;
    if (db == null) {
      return Stream.value(_localSos);
    }
    return db.ref('safety/sos').orderByChild('uid').equalTo(uid).onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries
            .map((e) => SosModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString()))
            .where((s) => s.status == 'active')
            .toList();
        if (list.isNotEmpty) {
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list.first;
        }
      }
      return null;
    });
  }

  Stream<List<EmergencyContactModel>> streamEmergencyContacts(String uid) {
    final db = _db;
    if (db == null) {
      return Stream.value(List<EmergencyContactModel>.from(_localContacts));
    }
    return db.ref('safety/emergencyContacts/$uid').onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        return data.entries.map((e) {
          return EmergencyContactModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).toList();
      }
      return List<EmergencyContactModel>.from(_localContacts);
    });
  }

  Future<List<EmergencyContactModel>> getEmergencyContacts(String uid) async {
    final db = _db;
    if (db == null) return List<EmergencyContactModel>.from(_localContacts);
    try {
      final snap = await db.ref('safety/emergencyContacts/$uid').get();
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        return data.entries.map((e) {
          return EmergencyContactModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).toList();
      }
    } catch (_) {}
    return List<EmergencyContactModel>.from(_localContacts);
  }

  Future<bool> addEmergencyContact(String uid, EmergencyContactModel contact) async {
    _localContacts.removeWhere((c) => c.contactId == contact.contactId);
    _localContacts.add(contact);

    final db = _db;
    if (db != null) {
      try {
        await db.ref('safety/emergencyContacts/$uid/${contact.contactId}').set(contact.toMap());
      } catch (_) {}
    }
    return true;
  }

  Future<bool> deleteEmergencyContact(String uid, String contactId) async {
    _localContacts.removeWhere((c) => c.contactId == contactId);

    final db = _db;
    if (db != null) {
      try {
        await db.ref('safety/emergencyContacts/$uid/$contactId').remove();
      } catch (_) {}
    }
    return true;
  }

  Future<bool> setLiveSharing(String rideId, bool isActive, {List<String> sharedWith = const []}) async {
    final model = LiveSharingModel(
      rideId: rideId,
      isActive: isActive,
      sharedWith: sharedWith,
      expiresAt: DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch,
    );
    _localSharing[rideId] = model;

    final db = _db;
    if (db != null) {
      try {
        await db.ref('safety/liveSharing/$rideId').set(model.toMap());
      } catch (_) {}
    }
    return true;
  }

  Stream<LiveSharingModel?> streamLiveSharing(String rideId) {
    final db = _db;
    if (db == null) {
      return Stream.value(_localSharing[rideId]);
    }
    return db.ref('safety/liveSharing/$rideId').onValue.map((event) {
      if (event.snapshot.value != null) {
        return LiveSharingModel.fromMap(Map<dynamic, dynamic>.from(event.snapshot.value as Map), rideId);
      }
      return _localSharing[rideId];
    });
  }
}
