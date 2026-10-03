import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_db_service.dart';
import '../../auth/domain/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _profile;
  final String _fallbackAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      final db = RealtimeDbService();
      final p = await db.getUserData(uid);
      if (mounted) setState(() => _profile = p);
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Logout from SheRide?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: const Text('You will need to sign in again to book rides.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      final auth = context.read<AuthService>();
      await auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUser = auth.currentUser;
    final name = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : (currentUser?.displayName?.isNotEmpty == true ? currentUser!.displayName! : 'SheRide Member');
    final email = _profile?.email.isNotEmpty == true
        ? _profile!.email
        : (currentUser?.email?.isNotEmpty == true ? currentUser!.email! : (currentUser?.phoneNumber ?? 'No email set'));
    
    final photo = (_profile?.profileImageUrl.isNotEmpty == true)
        ? _profile!.profileImageUrl
        : ((currentUser?.photoURL?.isNotEmpty == true) ? currentUser!.photoURL! : _fallbackAvatar);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Profile title (left) + Help Pill (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/support'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF8BBD9)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFFE91E63)),
                          const SizedBox(width: 4),
                          Text(
                            '24/7 Help',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE91E63),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // User Info Card with prominent DP and Edit Trigger
              GestureDetector(
                onTap: () async {
                  await context.push('/edit-profile');
                  _loadProfile();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                    border: Border.all(color: const Color(0xFFFCE4EC)),
                  ),
                  child: Row(
                    children: [
                      // DP with verified badge
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE91E63), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFFF8BBD0),
                              backgroundImage: NetworkImage(photo),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              email,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '4.92 • Verified Rider',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF757575), size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // All 9 Profile Sub-Pages Fully Functional
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
                    // 1. Personal Information
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      onTap: () async {
                        await context.push('/edit-profile');
                        _loadProfile();
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 2. Payment Methods & SheRide Wallet
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Payment Methods & Wallet',
                      onTap: () => context.push('/wallet'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 3. Saved Places
                    _buildMenuItem(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Saved Places (Home, Work)',
                      onTap: () => context.push('/saved-places'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 4. Refer & Earn with Get ₹50 Badge
                    _buildMenuItem(
                      icon: Icons.card_giftcard_rounded,
                      title: 'Refer & Earn',
                      badgeText: 'Get ₹50',
                      onTap: () => context.push('/rewards'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 5. My Rewards & Coupons
                    _buildMenuItem(
                      icon: Icons.emoji_events_outlined,
                      title: 'My Rewards & Promo Codes',
                      onTap: () => context.push('/rewards'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 6. Emergency Contacts (Pink Shield)
                    _buildMenuItem(
                      icon: Icons.contact_phone_outlined,
                      title: 'Emergency Contacts',
                      onTap: () => context.push('/emergency-contacts'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 7. Safety Center & SOS
                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      title: 'Pink Shield Safety & SOS',
                      badgeText: 'Active',
                      onTap: () => context.push('/safety-center'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 8. Notifications
                    _buildMenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications & Alerts',
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 9. App Settings & Ride Comfort Preferences
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'App Settings & Preferences',
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 10. About SheRide & Legal
                    _buildMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About SheRide & Legal',
                      onTap: () => context.push('/about'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),

                    // 11. Logout
                    _buildMenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      isLogout: true,
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? badgeText,
    bool isLogout = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isLogout ? const Color(0xFFE53935) : const Color(0xFF1A1A1A),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isLogout ? const Color(0xFFE53935) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (badgeText != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE91E63),
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF757575), size: 18),
          ],
        ),
      ),
    );
  }
}
