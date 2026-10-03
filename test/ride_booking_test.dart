import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_user/features/rides/domain/ride_model.dart';
import 'package:sheride_user/features/rides/data/ride_service.dart';

void main() {
  group('Phase 2 Unit Tests - User App Ride Booking & Matching', () {
    test('RideModel serialization, deserialization, and status transitions', () {
      final pickup = const LocationPoint(
        lat: 17.0005,
        lng: 81.7800,
        address: 'Rajahmundry Railway Station',
        name: 'Station',
      );
      final drop = const LocationPoint(
        lat: 17.0520,
        lng: 81.8210,
        address: 'Divancheruvu, Palacherla',
        name: 'College',
      );

      final ride = RideModel(
        rideId: 'ride_101',
        userId: 'user_priya',
        status: 'requested',
        pickup: pickup,
        drop: drop,
        vehicleType: 'bike',
        fare: 108.0,
        distanceKm: 3.9,
        durationMin: 12,
        paymentMethod: 'cash',
        otp: '4829',
      );

      final map = ride.toMap();
      expect(map['rideId'], 'ride_101');
      expect(map['status'], 'requested');
      expect(map['fare'], 108.0);
      expect(map['otp'], '4829');

      final reconstructed = RideModel.fromMap(map);
      expect(reconstructed.rideId, 'ride_101');
      expect(reconstructed.pickup.lat, 17.0005);
      expect(reconstructed.drop.lng, 81.8210);

      // Transition to accepted
      final accepted = reconstructed.copyWith(
        status: 'accepted',
        riderId: 'rider_durga',
        riderName: 'Relangi Durga',
        vehicleNumber: 'KA 05 AB 1234',
        riderRating: 4.9,
      );
      expect(accepted.status, 'accepted');
      expect(accepted.riderName, 'Relangi Durga');

      // Transition to started
      final started = accepted.copyWith(status: 'started');
      expect(started.status, 'started');

      // Transition to completed
      final completed = started.copyWith(status: 'completed');
      expect(completed.status, 'completed');
    });

    test('Fare calculation logic across all vehicle tiers', () {
      final rideService = RideService();
      const pickup = LocationPoint(lat: 17.0005, lng: 81.7800, address: 'Start');
      const drop = LocationPoint(lat: 17.0520, lng: 81.8210, address: 'End');

      final options = rideService.calculateFares(pickup, drop);
      expect(options.length >= 4, true);

      final bike = options.firstWhere((o) => o.id == 'ev_scooter' || o.id == 'bike');
      final auto = options.firstWhere((o) => o.id == 'ev_auto' || o.id == 'auto');
      final cabEco = options.firstWhere((o) => o.id == 'ev_cab_eco' || o.id == 'cab_economy');
      final cabPrem = options.firstWhere((o) => o.id == 'ev_cab_premium' || o.id == 'cab_premium');

      expect(bike.fare >= 30.0, true);
      expect(auto.fare >= 45.0, true);
      expect(cabEco.fare >= 80.0, true);
      expect(cabPrem.fare >= 120.0, true);

      expect(bike.fare < auto.fare, true);
      expect(auto.fare < cabEco.fare, true);
      expect(cabEco.fare < cabPrem.fare, true);
    });
  });
}
