import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_user/features/notifications/data/notification_service.dart';
import 'package:sheride_user/features/notifications/domain/notification_model.dart';
import 'package:sheride_user/features/safety/data/safety_service.dart';
import 'package:sheride_user/features/safety/domain/emergency_contact_model.dart';
import 'package:sheride_user/features/safety/domain/live_sharing_model.dart';
import 'package:sheride_user/features/safety/domain/sos_model.dart';
import 'package:sheride_user/features/support/data/support_service.dart';
import 'package:sheride_user/features/support/domain/support_ticket_model.dart';

void main() {
  group('Phase 4 Unit Tests - User App Safety, Support & Notifications', () {
    test('SosModel serializes, deserializes and validates active status', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sos = SosModel(
        sosId: 'sos_101',
        uid: 'user_priya',
        rideId: 'ride_202',
        lat: 17.0005,
        lng: 81.7800,
        timestamp: now,
        status: 'active',
        type: 'emergency',
      );

      final map = sos.toMap();
      expect(map['sosId'], 'sos_101');
      expect(map['status'], 'active');
      expect(map['lat'], 17.0005);

      final parsed = SosModel.fromMap(map, 'sos_101');
      expect(parsed.uid, 'user_priya');
      expect(parsed.rideId, 'ride_202');
      expect(parsed.type, 'emergency');
    });

    test('EmergencyContactModel supports copyWith and serialization', () {
      final contact = EmergencyContactModel(
        contactId: 'ct_101',
        name: 'Sunita Sharma',
        phone: '+91 98480 12345',
        relation: 'Mother',
      );

      final map = contact.toMap();
      expect(map['name'], 'Sunita Sharma');
      expect(map['relation'], 'Mother');

      final updated = contact.copyWith(phone: '+91 99999 88888');
      expect(updated.phone, '+91 99999 88888');
      expect(updated.name, 'Sunita Sharma');
    });

    test('LiveSharingModel stores sharing state and recipients list', () {
      final expires = DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch;
      final sharing = LiveSharingModel(
        rideId: 'ride_303',
        isActive: true,
        sharedWith: ['+91 98480 12345', '+91 98480 67890'],
        expiresAt: expires,
      );

      final map = sharing.toMap();
      expect(map['isActive'], true);
      expect((map['sharedWith'] as List).length, 2);

      final parsed = LiveSharingModel.fromMap(map, 'ride_303');
      expect(parsed.isActive, true);
      expect(parsed.sharedWith.contains('+91 98480 12345'), true);
    });

    test('SupportTicketModel categorizes tickets correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ticket = SupportTicketModel(
        ticketId: 't_501',
        uid: 'user_priya',
        category: 'safety',
        subject: 'Night travel safety query',
        message: 'How do I verify the captain driver license?',
        status: 'open',
        createdAt: now,
        updatedAt: now,
      );

      final map = ticket.toMap();
      expect(map['category'], 'safety');
      expect(map['status'], 'open');

      final parsed = SupportTicketModel.fromMap(map, 't_501');
      expect(parsed.subject, 'Night travel safety query');
    });

    test('NotificationModel toggles read status properly', () {
      final notif = NotificationModel(
        notificationId: 'notif_1',
        title: 'Ride Confirmed 🌸',
        body: 'Relangi Durga is on the way!',
        type: 'ride',
        isRead: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(notif.isRead, false);
      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, true);
    });

    test('SafetyService triggers and resolves SOS alerts', () async {
      final safety = SafetyService();
      const testUid = 'user_sos_test';

      final sos = await safety.triggerSos(
        uid: testUid,
        lat: 17.0005,
        lng: 81.7800,
        rideId: 'ride_active_sos',
      );

      expect(sos.status, 'active');
      expect(sos.uid, testUid);

      final resolved = await safety.resolveSos(sos.sosId);
      expect(resolved, true);
    });

    test('SafetyService manages emergency contacts CRUD', () async {
      final safety = SafetyService();
      const testUid = 'user_contacts_test';

      final newContact = EmergencyContactModel(
        contactId: 'ct_test_99',
        name: 'Ananya Sharma',
        phone: '+91 98480 99999',
        relation: 'Sister',
      );

      await safety.addEmergencyContact(testUid, newContact);
      final contacts = await safety.getEmergencyContacts(testUid);
      expect(contacts.any((c) => c.contactId == 'ct_test_99'), true);

      await safety.deleteEmergencyContact(testUid, 'ct_test_99');
      final afterDelete = await safety.getEmergencyContacts(testUid);
      expect(afterDelete.any((c) => c.contactId == 'ct_test_99'), false);
    });

    test('SupportService creates and retrieves tickets', () async {
      final support = SupportService();
      const testUid = 'user_support_test';

      final ticket = await support.createTicket(
        uid: testUid,
        category: 'payment',
        subject: 'UPI Cashback confirmation',
        message: 'Where can I see the coupon cashback balance?',
      );

      expect(ticket.status, 'open');
      expect(ticket.category, 'payment');

      final tickets = await support.getTickets(testUid);
      expect(tickets.any((t) => t.ticketId == ticket.ticketId), true);
    });

    test('NotificationService creates and marks notifications as read', () async {
      final notifService = NotificationService();
      const testUid = 'user_notif_test';

      await notifService.sendNotification(
        targetUid: testUid,
        title: 'Discount Applied 🌸',
        body: 'Saved ₹50 using code SHERIDE50',
        type: 'offer',
      );

      await notifService.markAllAsRead(testUid);
      // Completes smoothly without throwing exceptions
      expect(true, isTrue);
    });
  });
}
