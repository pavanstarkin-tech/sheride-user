import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/location_service.dart';
import '../domain/ride_model.dart';

class DestinationSearchScreen extends StatefulWidget {
  final LocationPoint? initialPickup;
  final String? initialQuery;

  const DestinationSearchScreen({
    super.key,
    this.initialPickup,
    this.initialQuery,
  });

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _searchController = TextEditingController();
  final _locationService = LocationService();

  late LocationPoint _pickupLocation;
  List<AddressInfo> _searchResults = [];
  bool _isLoading = false;
  bool _showAllNearby = false;
  List<Map<String, dynamic>> _recentSearches = [];

  // Curated Popular Visited Places with Exact Coordinates for Mapbox Static Image Generation
  final List<Map<String, dynamic>> _curatedNearbyPlaces = [
    {
      'title': 'Rajahmundry Railway Station',
      'address': 'Railway Station Road, Innespeta, Rajahmundry, Andhra Pradesh',
      'lat': 17.0005,
      'lng': 81.7774,
      'category': 'Railway Station',
      'zoom': 15.2,
    },
    {
      'title': 'RTC Complex',
      'address': 'APSRTC Bus Station, Morampudi Road, Rajahmundry, Andhra Pradesh',
      'lat': 16.9935,
      'lng': 81.7820,
      'category': 'Bus Station',
      'zoom': 15.5,
    },
    {
      'title': 'Prasaditya Mall',
      'address': 'Syamala Theatre Road, Danavaipeta, Rajahmundry, Andhra Pradesh',
      'lat': 17.0040,
      'lng': 81.7860,
      'category': 'Shopping Mall',
      'zoom': 15.5,
    },
    {
      'title': 'Lalacheruvu',
      'address': 'Lalacheruvu Junction, NH16, Rajahmundry, Andhra Pradesh',
      'lat': 17.0220,
      'lng': 81.8120,
      'category': 'Junction',
      'zoom': 15.0,
    },
    {
      'title': 'Kotipalli Bus Stand Road',
      'address': 'Kotipalli Bus Stand Road, Main Bazaar, Rajahmundry, Andhra Pradesh',
      'lat': 16.9850,
      'lng': 81.7720,
      'category': 'Bus Stand',
      'zoom': 15.5,
    },
    {
      'title': 'Gokavaram Bus stand',
      'address': 'Gokavaram Bus Stand, Aryapuram, Rajahmundry, Andhra Pradesh',
      'lat': 17.0110,
      'lng': 81.7890,
      'category': 'Bus Stand',
      'zoom': 15.5,
    },
    {
      'title': 'Godavari Pushkar Ghat',
      'address': 'Pushkar Ghat, Godavari Bund, Rajahmundry, Andhra Pradesh',
      'lat': 16.9880,
      'lng': 81.7680,
      'category': 'Landmark / Ghat',
      'zoom': 15.2,
    },
    {
      'title': 'Danavaipeta Main Road',
      'address': 'Danavaipeta, Rajahmundry, Andhra Pradesh',
      'lat': 16.9980,
      'lng': 81.7800,
      'category': 'Commercial Hub',
      'zoom': 15.2,
    },
    {
      'title': 'Kadiyam Flower Nurseries',
      'address': 'Kadiyam Nursery Road, Rajahmundry, Andhra Pradesh',
      'lat': 16.9150,
      'lng': 81.8320,
      'category': 'Tourist Spot',
      'zoom': 14.8,
    },
  ];

