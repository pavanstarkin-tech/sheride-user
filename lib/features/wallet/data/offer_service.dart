import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../domain/offer_model.dart';

class OfferService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  static final List<OfferModel> defaultOffers = [
    OfferModel(
      offerId: 'offer_1',
      code: 'SHERIDE50',
      title: 'FLAT 50% OFF',
      description: 'Get 50% off up to ₹60 on your first 5 rides',
      discountType: 'percentage',
      discountValue: 50.0,
      minFare: 50.0,
      maxDiscount: 60.0,
      validFrom: 0,
      validUntil: DateTime.now().add(const Duration(days: 60)).millisecondsSinceEpoch,
      isActive: true,
    ),
    OfferModel(
      offerId: 'offer_2',
      code: 'WORKRIDE',
      title: 'Office Ready',
      description: 'Daily office commute discount 20% off up to ₹40',
      discountType: 'percentage',
      discountValue: 20.0,
      minFare: 60.0,
      maxDiscount: 40.0,
      validFrom: 0,
      validUntil: DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch,
      isActive: true,
    ),
    OfferModel(
      offerId: 'offer_3',
      code: 'COLLEGE',
      title: 'College Special',
      description: 'Special 30% off for verified campus rides up to ₹50',
      discountType: 'percentage',
      discountValue: 30.0,
      minFare: 40.0,
      maxDiscount: 50.0,
      validFrom: 0,
      validUntil: DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch,
      isActive: true,
    ),
    OfferModel(
      offerId: 'offer_4',
      code: 'WEEKEND',
      title: 'Weekend Vibes',
      description: 'Flat ₹40 off on rides above ₹100 on Saturdays & Sundays',
      discountType: 'flat',
      discountValue: 40.0,
      minFare: 100.0,
      maxDiscount: 40.0,
      validFrom: 0,
      validUntil: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      isActive: true,
    ),
  ];

  Stream<List<OfferModel>> streamOffers() {
    final db = _db;
    if (db == null) {
      return Stream.value(defaultOffers);
    }

    return db.ref('offers').onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries.map((e) {
          return OfferModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).where((o) => o.isActive).toList();
        if (list.isNotEmpty) return list;
      }
      return defaultOffers;
    });
  }

  Future<List<OfferModel>> getOffers() async {
    final db = _db;
    if (db == null) return defaultOffers;
    try {
      final snap = await db.ref('offers').get();
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        final list = data.entries.map((e) {
          return OfferModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).where((o) => o.isActive).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return defaultOffers;
  }

  Future<OfferModel?> validatePromoCode(String code, double fare, {String vehicleType = 'bike'}) async {
    final cleanCode = code.trim().toUpperCase();
    final offers = await getOffers();
    final matched = offers.firstWhere(
      (o) => o.code.toUpperCase() == cleanCode && o.isActive,
      orElse: () => OfferModel(
        offerId: 'none',
        code: '',
        title: '',
        description: '',
        discountType: 'none',
        discountValue: 0,
        validFrom: 0,
        validUntil: 0,
        isActive: false,
      ),
    );

    if (matched.code.isEmpty) return null;
    if (fare < matched.minFare) return null;
    return matched;
  }
}
