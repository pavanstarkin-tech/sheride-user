class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String gender;
  final String profileImageUrl;
  final String emergencyContact;
  final String createdAt;
  final bool isActive;
  final bool isBlocked;
  final double walletBalance;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email = '',
    this.gender = 'Female',
    this.profileImageUrl = '',
    this.emergencyContact = '',
    String? createdAt,
    this.isActive = true,
    this.isBlocked = false,
    this.walletBalance = 0.0,
    this.role = 'user',
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'emergencyContact': emergencyContact,
      'createdAt': createdAt,
      'isActive': isActive,
      'isBlocked': isBlocked,
      'walletBalance': walletBalance,
      'role': role,
    };
  }

  factory UserModel.fromMap(Map<dynamic, dynamic> map, {String? uid}) {
    return UserModel(
      uid: (map['uid'] ?? uid ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      gender: (map['gender'] ?? 'Female').toString(),
      profileImageUrl: (map['profileImageUrl'] ?? '').toString(),
      emergencyContact: (map['emergencyContact'] ?? '').toString(),
      createdAt: (map['createdAt'] ?? '').toString(),
      isActive: map['isActive'] == true || map['isActive'] == 1,
      isBlocked: map['isBlocked'] == true || map['isBlocked'] == 1,
      walletBalance: (map['walletBalance'] is num) ? (map['walletBalance'] as num).toDouble() : 0.0,
      role: (map['role'] ?? 'user').toString(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? email,
    String? gender,
    String? profileImageUrl,
    String? emergencyContact,
    String? createdAt,
    bool? isActive,
    bool? isBlocked,
    double? walletBalance,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isBlocked: isBlocked ?? this.isBlocked,
      walletBalance: walletBalance ?? this.walletBalance,
      role: role ?? this.role,
    );
  }
}
