import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      appBar: AppBar(
        title: Text(
          'About SheRide',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Logo & Brand
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset('assets/images/ogo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Image.asset(
              'assets/images/banner_logo.png',
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'SheRide',
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Women Ride Together • Version 1.0.0 (Build 100)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE91E63)),
            ),
            const SizedBox(height: 24),

            // Mission Statement Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SheRide was built from the ground up to deliver safe, reliable, dignified, and sustainable urban mobility exclusively for women passengers and women captains across India. Every ride empowers women financially and ensures complete peace of mind with our Pink Shield real-time safety system.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.5, color: const Color(0xFF555555)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legal & Terms Links
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFE91E63)),
                    title: Text('Privacy Policy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Privacy Policy'),
                          content: const Text('SheRide takes data privacy seriously. GPS tracking is only enabled during active trips and shared strictly with your designated emergency contacts and security teams.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: Color(0xFFE91E63)),
                    title: Text('Terms of Service', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Terms of Service'),
                          content: const Text('By using SheRide, you agree to respectful community conduct. All riders and drivers undergo verification.'),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.code_rounded, color: Color(0xFFE91E63)),
                    title: Text('Open Source Licenses', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => showLicensePage(context: context, applicationName: 'SheRide', applicationVersion: '1.0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Made with 🌸 for Empowered Women Everywhere',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }
}
