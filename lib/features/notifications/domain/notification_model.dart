class NotificationModel {
  final String notificationId;
  final String title;
  final String body;
  final String type; // 'ride' | 'safety' | 'offer' | 'system'
  final Map<String, dynamic> data;
  final bool isRead;
  final int createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.title,
    required this.body,
    this.type = 'system',
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  factory NotificationModel.fromMap(Map<dynamic, dynamic>? map, String notificationId) {
    if (map == null) {
      return NotificationModel(
        notificationId: notificationId,
        title: 'Notification',
        body: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return NotificationModel(
      notificationId: notificationId,
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'system').toString(),
      data: (map['data'] is Map) ? Map<String, dynamic>.from(map['data'] as Map) : const {},
      isRead: map['isRead'] == true || map['isRead'] == 'true',
      createdAt: (map['createdAt'] is num) ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }

  NotificationModel copyWith({
    String? notificationId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    int? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
