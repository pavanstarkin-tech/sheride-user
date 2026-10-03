import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'English';
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _femaleCaptainPriority = true;
  bool _silentRidePreference = false;
  bool _acPreference = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      appBar: AppBar(
        title: Text(
          'App Settings & Preferences',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Language Preference
          _buildSectionHeader('Language & Localization'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildLanguageRadio('English', 'English (Default)'),
                const Divider(height: 1),
                _buildLanguageRadio('Hindi', 'हिन्दी (Hindi)'),
                const Divider(height: 1),
                _buildLanguageRadio('Telugu', 'తెలుగు (Telugu)'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ride Safety & Comfort Preferences
          _buildSectionHeader('Ride Comfort & Preferences'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFE91E63),
                  title: Text('100% Female Captain Priority', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('Always prioritize verified women riders & drivers', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                  value: _femaleCaptainPriority,
                  onChanged: (v) => setState(() => _femaleCaptainPriority = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFE91E63),
                  title: Text('Silent Ride Mode', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('Inform captain to minimize conversation during ride', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                  value: _silentRidePreference,
                  onChanged: (v) => setState(() => _silentRidePreference = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFE91E63),
                  title: Text('AC Always Preferred', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('Request AC turned on in all car bookings', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                  value: _acPreference,
                  onChanged: (v) => setState(() => _acPreference = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notifications
          _buildSectionHeader('Notifications & Security Alerts'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFE91E63),
                  title: Text('Push Notifications', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('Real-time trip updates and captain arrival alerts', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFFE91E63),
                  title: Text('Emergency SMS Alerts to Family', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text('Auto-send SMS with live GPS link on trip start', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                  value: _smsAlerts,
                  onChanged: (v) => setState(() => _smsAlerts = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved! 🌸'), backgroundColor: Color(0xFFE91E63)),
              );
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text('Save Preferences', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF757575)),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
      ],
    );
  }

  Widget _buildLanguageRadio(String code, String label) {
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      activeColor: const Color(0xFFE91E63),
      title: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700)),
      value: code,
      groupValue: _selectedLanguage,
      onChanged: (v) => setState(() => _selectedLanguage = v!),
    );
  }
}
