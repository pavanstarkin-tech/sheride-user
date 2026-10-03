class WalletModel {
  final String uid;
  final double balance;
  final String currency;
  final int updatedAt;

  const WalletModel({
    required this.uid,
    this.balance = 0.0,
    this.currency = 'INR',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'balance': balance,
      'currency': currency,
      'updatedAt': updatedAt,
    };
  }

  factory WalletModel.fromMap(Map<dynamic, dynamic>? map, String uid) {
    if (map == null) {
      return WalletModel(uid: uid, balance: 0.0, currency: 'INR', updatedAt: DateTime.now().millisecondsSinceEpoch);
    }
    return WalletModel(
      uid: uid,
      balance: (map['balance'] is num) ? (map['balance'] as num).toDouble() : 0.0,
      currency: (map['currency'] ?? 'INR').toString(),
      updatedAt: (map['updatedAt'] is num) ? (map['updatedAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }

  WalletModel copyWith({
    String? uid,
    double? balance,
    String? currency,
    int? updatedAt,
  }) {
    return WalletModel(
      uid: uid ?? this.uid,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
