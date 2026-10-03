import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_user/features/rides/domain/rating_model.dart';
import 'package:sheride_user/features/wallet/data/offer_service.dart';
import 'package:sheride_user/features/wallet/data/wallet_service.dart';
import 'package:sheride_user/features/wallet/domain/offer_model.dart';
import 'package:sheride_user/features/wallet/domain/transaction_model.dart';
import 'package:sheride_user/features/wallet/domain/wallet_model.dart';

void main() {
  group('Phase 3 Unit Tests - User App', () {
    test('WalletModel correctly serializes and deserializes', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final wallet = WalletModel(
        uid: 'user_priya',
        balance: 1500.0,
        currency: 'INR',
        updatedAt: now,
      );

      final map = wallet.toMap();
      expect(map['uid'], 'user_priya');
      expect(map['balance'], 1500.0);
      expect(map['currency'], 'INR');

      final fromMap = WalletModel.fromMap(map, 'user_priya');
      expect(fromMap.balance, 1500.0);
      expect(fromMap.currency, 'INR');
    });

    test('TransactionModel serializes and supports credit and debit types', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tx = TransactionModel(
        transactionId: 'tx_123',
        uid: 'user_priya',
        type: 'ride_payment',
        amount: 108.0,
        rideId: 'ride_001',
        description: 'Ride Payment for Bike Trip',
        createdAt: now,
        status: 'success',
      );

      final map = tx.toMap();
      expect(map['transactionId'], 'tx_123');
      expect(map['amount'], 108.0);
      expect(map['type'], 'ride_payment');

      final parsed = TransactionModel.fromMap(map, 'tx_123');
      expect(parsed.amount, 108.0);
      expect(parsed.rideId, 'ride_001');
    });

    test('OfferModel calculates percentage discount with max cap', () {
      final offer = OfferModel(
        offerId: 'o1',
        code: 'SHERIDE50',
        title: 'FLAT 50% OFF',
        description: '50% off up to ₹60',
        discountType: 'percentage',
        discountValue: 50.0,
        minFare: 50.0,
        maxDiscount: 60.0,
        validFrom: 0,
        validUntil: DateTime.now().add(const Duration(days: 10)).millisecondsSinceEpoch,
      );

      // ₹100 fare -> 50% = ₹50 (below max ₹60)
      expect(offer.calculateDiscount(100.0), 50.0);

      // ₹200 fare -> 50% = ₹100 -> capped at ₹60
      expect(offer.calculateDiscount(200.0), 60.0);

      // Below minFare (₹40 < ₹50) -> ₹0 discount
      expect(offer.calculateDiscount(40.0), 0.0);
    });

    test('OfferModel calculates flat discount accurately', () {
      final flatOffer = OfferModel(
        offerId: 'o2',
        code: 'WEEKEND',
        title: 'Weekend Vibes',
        description: 'Flat ₹40 off',
        discountType: 'flat',
        discountValue: 40.0,
        minFare: 100.0,
        maxDiscount: 40.0,
        validFrom: 0,
        validUntil: DateTime.now().add(const Duration(days: 10)).millisecondsSinceEpoch,
      );

      expect(flatOffer.calculateDiscount(120.0), 40.0);
      expect(flatOffer.calculateDiscount(80.0), 0.0); // Below min fare
    });

    test('RatingModel formats feedback and rating correctly', () {
      final rating = RatingModel(
        rideId: 'ride_101',
        fromUid: 'user_priya',
        toUid: 'rider_durga',
        rating: 5.0,
        feedback: 'Very safe ride and gentle driving!',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final map = rating.toMap();
      expect(map['rating'], 5.0);
      expect(map['feedback'], 'Very safe ride and gentle driving!');
      expect(map['toUid'], 'rider_durga');
    });

    test('WalletService addMoney and deductFare maintain balance locally', () async {
      final walletService = WalletService();
      const testUid = 'user_test_balance';

      await walletService.addMoney(testUid, 500.0);
      final walletAfterCredit = await walletService.getWallet(testUid);
      expect(walletAfterCredit.balance, greaterThanOrEqualTo(500.0)); // 0 default + 500

      await walletService.deductFare(testUid, 150.0, 'ride_test_01');
      final walletAfterDebit = await walletService.getWallet(testUid);
      expect(walletAfterDebit.balance, walletAfterCredit.balance - 150.0);
    });

    test('OfferService validates promo codes correctly', () async {
      final offerService = OfferService();
      final validOffer = await offerService.validatePromoCode('SHERIDE50', 100.0);
      expect(validOffer, isNotNull);
      expect(validOffer?.code, 'SHERIDE50');

      final invalidOffer = await offerService.validatePromoCode('UNKNOWN999', 100.0);
      expect(invalidOffer, isNull);
    });
  });
}
