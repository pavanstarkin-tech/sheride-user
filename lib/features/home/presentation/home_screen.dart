import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/realtime_db_service.dart';
import '../../auth/domain/user_model.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../rides/domain/ride_model.dart';
import '../../rides/presentation/travel_screen.dart';
import '../../services/presentation/services_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  UserModel? _userProfile;
  final _locationService = LocationService();
  MapboxMap? _mapboxMap;
  
  double _currentLat = 17.3850;
  double _currentLng = 78.4867;
  String _localityName = 'Locating you...';
  String _cityName = 'Please wait';
  bool _isLocating = true;

  final List<Map<String, dynamic>> _recentPlaces = [
    {
      'title': 'Railway Station',
      'address': 'Main Junction & Platform Road',
      'distance': '2.4 km',
      'icon': 'train',
      'latOffset': 0.018,
      'lngOffset': 0.012,
    },
    {
      'title': 'Central Bus Stand',
      'address': 'RTC Complex & Terminal Hub',
      'distance': '3.1 km',
      'icon': 'bus',
      'latOffset': 0.024,
      'lngOffset': -0.010,
    },
    {
      'title': 'City Center Mall',
      'address': 'Commercial Street & Retail Arcade',
      'distance': '4.5 km',
      'icon': 'mall',
      'latOffset': -0.022,
      'lngOffset': 0.028,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initCurrentLocation();
  }

  Future<void> _loadUserProfile() async {
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid != null) {
      final db = RealtimeDbService();
      final profile = await db.getUserData(uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    }
  }

  Future<void> _initCurrentLocation() async {
    setState(() => _isLocating = true);
    
    // Check cached position first for instantaneous response
    final cached = _locationService.lastKnownPosition;
    if (cached != null) {
      _currentLat = cached.latitude;
      _currentLng = cached.longitude;
      _moveMapboxCamera(_currentLat, _currentLng);
    }

    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      });

      _moveMapboxCamera(_currentLat, _currentLng);

      final addr = await _locationService.reverseGeocode(_currentLat, _currentLng);
      if (mounted) {
        setState(() {
          _localityName = addr.locality.isNotEmpty ? addr.locality : 'Current Location';
          _cityName = addr.city.isNotEmpty ? '${addr.city}, ${addr.state}' : 'Your City';
          _isLocating = false;
          _updateRecentPlacesForUserCity(addr.locality, addr.city);
        });
      }
    } else if (mounted) {
      final addr = await _locationService.reverseGeocode(_currentLat, _currentLng);
      setState(() {
        _localityName = addr.locality.isNotEmpty ? addr.locality : 'Current Location';
        _cityName = addr.city.isNotEmpty ? '${addr.city}, ${addr.state}' : 'Your Location';
        _isLocating = false;
        _updateRecentPlacesForUserCity(addr.locality, addr.city);
      });
    }

    if (mounted) {
      final authService = context.read<AuthService>();
      final uid = authService.currentUser?.uid;
      if (uid != null) {
        _locationService.startLocationPublishing(uid);
      }
    }
  }

  void _updateRecentPlacesForUserCity(String locality, String city) {
    final cityName = city.isNotEmpty ? city : locality;
    setState(() {
      _recentPlaces[0] = {
        'title': '$cityName Railway Station',
        'address': 'Main Railway Junction & Platform Road, $cityName',
        'distance': '2.4 km',
        'icon': 'train',
        'latOffset': 0.018,
        'lngOffset': 0.012,
      };
      _recentPlaces[1] = {
        'title': '$cityName Central Bus Stand',
        'address': 'RTC Bus Terminal & Transit Hub, $cityName',
        'distance': '3.1 km',
        'icon': 'bus',
        'latOffset': 0.024,
        'lngOffset': -0.010,
      };
      _recentPlaces[2] = {
        'title': '$cityName City Center Mall',
        'address': 'Commercial Arcade & Shopping District, $cityName',
        'distance': '4.5 km',
        'icon': 'mall',
        'latOffset': -0.022,
        'lngOffset': 0.028,
      };
    });
  }

  void _moveMapboxCamera(double lat, double lng) {
    if (_mapboxMap != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 15.0,
      ));
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    try {
      mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
      _moveMapboxCamera(_currentLat, _currentLng);
    } catch (e) {
      debugPrint("Mapbox location settings note: $e");
    }
  }

  void _centerOnMyLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      });
      _moveMapboxCamera(pos.latitude, pos.longitude);
      final addr = await _locationService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _localityName = addr.locality;
          _cityName = '${addr.city}, ${addr.state}';
        });
      }
    }
  }

  @override
  void dispose() {
    _locationService.stopLocationPublishing();
    super.dispose();
  }

  void _navigateToSearch({String? query}) {
    context.push('/destination-search', extra: {
      'pickup': LocationPoint(
        lat: _currentLat,
        lng: _currentLng,
        address: _localityName.isNotEmpty && _localityName != 'Locating you...' 
            ? '$_localityName, $_cityName' 
            : 'Current Location',
        name: _localityName.isNotEmpty && _localityName != 'Locating you...' 
            ? _localityName 
            : 'Current location',
      ),
      'initialQuery': query,
    });
  }

  Future<void> _navigateToShortcutDestination(String label) async {
    // 1. Get fresh live GPS position
    double userLat = _currentLat;
    double userLng = _currentLng;
    String locality = _localityName;
    String city = _cityName;

    final livePos = await _locationService.getCurrentPosition();
    if (livePos != null) {
      userLat = livePos.latitude;
      userLng = livePos.longitude;
      _currentLat = userLat;
      _currentLng = userLng;
      final addr = await _locationService.reverseGeocode(userLat, userLng);
      locality = addr.locality.isNotEmpty ? addr.locality : 'Current Location';
      city = addr.city.isNotEmpty ? '${addr.city}, ${addr.state}' : '';
      if (mounted) {
        setState(() {
          _localityName = locality;
          _cityName = city;
        });
      }
    }

    final pickupPoint = LocationPoint(
      lat: userLat,
      lng: userLng,
      address: locality.isNotEmpty && locality != 'Locating you...'
          ? '$locality, $city'
          : 'Current GPS Location',
      name: locality.isNotEmpty && locality != 'Locating you...'
          ? locality
          : 'Current location',
    );

    // 2. Query real local place for shortcuts if available
    String searchQuery = '';
    if (label == 'Station') searchQuery = 'Railway Station';
    if (label == 'Bus Stand') searchQuery = 'Bus Station';
    if (label == 'Mall') searchQuery = 'Shopping Mall';
    if (label == 'Work') searchQuery = 'IT Park';

    LocationPoint? dropPoint;
    if (searchQuery.isNotEmpty) {
      try {
        final places = await _locationService.searchPlacesProximity(
          query: searchQuery,
          currentLat: userLat,
          currentLng: userLng,
        );
        if (places.isNotEmpty) {
          final top = places.first;
          dropPoint = LocationPoint(
            lat: top.lat,
            lng: top.lng,
            address: top.fullAddress,
            name: top.locality.isNotEmpty ? top.locality : top.fullAddress,
          );
        }
      } catch (e) {
        debugPrint("Proximity search notice: $e");
      }
    }

    // Fallback if network search returned nothing
    if (dropPoint == null) {
      double offsetLat = 0.02;
      double offsetLng = 0.015;
      String destName = label;
      String destAddress = '$label, $locality, $city';

      if (label == 'Home') {
        destName = 'Home';
        destAddress = 'Home, $locality, $city';
        offsetLat = 0.018;
        offsetLng = -0.014;
      } else if (label == 'Work') {
        destName = 'Work Place';
        destAddress = 'Commercial Tech Center, $city';
        offsetLat = 0.025;
        offsetLng = 0.020;
      } else if (label == 'Station') {
        destName = '$city Railway Station';
        destAddress = 'Central Railway Station & Junction, $city';
        offsetLat = 0.022;
        offsetLng = 0.015;
      } else if (label == 'Bus Stand') {
        destName = '$city Central Bus Terminal';
        destAddress = 'Main Bus Stand & RTC Complex, $city';
        offsetLat = 0.018;
        offsetLng = -0.012;
      } else if (label == 'Mall') {
        destName = '$city Shopping Mall';
        destAddress = 'City Center Mall & Retail Hub, $city';
        offsetLat = 0.024;
        offsetLng = 0.022;
      }

      dropPoint = LocationPoint(
        lat: userLat + offsetLat,
        lng: userLng + offsetLng,
        address: destAddress,
        name: destName,
      );
    }

    if (mounted) {
      context.push('/ride-selection', extra: {
        'pickup': pickupPoint,
        'drop': dropPoint,
      });
    }
  }

  Future<void> _navigateToDirectBooking(Map<String, dynamic> place) async {
    double userLat = _currentLat;
    double userLng = _currentLng;
    String locality = _localityName;
    String city = _cityName;

    final livePos = await _locationService.getCurrentPosition();
    if (livePos != null) {
      userLat = livePos.latitude;
      userLng = livePos.longitude;
      _currentLat = userLat;
      _currentLng = userLng;
      final addr = await _locationService.reverseGeocode(userLat, userLng);
      locality = addr.locality.isNotEmpty ? addr.locality : 'Current Location';
      city = addr.city.isNotEmpty ? '${addr.city}, ${addr.state}' : '';
      if (mounted) {
        setState(() {
          _localityName = locality;
          _cityName = city;
        });
      }
    }

    final offsetLat = (place['latOffset'] as double? ?? 0.015);
    final offsetLng = (place['lngOffset'] as double? ?? 0.012);
    final dropLat = userLat + offsetLat;
    final dropLng = userLng + offsetLng;

    if (mounted) {
      context.push('/ride-selection', extra: {
        'pickup': LocationPoint(
          lat: userLat,
          lng: userLng,
          address: locality.isNotEmpty && locality != 'Locating you...'
              ? '$locality, $city'
              : 'Current GPS Location',
          name: locality.isNotEmpty && locality != 'Locating you...'
              ? locality
              : 'Current location',
        ),
        'drop': LocationPoint(
          lat: dropLat,
          lng: dropLng,
          address: (place['address'] as String?) ?? 'Destination',
          name: (place['title'] as String?) ?? 'Destination',
        ),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          _buildHomeBody(),
          const ServicesScreen(),
          const TravelScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeBody() {
    final photo = _userProfile?.profileImageUrl.isNotEmpty == true
        ? _userProfile!.profileImageUrl
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120';

    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.48; // Covers bottom 48% and completely hides Mapbox watermark

    return Stack(
      children: [
        // Mapbox Native Map Widget
        Positioned.fill(
          bottom: sheetHeight - 24,
          child: MapWidget(
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_currentLng, _currentLat)),
              zoom: 14.8,
            ),
            styleUri: ApiConstants.mapboxStyleUrl,
            onMapCreated: _onMapCreated,
          ),
        ),

        // Top White Fade Gradient Background (Ensures Notification & Header Clarity)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 135,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.98),
                  Colors.white.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // Top Floating Header Bar
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFFCE4EC)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar + Real Address Locality
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedNavIndex = 3),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE91E63), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFF8BBD0),
                            backgroundImage: NetworkImage(photo),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Color(0xFFE91E63)),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    _isLocating ? 'Locating you...' : _localityName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _cityName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF757575),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Notifications Bell
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF8BBD9)),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFFE91E63),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Center Location FAB Button (positioned cleanly above the sheet)
        Positioned(
          bottom: sheetHeight + 12,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: _centerOnMyLocation,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFE91E63),
            elevation: 4,
            child: const Icon(Icons.my_location_rounded, size: 22),
          ),
        ),

        // Bottom Booking Sheet (Increased Height with Directly Clickable Recently Visited Places)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: sheetHeight,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sheet Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Search Bar
                GestureDetector(
                  onTap: () => _navigateToSearch(),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF757575), size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Where are you going?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE91E63),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Destinations Row (Home, Work, Station, Bus Stand, Mall)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickActionItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      onTap: () => _navigateToShortcutDestination('Home'),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.work_rounded,
                      label: 'Work',
                      onTap: () => _navigateToShortcutDestination('Work'),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.train_rounded,
                      label: 'Station',
                      onTap: () => _navigateToShortcutDestination('Station'),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.directions_bus_rounded,
                      label: 'Bus Stand',
                      onTap: () => _navigateToShortcutDestination('Bus Stand'),
                    ),
                    _buildQuickActionItem(
                      icon: Icons.local_mall_rounded,
                      label: 'Mall',
                      onTap: () => _navigateToShortcutDestination('Mall'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Recently Visited Places Section (Direct One-Click Navigation to Vehicle Selection!)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recently Visited',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'Instant Book',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Recent Places List Cards (Tapping directly opens Vehicle Selection!)
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _recentPlaces.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
                    itemBuilder: (context, idx) {
                      final p = _recentPlaces[idx];
                      IconData icon = Icons.place_rounded;
                      if (p['icon'] == 'train') icon = Icons.train_rounded;
                      if (p['icon'] == 'bus') icon = Icons.directions_bus_rounded;
                      if (p['icon'] == 'mall') icon = Icons.shopping_bag_rounded;

                      return InkWell(
                        onTap: () => _navigateToDirectBooking(p),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: const Color(0xFFE91E63), size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p['title'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    Text(
                                      p['address'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: const Color(0xFF757575),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  p['distance'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFE91E63)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF8BBD9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFE91E63), size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (idx) => setState(() => _selectedNavIndex = idx),
        selectedItemColor: const Color(0xFFE91E63),
        unselectedItemColor: const Color(0xFF757575),
        selectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w800),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: _selectedNavIndex == 0
                  ? BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: const Icon(Icons.electric_scooter_rounded, size: 22),
            ),
            label: 'Ride',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: _selectedNavIndex == 1
                  ? BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: const Icon(Icons.grid_view_rounded, size: 22),
            ),
            label: 'All Services',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: _selectedNavIndex == 2
                  ? BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: const Icon(Icons.alt_route_rounded, size: 22),
            ),
            label: 'Travel',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: _selectedNavIndex == 3
                  ? BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: const Icon(Icons.person_outline_rounded, size: 22),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
