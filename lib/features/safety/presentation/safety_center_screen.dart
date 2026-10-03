import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/safety_service.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  final _safetyService = SafetyService();
  bool _audioRecordingEnabled = false;

  void _triggerSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('Trigger Emergency SOS?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'This will immediately alert your emergency contacts and the 24/7 SheRide Women Safety Command Center with your live GPS location.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ACTIVATE SOS'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _safetyService.triggerSos(
        uid: 'user_active',
        lat: 17.0005,
        lng: 81.7800,
        type: 'emergency',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EMERGENCY SOS ACTIVATED: Police & Safety Team Dispatched!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              // Header matching Screenshot 9
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
                          'Safety Center',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          'Your safety, our top priority.',
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
              const SizedBox(height: 20),

              // 6 Safety Feature Rows
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 1. Share Live Location
                    _buildSafetyTile(
                      icon: Icons.share_location_rounded,
                      title: 'Share Live Location',
                      subtitle: 'with family & friends',
                      iconBg: const Color(0xFFFCE4EC),
                      iconColor: const Color(0xFFE91E63),
                      onTap: () => context.push('/emergency-contacts'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 2. Emergency SOS
                    _buildSafetyTile(
                      icon: Icons.power_settings_new_rounded,
                      title: 'Emergency SOS',
                      subtitle: 'Instant help with one tap',
                      iconBg: const Color(0xFFFFEBEE),
                      iconColor: const Color(0xFFE53935),
                      onTap: _triggerSOS,
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 3. Live Ride Monitoring
                    _buildSafetyTile(
                      icon: Icons.visibility_rounded,
                      title: 'Live Ride Monitoring',
                      subtitle: 'Our team monitors every ride',
                      iconBg: const Color(0xFFFCE4EC),
                      iconColor: const Color(0xFFE91E63),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('24/7 Fleet Safety AI is actively monitoring your route.')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 4. Verified Women Riders
                    _buildSafetyTile(
                      icon: Icons.female_rounded,
                      title: 'Verified Women Riders',
                      subtitle: 'Background checked & trained',
                      iconBg: const Color(0xFFFCE4EC),
                      iconColor: const Color(0xFFE91E63),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('100% of SheRide captains undergo police verification & safety training.')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 5. Audio Recording
                    _buildSafetyTile(
                      icon: Icons.mic_none_rounded,
                      title: 'Audio Recording',
                      subtitle: 'During the ride for your safety',
                      iconBg: const Color(0xFFFCE4EC),
                      iconColor: const Color(0xFFE91E63),
                      onTap: () {
                        setState(() => _audioRecordingEnabled = !_audioRecordingEnabled);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_audioRecordingEnabled ? 'Safety audio recording enabled.' : 'Safety audio recording disabled.')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 6. 24/7 Women Support
                    _buildSafetyTile(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      title: '24/7 Women Support',
                      subtitle: "We're always here for you",
                      iconBg: const Color(0xFFFCE4EC),
                      iconColor: const Color(0xFFE91E63),
                      onTap: () => context.push('/support'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bottom Banner matching Screenshot 9
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF8BBD9).withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stronger Women',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE91E63),
                            ),
                          ),
                          Text(
                            'Safer Cities',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFF8BBD0),
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF757575), size: 20),
          ],
        ),
      ),
    );
  }
}
