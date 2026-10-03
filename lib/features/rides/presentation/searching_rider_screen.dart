import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../data/ride_service.dart';
import '../domain/ride_model.dart';
import '../../auth/presentation/widgets/she_ride_logo.dart';

class SearchingRiderScreen extends StatefulWidget {
  final RideModel ride;

  const SearchingRiderScreen({
    super.key,
    required this.ride,
  });

  @override
  State<SearchingRiderScreen> createState() => _SearchingRiderScreenState();
}

class _SearchingRiderScreenState extends State<SearchingRiderScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _rideService = RideService();
  StreamSubscription<RideModel?>? _rideSub;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _listenToRideStatus();
  }

  void _listenToRideStatus() {
    _rideSub = _rideService.streamRide(widget.ride.rideId).listen((updatedRide) {
      if (updatedRide != null && mounted) {
        if (updatedRide.status == 'accepted') {
          context.go('/rider-assigned', extra: {'ride': updatedRide});
        } else if (updatedRide.status == 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride was cancelled'), backgroundColor: AppColors.error),
          );
          context.go('/home');
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rideSub?.cancel();
    super.dispose();
  }

  Future<void> _handleCancelRide() async {
    setState(() => _isCancelling = true);
    await _rideService.cancelRide(widget.ride.rideId, cancelledBy: 'user');
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Radar Pulse Circles
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 200 + (_pulseController.value * 60),
                        height: 200 + (_pulseController.value * 60),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: (1.0 - _pulseController.value) * 0.2),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 140 + (_pulseController.value * 40),
                        height: 140 + (_pulseController.value * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight.withValues(alpha: (1.0 - _pulseController.value) * 0.35),
                        ),
                      );
                    },
                  ),
                  const SheRideLogo(size: 76, showTagline: false),
                ],
              ),
              const SizedBox(height: 36),

              // Status Heading
              const Text(
                'Connecting with Captain...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Searching for verified women riders near ${widget.ride.pickup.address}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Ride Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.ride.vehicleType == 'bike'
                            ? Icons.electric_scooter_rounded
                            : (widget.ride.vehicleType == 'auto' ? Icons.electric_rickshaw_rounded : Icons.directions_car_rounded),
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.ride.vehicleType.toUpperCase()} • ₹${widget.ride.fare.toInt()}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          Text(
                            'To: ${widget.ride.drop.address}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _handleCancelRide,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(
                          'Cancel Ride Request',
                          style: TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
