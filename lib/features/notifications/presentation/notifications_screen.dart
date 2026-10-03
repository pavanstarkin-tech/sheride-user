import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/notification_service.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final String _currentUid = 'user_1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              await _notificationService.markAllAsRead(_currentUid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read.')),
                );
              }
            },
            child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<NotificationModel>>(
          stream: _notificationService.streamNotifications(_currentUid),
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.secondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('You are all caught up!', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final notif = list[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: notif.isRead ? Colors.white : Colors.pink.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: notif.isRead ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getIconBgColor(notif.type),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getIcon(notif.type), color: _getIconColor(notif.type), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (!notif.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif.body,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.9)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateTime.fromMillisecondsSinceEpoch(notif.createdAt).toString().substring(0, 16),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    if (type == 'safety') return Icons.shield_rounded;
    if (type == 'ride') return Icons.electric_scooter_rounded;
    if (type == 'offer') return Icons.percent_rounded;
    return Icons.notifications_rounded;
  }

  Color _getIconBgColor(String type) {
    if (type == 'safety') return Colors.red.shade50;
    if (type == 'offer') return Colors.green.shade50;
    return AppColors.secondary.withValues(alpha: 0.2);
  }

  Color _getIconColor(String type) {
    if (type == 'safety') return AppColors.emergencyRed;
    if (type == 'offer') return Colors.green.shade700;
    return AppColors.primary;
  }
}
