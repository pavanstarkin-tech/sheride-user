import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/location_service.dart';
import '../../rides/domain/ride_model.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final List<Map<String, dynamic>> _vehicleServices = [
    {
      'id': 'scooty',
      'name': 'Scooty',
      'tagline': 'Solo Swift',
      'image': 'assets/images/vehicles/scooty.png',
      'badge': '🌸 Best Value',
      'badgeColor': Color(0xFFE91E63),
      'baseRate': 'From ₹20',
      'capacity': 1,
    },
    {
      'id': 'electric_scooty',
      'name': 'Electric Scooty',
      'tagline': 'Silent Eco',
      'image': 'assets/images/vehicles/electric_scooty.png',
      'badge': '⚡ 100% EV',
      'badgeColor': Color(0xFF2E7D32),
      'baseRate': 'From ₹22',
      'capacity': 1,
    },
    {
      'id': 'bike',
      'name': 'Bike',
      'tagline': 'Fast Commute',
      'image': 'assets/images/vehicles/bike.png',
      'badge': '⚡ Express',
      'badgeColor': Color(0xFF1565C0),
      'baseRate': 'From ₹25',
      'capacity': 1,
    },
    {
      'id': 'priority_bike',
      'name': 'Priority Bike',
      'tagline': 'VIP Captain',
      'image': 'assets/images/vehicles/priority_bike.png',
      'badge': '⭐ VIP 5★',
      'badgeColor': Color(0xFFF57C00),
      'baseRate': 'From ₹35',
      'capacity': 1,
    },
    {
      'id': 'auto',
      'name': 'Auto',
      'tagline': 'Everyday Favorite',
      'image': 'assets/images/vehicles/auto.png',
      'badge': '🌱 Safe 3W',
      'badgeColor': Color(0xFF7B1FA2),
      'baseRate': 'From ₹30',
      'capacity': 3,
    },
    {
      'id': 'priority_auto',
      'name': 'Priority Auto',
      'tagline': 'Instant Pickup',
      'image': 'assets/images/vehicles/priority_auto.png',
      'badge': '⚡ Quick',
      'badgeColor': Color(0xFFC2185B),
      'baseRate': 'From ₹40',
      'capacity': 3,
    },
    {
      'id': 'premium_auto',
      'name': 'Premium Auto',
      'tagline': 'Luxury Cabin',
      'image': 'assets/images/vehicles/premium_auto.png',
      'badge': '✨ Executive',
      'badgeColor': Color(0xFFD81B60),
      'baseRate': 'From ₹45',
      'capacity': 3,
    },
    {
      'id': 'mini_car',
      'name': 'Mini Car',
      'tagline': 'AC Hatchback',
      'image': 'assets/images/vehicles/mini_car.png',
      'badge': '❄️ Chilled AC',
      'badgeColor': Color(0xFF00897B),
      'baseRate': 'From ₹65',
      'capacity': 4,
    },
    {
      'id': 'premium_car',
      'name': 'Premium Car',
      'tagline': 'Prime Sedan',
      'image': 'assets/images/vehicles/premium_car.png',
      'badge': '👑 Luxury',
      'badgeColor': Color(0xFF5E35B1),
      'baseRate': 'From ₹100',
      'capacity': 4,
    },
    {
      'id': 'ev_car',
      'name': 'EV Car',
      'tagline': '100% Green Sedan',
      'image': 'assets/images/vehicles/ev_car.png',
      'badge': '🌿 Clean EV',
      'badgeColor': Color(0xFF2E7D32),
      'baseRate': 'From ₹85',
      'capacity': 4,
    },
  ];

  void _onBookVehicle(String vehicleId) async {
    final locationService = LocationService();
    final pos = await locationService.getCurrentPosition() ?? locationService.lastKnownPosition;
    final lat = pos?.latitude ?? 17.3850;
    final lng = pos?.longitude ?? 78.4867;
    final currentAddr = locationService.currentAddress?.fullAddress ?? 'Current Location';

    if (mounted) {
      context.push('/destination-search', extra: {
        'pickup': LocationPoint(
          lat: lat,
          lng: lng,
          address: currentAddr,
          name: 'Current location',
        ),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Services',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose from 10 specialized vehicle categories',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF8BBD9)),
                    ),
                    child: const Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFFE91E63)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bento Style Grid (3 Cards Per Row)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.76,
                ),
                itemCount: _vehicleServices.length,
                itemBuilder: (context, idx) {
                  final v = _vehicleServices[idx];
                  return GestureDetector(
                    onTap: () => _onBookVehicle(v['id']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFFCE4EC)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Vehicle Image Artwork
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                v['image'] as String,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.electric_scooter_rounded, color: Color(0xFFE91E63), size: 26),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Name
                          Text(
                            v['name'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Price / Rate
                          const SizedBox(height: 2),
                          Text(
                            v['baseRate'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
