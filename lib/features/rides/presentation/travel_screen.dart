import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../data/ride_service.dart';
import '../domain/ride_model.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rideService = RideService();
  bool _isLoading = false;
  List<RideModel> _rides = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid ?? 'guest';
    final list = await _rideService.getUserRides(uid);
    if (mounted) {
      setState(() {
        _rides = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRides = _rides.where((r) => r.status != 'completed' && r.status != 'cancelled').toList();
    final pastRides = _rides.where((r) => r.status == 'completed' || r.status == 'cancelled').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Travel & Activity',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadRides,
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFFE91E63)),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFE91E63),
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF757575),
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Active Rides'),
                  Tab(text: 'Past Trips'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActiveRidesTab(activeRides),
                        _buildPastRidesTab(pastRides),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRidesTab(List<RideModel> activeRides) {
    if (activeRides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.electric_scooter_rounded, size: 44, color: Color(0xFFE91E63)),
              ),
              const SizedBox(height: 20),
              Text(
                'No Active Rides Right Now',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Book a ride from Home or Services to track your SheRide Captain live on the map.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF757575),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  'Book a Ride Now',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: activeRides.length,
      itemBuilder: (context, index) {
        final ride = activeRides[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E63).withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF8BBD9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'STATUS: ${ride.status.toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                  ),
                  if (ride.otp.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'START OTP: ${ride.otp}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.pickup.address,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.drop.address,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF5F5F5)),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${ride.fare.toInt()}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/live-tracking', extra: {'ride': ride}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Track Live Map'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPastRidesTab(List<RideModel> pastRides) {
    if (pastRides.isEmpty) {
      final demoPast = [
        RideModel(
          rideId: 'ride_p1',
          userId: 'user',
          pickup: const LocationPoint(lat: 17.3850, lng: 78.4867, address: 'Rajendranagar Ring Road'),
          drop: const LocationPoint(lat: 17.3980, lng: 78.4980, address: 'Rajendranagar Railway Station'),
          vehicleType: 'electric_scooty',
          fare: 48,
          distanceKm: 3.2,
          durationMin: 11,
          status: 'completed',
          otp: '4829',
          riderName: 'Sunita Sharma',
          riderRating: 4.9,
          createdAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        ),
        RideModel(
          rideId: 'ride_p2',
          userId: 'user',
          pickup: const LocationPoint(lat: 17.3850, lng: 78.4867, address: 'Commercial Hub'),
          drop: const LocationPoint(lat: 17.4100, lng: 78.5200, address: 'City Central Mall'),
          vehicleType: 'auto',
          fare: 76,
          distanceKm: 5.4,
          durationMin: 18,
          status: 'completed',
          otp: '9182',
          riderName: 'Pooja Reddy',
          riderRating: 5.0,
          createdAt: DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch,
        ),
      ];

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: demoPast.length,
        itemBuilder: (context, index) => _buildPastRideCard(demoPast[index]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: pastRides.length,
      itemBuilder: (context, index) => _buildPastRideCard(pastRides[index]),
    );
  }

  Widget _buildPastRideCard(RideModel ride) {
    final date = DateTime.fromMillisecondsSinceEpoch(ride.createdAt);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final isCompleted = ride.status.toLowerCase() == 'completed';

    return InkWell(
      onTap: () => context.push('/trip-details', extra: {'ride': ride}),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.electric_scooter_rounded, size: 18, color: Color(0xFFE91E63)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.vehicleType.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF757575)),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '₹${ride.fare.toInt()}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.pickup.address,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFE91E63)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.drop.address,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF5F5F5)),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Captain ${ride.riderName ?? "Sunita Sharma"}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF424242)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Trip Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFE91E63)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
