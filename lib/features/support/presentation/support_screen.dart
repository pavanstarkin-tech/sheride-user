import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showChatDialog(String topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SheRide 24/7 Support Desk',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Connected to: $topic',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFE91E63), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFF8BBD0),
                    child: Icon(Icons.support_agent_rounded, color: Color(0xFFE91E63), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hello! A woman support representative is ready to help you.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Connected to live support chat!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Start Chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header matching Screenshot 10
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Help & Support',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          "We're here for you, always.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 16),

              // Search bar "Search for help..."
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF757575), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: const Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Search for help...',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: const Color(0xFF9E9E9E)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 7 Support Category Tiles matching Screenshot 10
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 1. Live Chat
                    _buildSupportTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Live Chat',
                      subtitle: 'Chat with our support team',
                      iconBg: const Color(0xFFEDE7F6),
                      iconColor: const Color(0xFF5E35B1),
                      onTap: () => _showChatDialog('Live Support Chat'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 2. Call Support
                    _buildSupportTile(
                      icon: Icons.phone_outlined,
                      title: 'Call Support',
                      subtitle: '24/7 women support',
                      iconBg: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF2E7D32),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calling SheRide 24/7 Women Helpline (1800-SHERIDE)...')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 3. Raise a Safety Concern
                    _buildSupportTile(
                      icon: Icons.warning_amber_rounded,
                      title: 'Raise a Safety Concern',
                      subtitle: 'Report an issue',
                      iconBg: const Color(0xFFFFF3E0),
                      iconColor: const Color(0xFFF57C00),
                      onTap: () => _showChatDialog('Safety Concern'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 4. Lost & Found
                    _buildSupportTile(
                      icon: Icons.card_travel_rounded,
                      title: 'Lost & Found',
                      subtitle: 'Get help with lost items',
                      iconBg: const Color(0xFFFFEBEE),
                      iconColor: const Color(0xFFE53935),
                      onTap: () => _showChatDialog('Lost & Found'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 5. Payment or Refund
                    _buildSupportTile(
                      icon: Icons.payment_rounded,
                      title: 'Payment or Refund',
                      subtitle: 'Fare, wallet and payment related',
                      iconBg: const Color(0xFFE3F2FD),
                      iconColor: const Color(0xFF1976D2),
                      onTap: () => _showChatDialog('Payment & Refund'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 6. Trip Issue
                    _buildSupportTile(
                      icon: Icons.directions_car_filled_outlined,
                      title: 'Trip Issue',
                      subtitle: 'Cancellation, wrong fare, etc.',
                      iconBg: const Color(0xFFE0F7FA),
                      iconColor: const Color(0xFF0097A7),
                      onTap: () => _showChatDialog('Trip Issue'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 7. App Support
                    _buildSupportTile(
                      icon: Icons.phone_android_rounded,
                      title: 'App Support',
                      subtitle: 'Technical help & account support',
                      iconBg: const Color(0xFFFCE4EC),
                      iconColor: const Color(0xFFE91E63),
                      onTap: () => _showChatDialog('App Technical Support'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF757575), size: 18),
          ],
        ),
      ),
    );
  }
}
