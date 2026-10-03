class LocationPoint {
  final double lat;
  final double lng;
  final String address;
  final String? name;

  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.address,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address,
      if (name != null) 'name': name,
    };
  }

  factory LocationPoint.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const LocationPoint(lat: 17.0005, lng: 81.7800, address: 'Rajahmundry, AP');
    }
    return LocationPoint(
      lat: (map['lat'] is num) ? (map['lat'] as num).toDouble() : 17.0005,
      lng: (map['lng'] is num) ? (map['lng'] as num).toDouble() : 81.7800,
      address: (map['address'] ?? 'Unknown location').toString(),
      name: map['name']?.toString(),
    );
  }
}

class RideModel {
  final String rideId;
  final String userId;
  final String? riderId;
  final String status; // requested | accepted | arrived | started | completed | cancelled
  final LocationPoint pickup;
  final LocationPoint drop;
  final String vehicleType; // bike | auto | cab_economy | cab_premium
  final double fare;
  final double distanceKm;
  final int durationMin;
  final int createdAt;
  final int? acceptedAt;
  final int? startedAt;
  final int? completedAt;
  final int? cancelledAt;
  final String? cancelledBy; // user | rider | system
  final String paymentMethod; // cash | wallet | upi
  final String otp; // 4-digit start OTP

  // Rider details cache (populated when accepted)
  final String? riderName;
  final String? riderPhone;
  final String? riderPhoto;
  final String? vehicleNumber;
  final double? riderRating;

  RideModel({
    required this.rideId,
    required this.userId,
    this.riderId,
    this.status = 'requested',
    required this.pickup,
    required this.drop,
    required this.vehicleType,
    required this.fare,
    required this.distanceKm,
    required this.durationMin,
    int? createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.paymentMethod = 'cash',
    required this.otp,
    this.riderName,
    this.riderPhone,
    this.riderPhoto,
    this.vehicleNumber,
    this.riderRating,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'userId': userId,
      'riderId': riderId,
      'status': status,
      'pickup': pickup.toMap(),
      'drop': drop.toMap(),
      'vehicleType': vehicleType,
      'fare': fare,
      'distanceKm': distanceKm,
      'durationMin': durationMin,
      'createdAt': createdAt,
      'acceptedAt': acceptedAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
      'cancelledBy': cancelledBy,
      'paymentMethod': paymentMethod,
      'otp': otp,
      if (riderName != null) 'riderName': riderName,
      if (riderPhone != null) 'riderPhone': riderPhone,
      if (riderPhoto != null) 'riderPhoto': riderPhoto,
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      if (riderRating != null) 'riderRating': riderRating,
    };
  }

  factory RideModel.fromMap(Map<dynamic, dynamic> map, {String? rideId}) {
    return RideModel(
      rideId: (map['rideId'] ?? rideId ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      riderId: map['riderId']?.toString(),
      status: (map['status'] ?? 'requested').toString(),
      pickup: LocationPoint.fromMap(map['pickup'] as Map?),
      drop: LocationPoint.fromMap(map['drop'] as Map?),
      vehicleType: (map['vehicleType'] ?? 'bike').toString(),
      fare: (map['fare'] is num) ? (map['fare'] as num).toDouble() : 50.0,
      distanceKm: (map['distanceKm'] is num) ? (map['distanceKm'] as num).toDouble() : 3.0,
      durationMin: (map['durationMin'] is num) ? (map['durationMin'] as num).toInt() : 10,
      createdAt: (map['createdAt'] is num) ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      acceptedAt: (map['acceptedAt'] is num) ? (map['acceptedAt'] as num).toInt() : null,
      startedAt: (map['startedAt'] is num) ? (map['startedAt'] as num).toInt() : null,
      completedAt: (map['completedAt'] is num) ? (map['completedAt'] as num).toInt() : null,
      cancelledAt: (map['cancelledAt'] is num) ? (map['cancelledAt'] as num).toInt() : null,
      cancelledBy: map['cancelledBy']?.toString(),
      paymentMethod: (map['paymentMethod'] ?? 'cash').toString(),
      otp: (map['otp'] ?? '1234').toString(),
      riderName: map['riderName']?.toString(),
      riderPhone: map['riderPhone']?.toString(),
      riderPhoto: map['riderPhoto']?.toString(),
      vehicleNumber: map['vehicleNumber']?.toString(),
      riderRating: (map['riderRating'] is num) ? (map['riderRating'] as num).toDouble() : null,
    );
  }

  RideModel copyWith({
    String? rideId,
    String? userId,
    String? riderId,
    String? status,
    LocationPoint? pickup,
    LocationPoint? drop,
    String? vehicleType,
    double? fare,
    double? distanceKm,
    int? durationMin,
    int? createdAt,
    int? acceptedAt,
    int? startedAt,
    int? completedAt,
    int? cancelledAt,
    String? cancelledBy,
    String? paymentMethod,
    String? otp,
    String? riderName,
    String? riderPhone,
    String? riderPhoto,
    String? vehicleNumber,
    double? riderRating,
  }) {
    return RideModel(
      rideId: rideId ?? this.rideId,
      userId: userId ?? this.userId,
      riderId: riderId ?? this.riderId,
      status: status ?? this.status,
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      vehicleType: vehicleType ?? this.vehicleType,
      fare: fare ?? this.fare,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      otp: otp ?? this.otp,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      riderPhoto: riderPhoto ?? this.riderPhoto,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      riderRating: riderRating ?? this.riderRating,
    );
  }
}
