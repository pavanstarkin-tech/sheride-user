import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_user/core/services/network_service.dart';
import 'package:sheride_user/features/auth/domain/user_model.dart';
import 'package:sheride_user/features/notifications/data/notification_service.dart';
import 'package:sheride_user/features/rides/data/ride_service.dart';
import 'package:sheride_user/features/rides/domain/ride_model.dart';
import 'package:sheride_user/features/safety/data/safety_service.dart';
import 'package:sheride_user/features/safety/domain/emergency_contact_model.dart';
import 'package:sheride_user/features/safety/domain/live_sharing_model.dart';
import 'package:sheride_user/features/support/data/support_service.dart';
import 'package:sheride_user/features/wallet/data/offer_service.dart';
import 'package:sheride_user/features/wallet/data/wallet_service.dart';

void main() {
  group('Phase 5 - SheRide User App Full E2E & Production Hardening Suite', () {
    test('E2E Flow 1: User Registration & Session Persistence', () {
      final user = UserModel(
        uid: 'user_priya_e2e',
        phone: '+919876543210',
        name: 'Priya Sharma',
        email: 'priya@sheride.app',
        gender: 'Female',
        createdAt: DateTime.now().toIso8601String(),
      );

      expect(user.uid, 'user_priya_e2e');
      expect(user.gender, 'Female');
      final map = user.toMap();
      final restored = UserModel.fromMap(map, uid: user.uid);
      expect(restored.name, 'Priya Sharma');
    });

    test('E2E Flow 2: Ride Request & Fare Calculations across vehicle tiers', () {
      final service = RideService();
      const pickup = LocationPoint(lat: 12.9716, lng: 77.5946, address: 'Indiranagar');
      const drop = LocationPoint(lat: 12.9352, lng: 77.6245, address: 'Koramangala');
      final options = service.calculateFares(pickup, drop);

      expect(options.length >= 4, true);
      final bikeOption = options.firstWhere((o) => o.id == 'ev_scooter' || o.id == 'bike');
      final autoOption = options.firstWhere((o) => o.id == 'ev_auto' || o.id == 'auto');
      final cabOption = options.firstWhere((o) => o.id == 'ev_cab_eco' || o.id == 'cab_economy');
      final premOption = options.firstWhere((o) => o.id == 'ev_cab_premium' || o.id == 'cab_premium');

      expect(bikeOption.fare, greaterThan(0));
      expect(autoOption.fare, greaterThan(bikeOption.fare));
      expect(cabOption.fare, greaterThan(autoOption.fare));
      expect(premOption.fare, greaterThan(cabOption.fare));
    });

    test('E2E Flow 3: Complete Ride Lifecycle (Requested -> Accepted -> Arrived -> Started -> Completed)', () {
      final ride = RideModel(
        rideId: 'ride_e2e_101',
        userId: 'user_priya_e2e',
        riderId: 'rider_durga_e2e',
        status: 'requested',
        pickup: const LocationPoint(lat: 12.9716, lng: 77.5946, address: 'Indiranagar 100ft Rd'),
        drop: const LocationPoint(lat: 12.9352, lng: 77.6245, address: 'Koramangala 5th Block'),
        fare: 150.0,
        vehicleType: 'bike',
        distanceKm: 5.0,
        durationMin: 18,
        otp: '4821',
        paymentMethod: 'cash',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(ride.status, 'requested');
      final accepted = ride.copyWith(status: 'accepted');
      expect(accepted.status, 'accepted');
      final arrived = accepted.copyWith(status: 'arrived');
      expect(arrived.status, 'arrived');
      final started = arrived.copyWith(status: 'started');
      expect(started.status, 'started');
      final completed = started.copyWith(status: 'completed');
      expect(completed.status, 'completed');
    });

    test('E2E Flow 4: Safety Layer - SOS Trigger & Dispatch Record', () async {
      final safety = SafetyService();
      final sos = await safety.triggerSos(
        uid: 'user_priya_e2e',
        rideId: 'ride_e2e_101',
        lat: 12.9716,
        lng: 77.5946,
      );

      expect(sos.status, 'active');
      expect(sos.uid, 'user_priya_e2e');
      expect(sos.rideId, 'ride_e2e_101');

      await safety.resolveSos(sos.sosId);
      final active = await safety.streamActiveSos('user_priya_e2e').first;
      expect(active == null || active.status == 'resolved', isTrue);
    });

    test('E2E Flow 5: Live Trip Sharing & Emergency Contacts Sync', () async {
      final safety = SafetyService();
      final contact = EmergencyContactModel(
        contactId: 'ct_mom_e2e',
        name: 'Sunita Sharma (Mom)',
        phone: '+919811122233',
        relation: 'Mother',
      );

      await safety.addEmergencyContact('user_priya_e2e', contact);
      final contacts = await safety.getEmergencyContacts('user_priya_e2e');
      expect(contacts.any((c) => c.phone == '+919811122233'), isTrue);

      final liveShare = LiveSharingModel(
        rideId: 'ride_e2e_101',
        isActive: true,
        sharedWith: [contact.phone],
        expiresAt: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      );
      expect(liveShare.isActive, isTrue);
      expect(liveShare.sharedWith.length, 1);
    });

    test('E2E Flow 6: Promo Offers & Wallet Transactions', () async {
      final offerService = OfferService();
      final offer = await offerService.validatePromoCode('SHERIDE50', 200.0);
      expect(offer, isNotNull);
      final discount = offer!.calculateDiscount(200.0);
      expect(discount, 60.0); // 50% max capped at 60

      final walletService = WalletService();
      await walletService.addMoney('user_priya_e2e', 500.0);
      final wallet = await walletService.getWallet('user_priya_e2e');
      expect(wallet.balance, greaterThanOrEqualTo(500.0));

      final success = await walletService.deductFare('user_priya_e2e', 150.0, 'ride_e2e_101');
      expect(success, isTrue);
    });

    test('E2E Flow 7: Support Desk & 24/7 Ticketing', () async {
      final supportService = SupportService();
      final ticket = await supportService.createTicket(
        uid: 'user_priya_e2e',
        category: 'safety',
        subject: 'Captain took an illuminated route',
        message: 'Everything was safe, checking route logs.',
      );

      expect(ticket.ticketId.isNotEmpty, isTrue);
      expect(ticket.status, 'open');
      expect(ticket.category, 'safety');

      final tickets = await supportService.getTickets('user_priya_e2e');
      expect(tickets.any((t) => t.ticketId == ticket.ticketId), isTrue);
    });

    test('E2E Flow 8: Notifications Dispatch & Mark as Read', () async {
      final notifService = NotificationService();
      await notifService.sendNotification(
        targetUid: 'user_priya_e2e',
        title: 'Ride Completed 🌸',
        body: 'Thank you for riding with SheRide.',
        type: 'ride',
      );

      final notifs = await notifService.streamNotifications('user_priya_e2e').first;
      expect(notifs.isNotEmpty, isTrue);
      await notifService.markAllAsRead('user_priya_e2e');
    });

    test('E2E Flow 9: Offline & Resilience Network Service', () {
      final network = NetworkService();
      expect(network.isOnline.value, isNotNull);
    });

    test('E2E Flow 10: Edge Case - Ride Cancellation Status', () {
      final ride = RideModel(
        rideId: 'ride_cancel_e2e',
        userId: 'user_priya_e2e',
        riderId: null,
        status: 'requested',
        pickup: const LocationPoint(lat: 12.9716, lng: 77.5946, address: 'Indiranagar'),
        drop: const LocationPoint(lat: 12.9352, lng: 77.6245, address: 'Koramangala'),
        fare: 120.0,
        vehicleType: 'auto',
        distanceKm: 3.5,
        durationMin: 12,
        otp: '9921',
        paymentMethod: 'cash',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final cancelled = ride.copyWith(status: 'cancelled', cancelledBy: 'user');
      expect(cancelled.status, 'cancelled');
      expect(cancelled.cancelledBy, 'user');
    });
  });
}
