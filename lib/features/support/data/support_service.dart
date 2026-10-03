import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../domain/support_ticket_model.dart';

class SupportService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  static final List<SupportTicketModel> _localTickets = [
    SupportTicketModel(
      ticketId: 't_sample_1',
      uid: 'user_1',
      category: 'safety',
      subject: 'Captain verification confirmation',
      message: 'Can I verify the captain driver license number before onboarding?',
      status: 'resolved',
      createdAt: DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    ),
  ];

  Future<SupportTicketModel> createTicket({
    required String uid,
    required String category,
    required String subject,
    required String message,
    String? rideId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ticketId = 'ticket_${now}_${uid.hashCode.abs().toString().substring(0, 4)}';
    final ticket = SupportTicketModel(
      ticketId: ticketId,
      uid: uid,
      category: category,
      subject: subject,
      message: message,
      rideId: rideId,
      status: 'open',
      createdAt: now,
      updatedAt: now,
    );

    _localTickets.insert(0, ticket);

    final db = _db;
    if (db != null) {
      try {
        await db.ref('supportTickets/$ticketId').set(ticket.toMap());
      } catch (_) {}
    }
    return ticket;
  }

  Stream<List<SupportTicketModel>> streamTickets(String uid) {
    final db = _db;
    if (db == null) {
      return Stream.value(_localTickets.where((t) => t.uid == uid || t.uid == 'user_1').toList());
    }
    return db.ref('supportTickets').orderByChild('uid').equalTo(uid).onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries.map((e) {
          return SupportTicketModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      return _localTickets.where((t) => t.uid == uid || t.uid == 'user_1').toList();
    });
  }

  Future<List<SupportTicketModel>> getTickets(String uid) async {
    final db = _db;
    if (db == null) return _localTickets.where((t) => t.uid == uid || t.uid == 'user_1').toList();
    try {
      final snap = await db.ref('supportTickets').orderByChild('uid').equalTo(uid).get();
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        final list = data.entries.map((e) {
          return SupportTicketModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (_) {}
    return _localTickets.where((t) => t.uid == uid || t.uid == 'user_1').toList();
  }
}
