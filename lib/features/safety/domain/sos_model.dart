class SosModel {
  final String sosId;
  final String uid;
  final String? rideId;
  final double lat;
  final double lng;
  final int timestamp;
  final String status; // 'active' | 'resolved'
  final String type; // 'emergency' | 'share_trip'

  const SosModel({
    required this.sosId,
    required this.uid,
    this.rideId,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.status = 'active',
    this.type = 'emergency',
  });

  Map<String, dynamic> toMap() {
    return {
      'sosId': sosId,
      'uid': uid,
      'rideId': rideId,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp,
      'status': status,
      'type': type,
    };
  }

  factory SosModel.fromMap(Map<dynamic, dynamic>? map, String sosId) {
    if (map == null) {
      return SosModel(
        sosId: sosId,
        uid: '',
        lat: 17.0005,
        lng: 81.7800,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return SosModel(
      sosId: sosId,
      uid: (map['uid'] ?? '').toString(),
      rideId: map['rideId']?.toString(),
      lat: (map['lat'] is num) ? (map['lat'] as num).toDouble() : 17.0005,
      lng: (map['lng'] is num) ? (map['lng'] as num).toDouble() : 81.7800,
      timestamp: (map['timestamp'] is num) ? (map['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      status: (map['status'] ?? 'active').toString(),
      type: (map['type'] ?? 'emergency').toString(),
    );
  }
}