  @override
  void initState() {
    super.initState();
    final cached = _locationService.lastKnownPosition;
    final cachedAddr = _locationService.currentAddress;
    _pickupLocation = widget.initialPickup ??
        (cached != null
            ? LocationPoint(
                lat: cached.latitude,
                lng: cached.longitude,
                address: cachedAddr?.fullAddress ?? 'Current Location',
                name: cachedAddr?.locality ?? 'Current location',
              )
            : const LocationPoint(
                lat: 17.3850,
                lng: 78.4867,
                address: 'Current Location',
                name: 'Current location',
              ));

    _loadRecentSearches();

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _onSearchChanged(widget.initialQuery!);
    } else {
      _loadCurrentGpsLocation();
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sheride_recent_destinations');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _recentSearches = decoded.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      debugPrint("Load recent searches error: $e");
    }
  }

  Future<void> _saveRecentSearch(String title, String address, double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final item = {
        'title': title,
        'address': address,
        'lat': lat,
        'lng': lng,
        'time': DateTime.now().millisecondsSinceEpoch,
      };

      // Deduplicate & keep top 6
      List<Map<String, dynamic>> updated = List.from(_recentSearches);
      updated.removeWhere((x) => x['title'] == title || (x['lat'] == lat && x['lng'] == lng));
      updated.insert(0, item);
      if (updated.length > 6) {
        updated = updated.sublist(0, 6);
      }

      await prefs.setString('sheride_recent_destinations', jsonEncode(updated));
    } catch (e) {
      debugPrint("Save recent search error: $e");
    }
  }

  Future<void> _loadCurrentGpsLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      final addr = await _locationService.reverseGeocode(pos.latitude, pos.longitude);
      setState(() {
        _pickupLocation = LocationPoint(
          lat: pos.latitude,
          lng: pos.longitude,
          address: addr.fullAddress,
          name: addr.locality,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Generate Mapbox Static Image URL for given coordinates
  String _getMapboxImageUrl(double lat, double lng, {double zoom = 15.0, int width = 300, int height = 200}) {
    // Official Mapbox Static Images API endpoint with high-res @2x tile and custom branded pin
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/pin-s+e91e63($lng,$lat)/$lng,$lat,$zoom,0/${width}x$height@2x?access_token=${ApiConstants.mapboxAccessToken}';
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final results = await _locationService.searchPlacesProximity(
      query: query,
      currentLat: _pickupLocation.lat,
      currentLng: _pickupLocation.lng,
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _onSelectDropLocation(String title, String address, double lat, double lng) {
    _saveRecentSearch(title, address, lat, lng);

    final dropLocation = LocationPoint(
      lat: lat,
      lng: lng,
      address: address,
      name: title,
    );

    context.push('/ride-selection', extra: {
      'pickup': _pickupLocation,
      'drop': dropLocation,
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Search Bar Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Color(0xFF757575), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: widget.initialQuery == null,
                              onChanged: _onSearchChanged,
                              cursorColor: const Color(0xFF1A1A1A),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A1A),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search destination or railway station...',
                                hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13.5),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                isDense: true,
                              ),
                            ),
                          ),
                          if (hasSearchQuery)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                              child: const Icon(Icons.close_rounded, color: Color(0xFF757575), size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Content: Search Results or Nearby Places & Recent Visits with Mapbox Images
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                  : hasSearchQuery
                      ? _buildSearchResultsList()
                      : _buildNearbySuggestions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_rounded, size: 48, color: Color(0xFF9E9E9E)),
              const SizedBox(height: 12),
              Text(
                'No exact places found',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Try searching with nearby landmark or area name.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF757575)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, idx) {
        final res = _searchResults[idx];
        final dist = _locationService.calculateDistanceKm(
          _pickupLocation.lat,
          _pickupLocation.lng,
          res.lat,
          res.lng,
        );

        final mapboxThumb = _getMapboxImageUrl(res.lat, res.lng, zoom: 15.0, width: 120, height: 120);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Image.network(
                mapboxThumb,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Icon(Icons.place_rounded, color: Color(0xFFE91E63), size: 22),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF5F5F5),
                    child: const Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE91E63)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  res.locality,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                '${dist.toStringAsFixed(1)} km',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          subtitle: Text(
            res.fullAddress,
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF757575)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _onSelectDropLocation(res.locality, res.fullAddress, res.lat, res.lng),
        );
      },
    );
  }

  Widget _buildNearbySuggestions() {
    final displayedNearby = _showAllNearby ? _curatedNearbyPlaces : _curatedNearbyPlaces.take(6).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Nearby Places Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Places',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _showAllNearby = !_showAllNearby);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  _showAllNearby ? 'Show Less' : 'See All',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE91E63),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. 3-Column Grid of Nearby Places Cards with Mapbox Images
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedNearby.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            final place = displayedNearby[index];
            final title = place['title'] as String;
            final address = place['address'] as String;
            final lat = place['lat'] as double;
            final lng = place['lng'] as double;
            final zoom = (place['zoom'] as double?) ?? 15.0;

            final imageUrl = _getMapboxImageUrl(lat, lng, zoom: zoom, width: 240, height: 160);

            return InkWell(
              onTap: () => _onSelectDropLocation(title, address, lat, lng),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Mapbox Static Image Preview
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEFEFEF)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFFCE4EC),
                            child: const Center(
                              child: Icon(Icons.location_city_rounded, color: Color(0xFFE91E63), size: 26),
                            ),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF5F5F5),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFE91E63),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Place Name Label
                  SizedBox(
                    height: 30,
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // 3. Recently Visited Places Section (if available)
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recently Visited',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('sheride_recent_destinations');
                  setState(() => _recentSearches = []);
                },
                child: Text(
                  'Clear',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF757575),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal scroll of recently visited places with Mapbox image
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentSearches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final r = _recentSearches[idx];
                final rTitle = r['title'] as String? ?? 'Place';
                final rAddress = r['address'] as String? ?? '';
                final rLat = (r['lat'] as num?)?.toDouble() ?? 17.0005;
                final rLng = (r['lng'] as num?)?.toDouble() ?? 81.7774;
                final rImage = _getMapboxImageUrl(rLat, rLng, zoom: 15.0, width: 160, height: 120);

                return InkWell(
                  onTap: () => _onSelectDropLocation(rTitle, rAddress, rLat, rLng),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: Image.network(
                              rImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFFCE4EC),
                                child: const Icon(Icons.history_rounded, color: Color(0xFFE91E63), size: 20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                rTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF757575),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 4. Quick Transit Hub Categories
        Text(
          'Explore Transit & Hubs',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),

        ...[
          {'title': 'Railway Station', 'icon': Icons.train_rounded, 'desc': 'Nearest railway junction & station'},
          {'title': 'Bus Terminal / RTC', 'icon': Icons.directions_bus_rounded, 'desc': 'Central bus station & transit hub'},
          {'title': 'Shopping Mall', 'icon': Icons.shopping_bag_rounded, 'desc': 'City malls, shopping centers & multiplexes'},
          {'title': 'Airport / Air Terminal', 'icon': Icons.flight_takeoff_rounded, 'desc': 'Domestic / International airport'},
        ].map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(p['icon'] as IconData, color: const Color(0xFF424242), size: 18),
              ),
              title: Text(
                p['title'] as String,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                p['desc'] as String,
                style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF757575)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFBDBDBD)),
              onTap: () {
                _searchController.text = p['title'] as String;
                _onSearchChanged(p['title'] as String);
              },
            ),
          );
        }),
      ],
    );
  }
}

