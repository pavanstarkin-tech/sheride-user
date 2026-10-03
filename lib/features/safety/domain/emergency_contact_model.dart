class EmergencyContactModel {
  final String contactId;
  final String name;
  final String phone;
  final String relation; // Mother | Father | Sister | Friend | Guardian

  const EmergencyContactModel({
    required this.contactId,
    required this.name,
    required this.phone,
    this.relation = 'Guardian',
  });

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'name': name,
      'phone': phone,
      'relation': relation,
    };
  }

  factory EmergencyContactModel.fromMap(Map<dynamic, dynamic>? map, String contactId) {
    if (map == null) {
      return EmergencyContactModel(
        contactId: contactId,
        name: 'Guardian',
        phone: '+919876543210',
        relation: 'Guardian',
      );
    }
    return EmergencyContactModel(
      contactId: contactId,
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      relation: (map['relation'] ?? 'Guardian').toString(),
    );
  }

  EmergencyContactModel copyWith({
    String? contactId,
    String? name,
    String? phone,
    String? relation,
  }) {
    return EmergencyContactModel(
      contactId: contactId ?? this.contactId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
    );
  }
}
