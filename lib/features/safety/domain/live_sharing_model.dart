class LiveSharingModel {
  final String rideId;
  final bool isActive;
  final List<String> sharedWith;
  final int expiresAt;

  const LiveSharingModel({
    required this.rideId,
    this.isActive = true,
    this.sharedWith = const [],
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'isActive': isActive,
      'sharedWith': sharedWith,
      'expiresAt': expiresAt,
    };
  }

  factory LiveSharingModel.fromMap(Map<dynamic, dynamic>? map, String rideId) {
    if (map == null) {
      return LiveSharingModel(
        rideId: rideId,
        isActive: false,
        expiresAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return LiveSharingModel(
      rideId: rideId,
      isActive: map['isActive'] == true || map['isActive'] == 'true',
      sharedWith: (map['sharedWith'] is List)
          ? (map['sharedWith'] as List).map((e) => e.toString()).toList()
          : const [],
      expiresAt: (map['expiresAt'] is num) ? (map['expiresAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }
}
