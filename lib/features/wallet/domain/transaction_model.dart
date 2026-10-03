class TransactionModel {
  final String transactionId;
  final String uid;
  final String type; // 'credit', 'debit', 'ride_payment', 'refund', 'offer_cashback'
  final double amount;
  final String? rideId;
  final String description;
  final int createdAt;
  final String status; // 'success', 'failed', 'pending'

  const TransactionModel({
    required this.transactionId,
    required this.uid,
    required this.type,
    required this.amount,
    this.rideId,
    required this.description,
    required this.createdAt,
    this.status = 'success',
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'uid': uid,
      'type': type,
      'amount': amount,
      'rideId': rideId,
      'description': description,
      'createdAt': createdAt,
      'status': status,
    };
  }

  factory TransactionModel.fromMap(Map<dynamic, dynamic>? map, String transactionId) {
    if (map == null) {
      return TransactionModel(
        transactionId: transactionId,
        uid: '',
        type: 'credit',
        amount: 0.0,
        description: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return TransactionModel(
      transactionId: transactionId,
      uid: (map['uid'] ?? '').toString(),
      type: (map['type'] ?? 'credit').toString(),
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      rideId: map['rideId']?.toString(),
      description: (map['description'] ?? '').toString(),
      createdAt: (map['createdAt'] is num) ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      status: (map['status'] ?? 'success').toString(),
    );
  }
}
