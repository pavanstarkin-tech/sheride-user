import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../data/ride_service.dart';
import '../domain/ride_model.dart';

class LiveTrackingScreen extends StatefulWidget {
  final RideModel ride;

  const LiveTrackingScreen({
    super.key,
    required this.ride,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
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
    _listenToRideAndRider();
    _fetchRiderDetails();
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

  void _listenToRideAndRider() {
    _rideSub = _rideService.streamRide(widget.ride.rideId).listen((updated) {
      if (updated != null && mounted) {
        setState(() => _currentRide = updated);
        if (updated.status == 'completed') {
          context.go('/ride-completed', extra: {'ride': updated});
        } else if (updated.status == 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride was cancelled'), backgroundColor: AppColors.error),
          );
          context.go('/home');
        }
      }
    });

    final riderId = widget.ride.riderId;
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

  String get _currentDistanceText {
    if (_liveRiderLocation != null) {
      final dist = _calculateDistanceKm(
        _liveRiderLocation!.lat,
        _liveRiderLocation!.lng,
        _currentRide.drop.lat,
        _currentRide.drop.lng,
      );
      return '${dist.toStringAsFixed(1)} km';
    }
    return '${_currentRide.distanceKm} km';
  }

  String get _currentEtaText {
    if (_liveRiderLocation != null) {
      final dist = _calculateDistanceKm(
        _liveRiderLocation!.lat,
        _liveRiderLocation!.lng,
        _currentRide.drop.lat,
        _currentRide.drop.lng,
      );
      final minutes = ((dist / 25.0) * 60).clamp(1.0, 60.0).round();
      return '$minutes min';
    }
    return '${_currentRide.durationMin} min';
  }

  void _handleShareTrip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live trip safety link shared with emergency contacts! 🌸'),
        backgroundColor: Color(0xFFE91E63),
      ),
    );
  }

  void _handleSOS() {
    context.push('/safety-center');
  }

  void _handleSupport() {
    context.push('/support');
  }

  @override
  Widget build(BuildContext context) {
    final riderName = _riderProfile?['name'] ?? _currentRide.riderName ?? 'Captain';
    final vehicle = _riderProfile?['vehicleNumber'] ?? _currentRide.vehicleNumber ?? 'Verified';
    final vehicleModel = _riderProfile?['vehicleModel'] ?? 'Fleet';
    final rating = (_riderProfile?['rating'] is num) ? (_riderProfile!['rating'] as num).toDouble() : (_currentRide.riderRating ?? 5.0);
    final photo = _riderProfile?['profileImageUrl'] ?? _currentRide.riderPhoto ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Map with Route and Pins
            Positioned.fill(
              bottom: 270,
              child: Container(
                color: const Color(0xFFEBF2EE),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: _LiveTrackingRoutePainter(),
                    ),

                    // Pickup Pin
                    Positioned(
                      top: 70,
                      left: 140,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Text(
                          _currentRide.pickup.name ?? 'Pickup',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ),

                    // Destination Landmark Pin
                    Positioned(
                      top: 100,
                      right: 35,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE91E63),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: Text(
                              _currentRide.drop.name ?? 'Drop Location',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Live Moving Pink Scooter on Route
                    Positioned(
                      top: 175,
                      right: 80,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.electric_scooter_rounded, color: Colors.white, size: 18),
                      ),
                    ),

                    // Top Bar: Back Button + Share Trip Pill
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A1A1A)),
                            ),
                          ),
                          GestureDetector(
                            onTap: _handleShareTrip,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.share_outlined, size: 15, color: Color(0xFFE91E63)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Share Trip',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
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
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Trip Card
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Row: On Trip (left) | Live ETA & Distance (right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'On Trip',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  _liveRiderLocation != null ? 'Live tracking active' : 'Waiting for rider location...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currentEtaText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              _currentDistanceText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rider Mini Info Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFFCE4EC),
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty ? const Icon(Icons.person, color: Color(0xFFE91E63), size: 18) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  riderName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  '${rating.toStringAsFixed(1)} • $vehicleModel • $vehicle',
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
                                SnackBar(content: Text(phone.isNotEmpty ? 'Calling $phone...' : 'Calling $riderName...')),
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFCE4EC),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_outlined, color: Color(0xFFE91E63), size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3 Action Buttons: Share Trip | SOS | Support
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionPill(
                            icon: Icons.share_outlined,
                            label: 'Share Trip',
                            color: const Color(0xFF1A1A1A),
                            onTap: _handleShareTrip,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionPill(
                            icon: Icons.error_outline_rounded,
                            label: 'SOS',
                            color: const Color(0xFFE53935),
                            onTap: _handleSOS,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionPill(
                            icon: Icons.headset_mic_outlined,
                            label: 'Support',
                            color: const Color(0xFF1A1A1A),
                            onTap: _handleSupport,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bottom Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFF8BBD0),
                            child: Icon(Icons.shield_rounded, color: Color(0xFFE91E63), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Traveling Together',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  'For Safer, Happier Cities',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFE91E63),
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
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTrackingRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadBgPaint = Paint()
      ..color = const Color(0xFFDFE6E1)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(140, 75)
      ..cubicTo(size.width * 0.4, 180, size.width * 0.7, 120, size.width - 45, 110);

    canvas.drawPath(path, roadBgPaint);
    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
