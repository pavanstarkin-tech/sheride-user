class SupportTicketModel {
  final String ticketId;
  final String uid;
  final String category; // 'safety' | 'payment' | 'trip' | 'app' | 'other'
  final String subject;
  final String message;
  final String? rideId;
  final String status; // 'open' | 'in_progress' | 'resolved'
  final int createdAt;
  final int updatedAt;

  const SupportTicketModel({
    required this.ticketId,
    required this.uid,
    required this.category,
    required this.subject,
    required this.message,
    this.rideId,
    this.status = 'open',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'uid': uid,
      'category': category,
      'subject': subject,
      'message': message,
      'rideId': rideId,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory SupportTicketModel.fromMap(Map<dynamic, dynamic>? map, String ticketId) {
    if (map == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return SupportTicketModel(
        ticketId: ticketId,
        uid: '',
        category: 'safety',
        subject: '',
        message: '',
        createdAt: now,
        updatedAt: now,
      );
    }
    return SupportTicketModel(
      ticketId: ticketId,
      uid: (map['uid'] ?? '').toString(),
      category: (map['category'] ?? 'safety').toString(),
      subject: (map['subject'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      rideId: map['rideId']?.toString(),
      status: (map['status'] ?? 'open').toString(),
      createdAt: (map['createdAt'] is num) ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] is num) ? (map['updatedAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }
}
