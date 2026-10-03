import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../domain/ride_model.dart';
import '../../../core/services/mapbox_service.dart';

class VehicleFareOption {
  final String id; // dynamic slug id e.g. ev_scooter, ev_bike, ev_auto, ev_cab_eco, ev_cab_premium, ev_charging_unit
  final String name;
  final String subtitle;
  final int etaMin;
  final int capacity;
  final double fare;
  final double distanceKm;
  final int durationMin;
  final String icon;
  final String imageUrl;
  final bool isElectric;
  final String badge;
  final int nearbyCount;

  const VehicleFareOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.etaMin,
    required this.capacity,
    required this.fare,
    required this.distanceKm,
    required this.durationMin,
    required this.icon,
    this.imageUrl = '',
    this.isElectric = true,
    this.badge = '⚡ 100% Electric',
    this.nearbyCount = 1,
  });
}

class RideService extends ChangeNotifier {
  FirebaseDatabase? _db;
  final MapboxService _mapboxService = MapboxService();

  RideService({FirebaseDatabase? db}) : _db = db;

  FirebaseDatabase get db {
    if (_db == null) {
      try {
        _db = FirebaseDatabase.instance;
      } catch (e) {
        debugPrint("RideService DB fallback notice: $e");
      }
    }
    return _db ?? FirebaseDatabase.instance;
  }

