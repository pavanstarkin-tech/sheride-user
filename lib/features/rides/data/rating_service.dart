import 'package:firebase_database/firebase_database.dart';
import '../domain/rating_model.dart';

class RatingService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  static final Map<String, RatingModel> _localRatings = {};

  Future<bool> submitRating(RatingModel rating) async {
    _localRatings[rating.rideId] = rating;
    final db = _db;
    if (db != null) {
      try {
        await db.ref('ratings/${rating.rideId}').set(rating.toMap());

        // Update rider's average rating if riderId is provided
        if (rating.toUid.isNotEmpty) {
          final riderRef = db.ref('riders/${rating.toUid}');
          final snap = await riderRef.get();
          if (snap.exists && snap.value != null) {
            final data = Map<dynamic, dynamic>.from(snap.value as Map);
            final currentRating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 5.0;
            final totalRides = (data['totalRides'] is num) ? (data['totalRides'] as num).toInt() : 1;
            final newTotal = totalRides + 1;
            final newAvg = ((currentRating * totalRides) + rating.rating) / newTotal;
            await riderRef.update({
              'rating': double.parse(newAvg.toStringAsFixed(1)),
              'totalRides': newTotal,
            });
          }
        }
        return true;
      } catch (e) {
        // Fallback success
      }
    }
    return true;
  }
}
