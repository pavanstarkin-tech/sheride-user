class RatingModel {
  final String rideId;
  final String fromUid;
  final String toUid;
  final double rating; // 1.0 to 5.0
  final String feedback;
  final int createdAt;

  const RatingModel({
    required this.rideId,
    required this.fromUid,
    required this.toUid,
    required this.rating,
    this.feedback = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'fromUid': fromUid,
      'toUid': toUid,
      'rating': rating,
      'feedback': feedback,
      'createdAt': createdAt,
    };
  }

  factory RatingModel.fromMap(Map<dynamic, dynamic>? map, String rideId) {
    if (map == null) {
      return RatingModel(
        rideId: rideId,
        fromUid: '',
        toUid: '',
        rating: 5.0,
        feedback: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return RatingModel(
      rideId: rideId,
      fromUid: (map['fromUid'] ?? '').toString(),
      toUid: (map['toUid'] ?? '').toString(),
      rating: (map['rating'] is num) ? (map['rating'] as num).toDouble() : 5.0,
      feedback: (map['feedback'] ?? '').toString(),
      createdAt: (map['createdAt'] is num) ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }
}