  // 1. Calculate Fares synchronously (with default dynamic catalog)
  List<VehicleFareOption> calculateFares(LocationPoint pickup, LocationPoint drop) {
    double distanceKm = _mapboxService.calculateDistance(
      pickup.lat,
      pickup.lng,
      drop.lat,
      drop.lng,
    );

    if (distanceKm < 0.5) distanceKm = 1.2;
    distanceKm = double.parse(distanceKm.toStringAsFixed(1));
    final durationMin = max(5, (distanceKm * 2.8).round());

    return [
      VehicleFareOption(
        id: 'scooty',
        name: 'Scooty',
        subtitle: 'Quick, nimble & affordable solo city commute',
        etaMin: 2,
        capacity: 1,
        fare: max(25.0, (20.0 + (distanceKm * 9.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'scooter',
        imageUrl: 'assets/images/vehicles/scooty.png',
        isElectric: false,
        badge: '⭐ Most Affordable',
        nearbyCount: 4,
      ),
      VehicleFareOption(
        id: 'electric_scooty',
        name: 'Electric Scooty',
        subtitle: '100% Eco-friendly, silent & zero-emission scooter',
        etaMin: 3,
        capacity: 1,
        fare: max(30.0, (25.0 + (distanceKm * 10.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'scooter',
        imageUrl: 'assets/images/vehicles/electric_scooty.png',
        isElectric: true,
        badge: '⚡ 100% Electric',
        nearbyCount: 5,
      ),
      VehicleFareOption(
        id: 'bike',
        name: 'Bike',
        subtitle: 'Fastest commute through peak traffic',
        etaMin: 3,
        capacity: 1,
        fare: max(30.0, (25.0 + (distanceKm * 11.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'bike',
        imageUrl: 'assets/images/vehicles/bike.png',
        isElectric: false,
        badge: '⚡ Fast Travel',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'priority_bike',
        name: 'Priority Bike',
        subtitle: 'Guaranteed top-rated captains & faster pickup',
        etaMin: 2,
        capacity: 1,
        fare: max(40.0, (35.0 + (distanceKm * 13.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'bike',
        imageUrl: 'assets/images/vehicles/priority_bike.png',
        isElectric: false,
        badge: '⭐ Priority Express',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'auto',
        name: 'Auto',
        subtitle: 'Safe, iconic 3-wheeler driven by women captains',
        etaMin: 4,
        capacity: 3,
        fare: max(40.0, (30.0 + (distanceKm * 13.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/auto.png',
        isElectric: false,
        badge: '🌱 Safe & Reliable',
        nearbyCount: 4,
      ),
      VehicleFareOption(
        id: 'priority_auto',
        name: 'Priority Auto',
        subtitle: 'Express dispatch auto with minimal wait time',
        etaMin: 2,
        capacity: 3,
        fare: max(50.0, (40.0 + (distanceKm * 15.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/priority_auto.png',
        isElectric: false,
        badge: '🚀 Express Dispatch',
        nearbyCount: 2,
      ),
      VehicleFareOption(
        id: 'premium_auto',
        name: 'Premium Auto',
        subtitle: 'Upgraded spacious auto with top safety rating',
        etaMin: 3,
        capacity: 3,
        fare: max(55.0, (45.0 + (distanceKm * 16.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/premium_auto.png',
        isElectric: false,
        badge: '👑 Premium Fleet',
        nearbyCount: 2,
      ),
      VehicleFareOption(
        id: 'mini_car',
        name: 'Mini Car',
        subtitle: 'Clean, air-conditioned comfortable hatchback cab',
        etaMin: 5,
        capacity: 4,
        fare: max(75.0, (55.0 + (distanceKm * 17.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'cab',
        imageUrl: 'assets/images/vehicles/mini_car.png',
        isElectric: false,
        badge: '❄️ AC Hatchback',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'premium_car',
        name: 'Premium Car',
        subtitle: 'Luxury executive sedan/SUV with top-rated captains',
        etaMin: 6,
        capacity: 4,
        fare: max(120.0, (85.0 + (distanceKm * 22.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'cab',
        imageUrl: 'assets/images/vehicles/premium_car.png',
        isElectric: false,
        badge: '✨ Executive Comfort',
        nearbyCount: 2,
      ),
      VehicleFareOption(
        id: 'ev_car',
        name: 'EV Car',
        subtitle: 'Silent, zero-emission premium electric cab',
        etaMin: 5,
        capacity: 4,
        fare: max(95.0, (70.0 + (distanceKm * 19.0)).roundToDouble()),
        distanceKm: distanceKm,
        durationMin: durationMin,
        icon: 'cab',
        imageUrl: 'assets/images/vehicles/ev_car.png',
        isElectric: true,
        badge: '⚡ Clean EV',
        nearbyCount: 3,
      ),
    ];
  }

  // 1.1 Fetch Live Dynamic Vehicle Types & Nearby Rider Counts from Firebase RTDB
  Future<List<VehicleFareOption>> getLiveDynamicFares(LocationPoint pickup, LocationPoint drop) async {
    final defaultFares = calculateFares(pickup, drop);
    try {
      final snap = await db.ref('settings/vehicleTypes').get();
      if (!snap.exists || snap.value == null) {
        return defaultFares;
      }

      // Fetch live online rider locations for proximity counts
      final locSnap = await db.ref('riderLocations').get();
      final Map<String, dynamic> riderLocs = locSnap.exists && locSnap.value != null
          ? Map<String, dynamic>.from(locSnap.value as Map)
          : {};

      double distanceKm = _mapboxService.calculateDistance(
        pickup.lat,
        pickup.lng,
        drop.lat,
        drop.lng,
      );
      if (distanceKm < 0.5) distanceKm = 1.2;
      distanceKm = double.parse(distanceKm.toStringAsFixed(1));
      final durationMin = max(5, (distanceKm * 2.8).round());

      final vmap = Map<String, dynamic>.from(snap.value as Map);
      final List<VehicleFareOption> liveList = [];

      vmap.forEach((key, val) {
        final data = Map<String, dynamic>.from(val as Map);
        final bool isActive = data['isActive'] == true || data['isActive'] == null;
        if (!isActive) return;

        final double baseFare = (data['baseFare'] ?? 30).toDouble();
        final double perKmRate = (data['perKmRate'] ?? 12).toDouble();
        final double perMinuteRate = (data['perMinuteRate'] ?? 1.5).toDouble();
        final double minimumFare = (data['minimumFare'] ?? 40).toDouble();
        final double computedFare = max(minimumFare, (baseFare + (distanceKm * perKmRate) + (durationMin * perMinuteRate)).roundToDouble());

        // Count riders nearby (within 8km)
        int nearby = 0;
        double minRiderDist = 999.0;
        riderLocs.forEach((rKey, rVal) {
          if (rVal is Map) {
            final rLat = (rVal['latitude'] ?? rVal['lat'] ?? 0.0).toDouble();
            final rLng = (rVal['longitude'] ?? rVal['lng'] ?? 0.0).toDouble();
            if (rLat != 0.0 && rLng != 0.0) {
              final d = _mapboxService.calculateDistance(pickup.lat, pickup.lng, rLat, rLng);
              if (d <= 8.0) {
                nearby++;
                if (d < minRiderDist) minRiderDist = d;
              }
            }
          }
        });

        final int dynamicEta = minRiderDist < 900 ? max(2, (minRiderDist * 2.5).round()) : max(3, (data['displayOrder'] ?? 3) * 2);

        liveList.add(VehicleFareOption(
          id: key,
          name: (data['name'] ?? key).toString(),
          subtitle: (data['tagline'] ?? 'Women-Driven Safe Commute').toString(),
          etaMin: dynamicEta,
          capacity: (data['capacity'] ?? 1).toInt(),
          fare: computedFare,
          distanceKm: distanceKm,
          durationMin: durationMin,
          icon: (data['category'] ?? 'scooter').toString(),
          imageUrl: (data['imageUrl'] ?? '').toString(),
          isElectric: data['isElectric'] == true,
          badge: (data['badge'] ?? '⚡ 100% Electric').toString(),
          nearbyCount: max(1, nearby),
        ));
      });

      if (liveList.isNotEmpty) {
        liveList.sort((a, b) => a.fare.compareTo(b.fare));
        return liveList;
      }
    } catch (e) {
      debugPrint("Live dynamic vehicle fare fetch notice: $e");
    }

    return defaultFares;
  }

  // 2. Create Ride in Realtime Database & push to activeRequests
  Future<RideModel> createRide({
    required String userId,
    required LocationPoint pickup,
    required LocationPoint drop,
    required VehicleFareOption selectedVehicle,
    String paymentMethod = 'cash',
  }) async {
    final rideId = 'ride_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final otp = (1000 + Random().nextInt(9000)).toString();

    final ride = RideModel(
      rideId: rideId,
      userId: userId,
      status: 'requested',
      pickup: pickup,
      drop: drop,
      vehicleType: selectedVehicle.id,
      fare: selectedVehicle.fare,
      distanceKm: selectedVehicle.distanceKm,
      durationMin: selectedVehicle.durationMin,
      paymentMethod: paymentMethod,
      otp: otp,
    );

    try {
      // Write to /rides/{rideId}
      await db.ref('rides/$rideId').set(ride.toMap());

      // Write to /activeRequests/{rideId}
      await db.ref('activeRequests/$rideId').set({
        'rideId': rideId,
        'userId': userId,
        'vehicleType': selectedVehicle.id,
        'pickupLat': pickup.lat,
        'pickupLng': pickup.lng,
        'pickupAddress': pickup.address,
        'dropAddress': drop.address,
        'fare': selectedVehicle.fare,
        'distanceKm': selectedVehicle.distanceKm,
        'createdAt': ServerValue.timestamp,
      });

      debugPrint("Ride $rideId created in Firebase Realtime Database");
    } catch (e) {
      debugPrint("Firebase Realtime DB createRide note: $e");
    }

    return ride;
  }

  // 3. Stream Single Ride Status
  Stream<RideModel?> streamRide(String rideId) {
    try {
      return db.ref('rides/$rideId').onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          return RideModel.fromMap(data, rideId: rideId);
        }
        return null;
      }).handleError((e) {
        debugPrint("streamRide notice: $e");
        return null;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  // 4. Stream Live Rider Location for tracking
  Stream<LocationPoint?> streamRiderLocation(String riderId) {
    try {
      return db.ref('riderLocations/$riderId').onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final lat = (data['lat'] is num) ? (data['lat'] as num).toDouble() : 17.0005;
          final lng = (data['lng'] is num) ? (data['lng'] as num).toDouble() : 81.7800;
          return LocationPoint(lat: lat, lng: lng, address: 'Live Captain Location');
        }
        return null;
      }).handleError((e) {
        debugPrint("streamRiderLocation notice: $e");
        return null;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  // 5. Cancel Ride
  Future<void> cancelRide(String rideId, {String cancelledBy = 'user', String? reason}) async {
    try {
      await db.ref('rides/$rideId').update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        'cancelledBy': cancelledBy,
        if (reason != null) 'cancellationReason': reason,
      });

      // Remove from activeRequests
      await db.ref('activeRequests/$rideId').remove();
    } catch (e) {
      debugPrint("Cancel ride notice: $e");
    }
  }

  // 6. Get User Rides History
  Future<List<RideModel>> getUserRides(String userId) async {
    try {
      final snapshot = await db.ref('rides').orderByChild('userId').equalTo(userId).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final list = data.entries.map((e) {
          final val = Map<dynamic, dynamic>.from(e.value as Map);
          return RideModel.fromMap(val, rideId: e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
    } catch (e) {
      debugPrint("getUserRides notice: $e");
    }
    return [];
  }
}
