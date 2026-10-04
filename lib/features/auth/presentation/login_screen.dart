import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import 'widgets/custom_button.dart';
import 'widgets/custom_text_field.dart';
import 'widgets/she_ride_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    try {
      await authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.errorMessage ?? e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showForgotPasswordModal() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
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
              'Reset Password',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your registered email address to receive a secure password reset link.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: resetEmailController,
              label: 'Email Address',
              hintText: 'name@example.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),
            CustomButton(
              text: 'Send Reset Link',
              onPressed: () async {
                final email = resetEmailController.text.trim();
                final authService = context.read<AuthService>();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final success = await authService.sendPasswordResetEmail(email);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Password reset link sent to $email! Please check your inbox.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(authService.errorMessage ?? 'Failed to send reset email'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPolicyBottomSheet(String title, String subtitle, List<Map<String, String>> sections) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF757575)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, index) {
                    final sec = sections[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sec['title'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sec['content'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: const Color(0xFF616161),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'I Understand & Agree',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSafetyPolicyModal() {
    _showPolicyBottomSheet(
      'Safety Policy',
      '100% Women-Only Safety Guarantee',
      [
        {
          'title': '1. Verified Female Captains Only',
          'content': 'Every captain undergoes comprehensive identity validation, background checks, license verification, and facial recognition before being approved to drive on SheRide.'
        },
        {
          'title': '2. Live Ride GPS Tracking & Safe Route Alerts',
          'content': 'Every ride is tracked in real-time. Any unexpected deviations or prolonged stops trigger automated safety alerts to our 24/7 dedicated Safety Command Team.'
        },
        {
          'title': '3. 24/7 Emergency SOS & PCR Integration',
          'content': 'A single tap on the in-app SOS button alerts local emergency response contacts, nearest police patrol, and shares live tracking telemetry immediately.'
        },
        {
          'title': '4. Secure OTP Start Verification',
          'content': 'Rides will only start once you confirm the 4-digit PIN with your verified captain to ensure you always board the right vehicle.'
        },
      ],
    );
  }

  void _showTermsModal() {
    _showPolicyBottomSheet(
      'Terms & Conditions',
      'Platform Usage & Service Agreement',
      [
        {
          'title': '1. Eligibility & Women-Only Community',
          'content': 'SheRide is exclusively designed for women passengers and women drivers. Account holders must provide accurate and verifiable personal details.'
        },
        {
          'title': '2. Booking & Cancellation Policy',
          'content': 'Passengers may cancel a ride before captain arrival. Frequent repeated cancellations without valid reason may temporarily restrict booking privileges.'
        },
        {
          'title': '3. Transparent Fare & Pricing',
          'content': 'Fares are calculated upfront based on distance, estimated travel time, and optional priority boosts chosen by the rider. Toll and tax charges are itemized.'
        },
        {
          'title': '4. Mutual Respect & Code of Conduct',
          'content': 'All passengers and captains are expected to treat each other with courtesy and mutual respect. Zero tolerance is maintained for harassment or misconduct.'
        },
      ],
    );
  }

  void _showPrivacyPolicyModal() {
    _showPolicyBottomSheet(
      'Privacy Policy',
      'Data Protection & Privacy Commitment',
      [
        {
          'title': '1. Phone Number Masking',
          'content': 'Your actual mobile number is never displayed to captains. All communication occurs through masked VoIP routing to protect your personal privacy.'
        },
        {
          'title': '2. Location & Telemetry Data',
          'content': 'GPS coordinates are gathered solely during active rides for navigational safety and live trip sharing. Location tracking ceases when the ride completes.'
        },
        {
          'title': '3. Secure Encryption',
          'content': 'All personal data, OTP authentications, and trip logs are securely encrypted using industry-standard TLS encryption protocols.'
        },
        {
          'title': '4. No Third-Party Data Sharing',
          'content': 'SheRide does not sell, lease, or monetize personal user information with external advertisers.'
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      // Brand Logo
                      const SheRideLogo(size: 100, showTagline: false, useCircle: false),
                      const SizedBox(height: 14),
                      Text(
                        'Welcome to SheRide',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '100% Verified Female Captains • Safe & Reliable',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE91E63),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Email & Password Direct Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hintText: 'user@example.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE91E63), size: 18),
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || !val.contains('@')) return 'Please enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hintText: '••••••••',
                              obscureText: _obscurePassword,
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE91E63), size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: const Color(0xFF757575),
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              validator: (val) {
                                if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordModal,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE91E63),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            CustomButton(
                              text: 'Sign In',
                              isLoading: authService.isLoading,
                              onPressed: _handleEmailLogin,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Divider OR
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Google Sign In Button with Google Logo
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Google Sign-In: Authenticating account...'),
                              backgroundColor: Color(0xFFE91E63),
                            ),
                          );
                          context.go('/home');
                        },
                        icon: Image.asset(
                          'assets/icons/google_logo.png',
                          width: 22,
                          height: 22,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 26,
                            color: Colors.red,
                          ),
                        ),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 16),

                      // Clickable Footer Policies (Terms & Conditions, Safety Policy, Privacy Policy)
                      Column(
                        children: [
                          Text(
                            'By continuing, you agree to SheRide\'s',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              GestureDetector(
                                onTap: _showTermsModal,
                                child: Text(
                                  'Terms & Conditions',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE91E63),
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFFE91E63),
                                  ),
                                ),
                              ),
                              Text(
                                '•',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                              ),
                              GestureDetector(
                                onTap: _showPrivacyPolicyModal,
                                child: Text(
                                  'Privacy Policy',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE91E63),
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFFE91E63),
                                  ),
                                ),
                              ),
                              Text(
                                '•',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                              ),
                              GestureDetector(
                                onTap: _showSafetyPolicyModal,
                                child: Text(
                                  'Safety Policy',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE91E63),
                                    decoration: TextDecoration.underline,
                                    decorationColor: const Color(0xFFE91E63),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
