import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../data/ride_service.dart';
import '../domain/ride_model.dart';

class RiderAssignedScreen extends StatefulWidget {
  final RideModel ride;

  const RiderAssignedScreen({
    super.key,
    required this.ride,
  });

  @override
  State<RiderAssignedScreen> createState() => _RiderAssignedScreenState();
}

class _RiderAssignedScreenState extends State<RiderAssignedScreen> {
  final _rideService = RideService();
  late RideModel _currentRide;
  StreamSubscription<RideModel?>? _rideSub;
  StreamSubscription<LocationPoint?>? _riderLocSub;
  LocationPoint? _liveRiderLocation;
  Map<String, dynamic>? _riderProfile;

  @override
  void initState() {
    super.initState();
    _currentRide = widget.ride;
    _listenToRideUpdates();
    _fetchRiderDetails();
    _listenToRiderLocation();
  }

  void _listenToRideUpdates() {
    _rideSub = _rideService.streamRide(widget.ride.rideId).listen((updated) {
      if (updated != null && mounted) {
        setState(() => _currentRide = updated);
        if (updated.status == 'started' || updated.status == 'in_progress') {
          context.go('/live-tracking', extra: {'ride': updated});
        } else if (updated.status == 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride was cancelled'), backgroundColor: AppColors.error),
          );
          context.go('/home');
        }
      }
    });
  }

  void _fetchRiderDetails() async {
    final riderId = _currentRide.riderId;
    if (riderId != null && riderId.isNotEmpty) {
      try {
        final snap = await FirebaseDatabase.instance.ref('riders/$riderId').get();
        if (snap.exists && snap.value != null && mounted) {
          setState(() {
            _riderProfile = Map<String, dynamic>.from(snap.value as Map);
          });
        }
      } catch (_) {}
    }
  }

  void _listenToRiderLocation() {
    final riderId = _currentRide.riderId;
    if (riderId != null && riderId.isNotEmpty) {
      _riderLocSub = _rideService.streamRiderLocation(riderId).listen((loc) {
        if (loc != null && mounted) {
          setState(() => _liveRiderLocation = loc);
        }
      });
    }
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _riderLocSub?.cancel();
    super.dispose();
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  String get _calculatedEta {
    if (_liveRiderLocation != null) {
      final dist = _calculateDistanceKm(
        _liveRiderLocation!.lat,
        _liveRiderLocation!.lng,
        _currentRide.pickup.lat,
        _currentRide.pickup.lng,
      );
      final minutes = ((dist / 25.0) * 60).clamp(1.0, 30.0).round();
      return '$minutes min';
    }
    return '${_currentRide.durationMin} min';
  }

  Future<void> _handleCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Ride?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this ride?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      await _rideService.cancelRide(_currentRide.rideId, cancelledBy: 'user');
      if (mounted) {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final riderName = _riderProfile?['name'] ?? _currentRide.riderName ?? 'Assigned Captain';
    final vehiclePlate = _riderProfile?['vehicleNumber'] ?? _currentRide.vehicleNumber ?? 'Verified Vehicle';
    final vehicleModel = _riderProfile?['vehicleModel'] ?? 'Captain Fleet';
    final photo = _riderProfile?['profileImageUrl'] ?? _currentRide.riderPhoto ?? '';
    final rating = (_riderProfile?['rating'] is num) ? (_riderProfile!['rating'] as num).toDouble() : (_currentRide.riderRating ?? 5.0);
    final totalRides = _riderProfile?['totalRides'] ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Navigation Row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
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
                          'Rider Assigned',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          'Your SheRide is on the way!',
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

              // Rider Card with Photo, ETA badge, Rating, Badges
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Photo with real ETA badge
                    Stack(
                      alignment: Alignment.topRight,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE91E63), width: 2.5),
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFFFCE4EC),
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty ? const Icon(Icons.person, size: 46, color: Color(0xFFE91E63)) : null,
                          ),
                        ),
                        Positioned(
                          right: -24,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_calculatedEta\naway',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Rider Name
                    Text(
                      riderName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.toStringAsFixed(1)} ($totalRides+ rides)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3 Badges (Verified, Women Rider, Trained)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBadge(
                          icon: Icons.check_circle_rounded,
                          label: 'Verified',
                          iconColor: const Color(0xFF4CAF50),
                          bgColor: const Color(0xFFE8F5E9),
                          textColor: const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(
                          icon: Icons.female_rounded,
                          label: 'Women Rider',
                          iconColor: const Color(0xFFE91E63),
                          bgColor: const Color(0xFFFCE4EC),
                          textColor: const Color(0xFFC2185B),
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(
                          icon: Icons.track_changes_rounded,
                          label: 'Trained',
                          iconColor: const Color(0xFFE91E63),
                          bgColor: const Color(0xFFFCE4EC),
                          textColor: const Color(0xFFC2185B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Vehicle Row Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFCE4EC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _currentRide.vehicleType == 'bike'
                            ? Icons.electric_scooter_rounded
                            : (_currentRide.vehicleType == 'auto' ? Icons.electric_rickshaw_rounded : Icons.directions_car_rounded),
                        color: const Color(0xFFE91E63),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleModel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF757575),
                            ),
                          ),
                          Text(
                            vehiclePlate,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            'Women Fleet • Verified',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final phone = _riderProfile?['phone'] ?? _currentRide.riderPhone ?? '';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(phone.isNotEmpty ? 'Calling $riderName ($phone)...' : 'Calling $riderName...'),
                            backgroundColor: const Color(0xFFE91E63),
                          ),
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFCE4EC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_outlined, color: Color(0xFFE91E63), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Real Arriving in ETA Box
              Column(
                children: [
                  Text(
                    'Arriving in',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _calculatedEta,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // OTP Section for Ride Start
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF8BBD9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ride PIN / OTP:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      _currentRide.otp,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFE91E63),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3 Action Buttons (Call, Message, Cancel)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionPill(
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onTap: () {
                      final phone = _riderProfile?['phone'] ?? _currentRide.riderPhone ?? '';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(phone.isNotEmpty ? 'Calling $phone...' : 'Calling captain...')),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionPill(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Message',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening secure chat with rider...')),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionPill(
                    icon: Icons.cancel_outlined,
                    label: 'Cancel',
                    onTap: _handleCancel,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Reassurance Safety Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF8BBD9).withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFF8BBD0),
                      child: Icon(Icons.shield_rounded, color: Color(0xFFE91E63), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You're in safe hands",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All our riders are women, verified\n& trained for your safety.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF757575),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF1A1A1A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
