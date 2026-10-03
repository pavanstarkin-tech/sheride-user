class OfferModel {
  final String offerId;
  final String code;
  final String title;
  final String description;
  final String discountType; // 'percentage' or 'flat'
  final double discountValue;
  final double minFare;
  final double maxDiscount;
  final int validFrom;
  final int validUntil;
  final int usageLimit;
  final int usedCount;
  final List<String> forVehicleTypes;
  final bool isActive;

  const OfferModel({
    required this.offerId,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.minFare = 0.0,
    this.maxDiscount = 100.0,
    required this.validFrom,
    required this.validUntil,
    this.usageLimit = 1000,
    this.usedCount = 0,
    this.forVehicleTypes = const ['bike', 'auto', 'cab', 'ev_scooter', 'emergency_cab'],
    this.isActive = true,
  });

  double calculateDiscount(double fare, {String vehicleType = 'bike'}) {
    if (!isActive) return 0.0;
    if (fare < minFare) return 0.0;
    if (forVehicleTypes.isNotEmpty && !forVehicleTypes.contains(vehicleType)) return 0.0;

    double calculated = 0.0;
    if (discountType == 'percentage') {
      calculated = (fare * discountValue) / 100.0;
      if (maxDiscount > 0 && calculated > maxDiscount) {
        calculated = maxDiscount;
      }
    } else if (discountType == 'flat') {
      calculated = discountValue;
    }
    if (calculated > fare) {
      calculated = fare;
    }
    return calculated;
  }

  Map<String, dynamic> toMap() {
    return {
      'offerId': offerId,
      'code': code,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'minFare': minFare,
      'maxDiscount': maxDiscount,
      'validFrom': validFrom,
      'validUntil': validUntil,
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'forVehicleTypes': forVehicleTypes,
      'isActive': isActive,
    };
  }

  factory OfferModel.fromMap(Map<dynamic, dynamic>? map, String offerId) {
    if (map == null) {
      return OfferModel(
        offerId: offerId,
        code: 'WELCOME50',
        title: 'Flat 50% OFF',
        description: 'Get 50% off on your rides',
        discountType: 'percentage',
        discountValue: 50.0,
        validFrom: 0,
        validUntil: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      );
    }
    return OfferModel(
      offerId: offerId,
      code: (map['code'] ?? '').toString().toUpperCase(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      discountType: (map['discountType'] ?? 'percentage').toString(),
      discountValue: (map['discountValue'] is num) ? (map['discountValue'] as num).toDouble() : 0.0,
      minFare: (map['minFare'] is num) ? (map['minFare'] as num).toDouble() : 0.0,
      maxDiscount: (map['maxDiscount'] is num) ? (map['maxDiscount'] as num).toDouble() : 100.0,
      validFrom: (map['validFrom'] is num) ? (map['validFrom'] as num).toInt() : 0,
      validUntil: (map['validUntil'] is num) ? (map['validUntil'] as num).toInt() : DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      usageLimit: (map['usageLimit'] is num) ? (map['usageLimit'] as num).toInt() : 1000,
      usedCount: (map['usedCount'] is num) ? (map['usedCount'] as num).toInt() : 0,
      forVehicleTypes: (map['forVehicleTypes'] is List)
          ? (map['forVehicleTypes'] as List).map((e) => e.toString()).toList()
          : const ['bike', 'auto', 'cab', 'ev_scooter', 'emergency_cab'],
      isActive: map['isActive'] == true || map['isActive'] == 'true' || map['isActive'] == 1,
    );
  }
}
