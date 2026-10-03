import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _onSearchChanged(widget.initialQuery!);
    } else {
      _loadCurrentGpsLocation();
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
            const SizedBox(height: 4),

            // Content: Results or Quick Nearby Search Suggestions
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

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.place_rounded, color: Color(0xFF424242), size: 20),
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
    final quickPresets = [
      {'title': 'Railway Station', 'icon': Icons.train_rounded, 'desc': 'Nearest railway junction & station'},
      {'title': 'Bus Terminal / RTC', 'icon': Icons.directions_bus_rounded, 'desc': 'Central bus station & transit hub'},
      {'title': 'Shopping Mall', 'icon': Icons.shopping_bag_rounded, 'desc': 'City malls, shopping centers & multiplexes'},
      {'title': 'Metro Station', 'icon': Icons.subway_rounded, 'desc': 'Nearest metro entrance'},
      {'title': 'Airport / Air Terminal', 'icon': Icons.flight_takeoff_rounded, 'desc': 'Domestic / International airport'},
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(
          'Quick Search Destinations',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 10),
        ...quickPresets.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(p['icon'] as IconData, color: const Color(0xFF424242), size: 20),
              ),
              title: Text(
                p['title'] as String,
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                p['desc'] as String,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF757575)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFBDBDBD)),
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
