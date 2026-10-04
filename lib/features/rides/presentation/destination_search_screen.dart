import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../data/destination_preload_service.dart';
import '../data/ride_history_service.dart';
import '../domain/ride_model.dart';
import 'widgets/place_card_image_slider.dart';

/// Mapbox Search Box POI Photo Component
/// Flow:
/// 1. Place name + proximity -> Mapbox Search Box API (/suggest)
/// 2. Extract Mapbox POI mapbox_id
/// 3. Retrieve place details with attribute_sets=photos (/retrieve)
/// 4. Extract photo URL from metadata.photos
/// 5. Display the actual place image (with graceful Mapbox Static Map fallback)
class MapboxPoiImage extends StatefulWidget {
  final String placeName;
  final double lat;
  final double lng;
  final double zoom;
  final String? initialPhotoUrl;
  final BoxFit fit;

  const MapboxPoiImage({
    super.key,
    required this.placeName,
    required this.lat,
    required this.lng,
    this.zoom = 15.0,
    this.initialPhotoUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<MapboxPoiImage> createState() => _MapboxPoiImageState();
}

class _MapboxPoiImageState extends State<MapboxPoiImage> {
  static final Map<String, String?> _photoCache = {};
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.initialPhotoUrl;
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      _resolveRealPlacePhoto();
    }
  }

  @override
  void didUpdateWidget(covariant MapboxPoiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeName != widget.placeName || oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _photoUrl = widget.initialPhotoUrl;
      if (_photoUrl == null || _photoUrl!.isEmpty) {
        _resolveRealPlacePhoto();
      }
    }
  }

  // Multi-tier Real Place Photo Resolution Pipeline
  Future<void> _resolveRealPlacePhoto() async {
    final cleanName = widget.placeName.trim();
    final cacheKey = '${cleanName.toLowerCase()}_${widget.lat.toStringAsFixed(3)}_${widget.lng.toStringAsFixed(3)}';
    if (_photoCache.containsKey(cacheKey) && _photoCache[cacheKey] != null) {
      if (mounted) {
        setState(() => _photoUrl = _photoCache[cacheKey]);
      }
      return;
    }

    // Tier 1: Mapbox Search Box API Photo Metadata
    try {
      final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      final suggestUrl = Uri.parse(
        'https://api.mapbox.com/search/searchbox/v1/suggest'
        '?q=${Uri.encodeComponent(cleanName)}&language=en&proximity=${widget.lng},${widget.lat}&types=poi&limit=1'
        '&session_token=$sessionToken&access_token=${ApiConstants.mapboxAccessToken}',
      );
      final sResp = await http.get(suggestUrl).timeout(const Duration(seconds: 3));
      if (sResp.statusCode == 200) {
        final sData = jsonDecode(sResp.body);
        final suggestions = sData['suggestions'] as List<dynamic>? ?? [];
        if (suggestions.isNotEmpty) {
          final mapboxId = suggestions.first['mapbox_id'] as String? ?? '';
          if (mapboxId.isNotEmpty) {
            final retrieveUrl = Uri.parse(
              'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
              '?attribute_sets=photos&session_token=$sessionToken&access_token=${ApiConstants.mapboxAccessToken}',
            );
            final rResp = await http.get(retrieveUrl).timeout(const Duration(seconds: 3));
            if (rResp.statusCode == 200) {
              final rData = jsonDecode(rResp.body);
              final feats = rData['features'] as List<dynamic>? ?? [];
              if (feats.isNotEmpty) {
                final f = feats.first;
                final photos = f['properties']?['metadata']?['photos'] as List<dynamic>? ??
                    f['properties']?['photos'] as List<dynamic>?;
                if (photos != null && photos.isNotEmpty) {
                  final firstPhoto = photos.first;
                  String? resolvedUrl;
                  if (firstPhoto is Map<String, dynamic>) {
                    resolvedUrl = firstPhoto['url'] as String? ??
                        firstPhoto['urls']?['regular'] as String? ??
                        firstPhoto['urls']?['small'] as String?;
                  } else if (firstPhoto is String) {
                    resolvedUrl = firstPhoto;
                  }
                  if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                    _photoCache[cacheKey] = resolvedUrl;
                    if (mounted) setState(() => _photoUrl = resolvedUrl);
                    return;
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Tier 2: Real Landmark Photo from Wikipedia / Wikimedia by Title
    try {
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=search'
        '&gsrsearch=${Uri.encodeComponent(cleanName)}&prop=pageimages&pithumbsize=600&format=json',
      );
      final wResp = await http.get(wikiUrl, headers: {'User-Agent': 'SheRideApp/1.0 (contact@sheride.app)'}).timeout(const Duration(seconds: 3));
      if (wResp.statusCode == 200) {
        final wData = jsonDecode(wResp.body);
        final pages = wData['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          for (final p in pages.values) {
            final thumb = p['thumbnail']?['source'] as String?;
            if (thumb != null && thumb.isNotEmpty) {
              _photoCache[cacheKey] = thumb;
              if (mounted) setState(() => _photoUrl = thumb);
              return;
            }
          }
        }
      }
    } catch (_) {}

    // Tier 3: Real Landmark Photo from Wikimedia Geosearch by Coordinates
    try {
      final geoUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=geosearch'
        '&ggscoord=${widget.lat}|${widget.lng}&ggsradius=15000&ggslimit=5&prop=pageimages&pithumbsize=600&format=json',
      );
      final gResp = await http.get(geoUrl, headers: {'User-Agent': 'SheRideApp/1.0 (contact@sheride.app)'}).timeout(const Duration(seconds: 3));
      if (gResp.statusCode == 200) {
        final gData = jsonDecode(gResp.body);
        final pages = gData['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          for (final p in pages.values) {
            final thumb = p['thumbnail']?['source'] as String?;
            if (thumb != null && thumb.isNotEmpty) {
              _photoCache[cacheKey] = thumb;
              if (mounted) setState(() => _photoUrl = thumb);
              return;
            }
          }
        }
      }
    } catch (_) {}

    // Tier 4: Curated High-Definition Authentic Place Category Photography
    final categoryPhoto = _getCategoryRealPhoto(cleanName);
    _photoCache[cacheKey] = categoryPhoto;
    if (mounted) {
      setState(() => _photoUrl = categoryPhoto);
    }
  }

  // Real photographs for popular Indian place categories
  String _getCategoryRealPhoto(String name) {
    final n = name.toLowerCase();
    if (n.contains('railway') || n.contains('station') || n.contains('train')) {
      return 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('bus') || n.contains('stand') || n.contains('complex') || n.contains('terminal')) {
      return 'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('mall') || n.contains('shopping') || n.contains('center') || n.contains('centre')) {
      return 'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('hospital') || n.contains('clinic') || n.contains('care') || n.contains('medical')) {
      return 'https://images.unsplash.com/photo-1587351021759-3e566b6af7cc?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('temple') || n.contains('mandir') || n.contains('church') || n.contains('masjid')) {
      return 'https://images.unsplash.com/photo-1561361513-2d000a50f0dc?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('college') || n.contains('school') || n.contains('university') || n.contains('campus')) {
      return 'https://images.unsplash.com/photo-1562774053-701939374585?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('airport') || n.contains('flight')) {
      return 'https://images.unsplash.com/photo-1530521954074-e64f6810b32d?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('hotel') || n.contains('resort') || n.contains('stay') || n.contains('inn')) {
      return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&auto=format&fit=crop&q=80';
    } else if (n.contains('park') || n.contains('garden') || n.contains('river') || n.contains('lake') || n.contains('ghat')) {
      return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1477959858617-67f30bc75b82?w=600&auto=format&fit=crop&q=80';
  }

  @override
  Widget build(BuildContext context) {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return Image.network(
        _photoUrl!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildFallbackPhoto(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoading();
        },
      );
    }

    return _buildFallbackPhoto();
  }

  Widget _buildFallbackPhoto() {
    final fallbackUrl = _getCategoryRealPhoto(widget.placeName);
    return Image.network(
      fallbackUrl,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFCE4EC),
        child: const Center(
          child: Icon(Icons.location_city_rounded, color: Color(0xFFE91E63), size: 26),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildLoading();
      },
    );
  }

  Widget _buildLoading() {
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
  }
}

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
  final _rideHistoryService = RideHistoryService();
  final _storageService = StorageService();

  late LocationPoint _pickupLocation;
  List<AddressInfo> _searchResults = [];
  bool _isLoading = false;
  bool _isLoadingNearby = true;
  bool _showAllNearby = false;

  List<DynamicPlaceItem> _dynamicPlaces = [];
  List<DynamicPlaceItem> _recentSearches = [];

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
                lat: 17.0005,
                lng: 81.7774,
                address: 'Current Location',
                name: 'Current location',
              ));

    // Instant Zero-Delay Load from Background Preload Service
    final preload = DestinationPreloadService();
    if (preload.nearbyPlaces.isNotEmpty) {
      _dynamicPlaces = List.from(preload.nearbyPlaces);
      _recentSearches = List.from(preload.recentSearches);
      _isLoadingNearby = false;
    } else {
      _isLoadingNearby = true;
      preload.startBackgroundPreload(lat: _pickupLocation.lat, lng: _pickupLocation.lng);
    }
    preload.addListener(_onPreloadUpdated);

    _initData();

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _onSearchChanged(widget.initialQuery!);
    }
  }

  void _onPreloadUpdated() {
    if (mounted) {
      final preload = DestinationPreloadService();
      if (preload.nearbyPlaces.isNotEmpty) {
        setState(() {
          _dynamicPlaces = List.from(preload.nearbyPlaces);
          _recentSearches = List.from(preload.recentSearches);
          _isLoadingNearby = false;
        });
      }
    }
  }

  Future<void> _initData() async {
    await _loadCurrentGpsLocation();
    await _loadDynamicPlaces();
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

  // Dynamically load places based on 1) Past Rides, 2) Search History, and 3) Live Mapbox Nearby POIs around GPS
  Future<void> _loadDynamicPlaces() async {
    if (!mounted) return;
    setState(() => _isLoadingNearby = true);

    final List<DynamicPlaceItem> combined = [];
    final Set<String> seenNames = {};

    // 1. Fetch User Past Rides Destinations from Firebase / Local History
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? _storageService.getUserId() ?? '';
      if (uid.isNotEmpty) {
        final pastRides = await _rideHistoryService.getRideHistory(uid);
        for (final r in pastRides) {
          if (r.drop.address.isNotEmpty && !seenNames.contains(r.drop.name?.toLowerCase())) {
            final name = r.drop.name?.isNotEmpty == true ? r.drop.name! : r.drop.address.split(',').first;
            seenNames.add(name.toLowerCase());
            final dist = _locationService.calculateDistanceKm(
              _pickupLocation.lat,
              _pickupLocation.lng,
              r.drop.lat,
              r.drop.lng,
            );
            combined.add(DynamicPlaceItem(
              title: name,
              address: r.drop.address,
              lat: r.drop.lat,
              lng: r.drop.lng,
              tag: 'Visited',
              distanceKm: dist,
              zoom: 15.2,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Load past rides error: $e");
    }

    // 2. Fetch User Recent Searches from SharedPreferences
    final List<DynamicPlaceItem> recentsList = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sheride_recent_destinations');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        for (final item in decoded) {
          final t = (item['title'] as String?) ?? '';
          final a = (item['address'] as String?) ?? '';
          final lat = (item['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (item['lng'] as num?)?.toDouble() ?? 0.0;
          if (lat != 0 && lng != 0 && t.isNotEmpty) {
            final dist = _locationService.calculateDistanceKm(
              _pickupLocation.lat,
              _pickupLocation.lng,
              lat,
              lng,
            );
            final placeItem = DynamicPlaceItem(
              title: t,
              address: a,
              lat: lat,
              lng: lng,
              tag: 'Recent',
              distanceKm: dist,
              zoom: 15.0,
            );
            recentsList.add(placeItem);
            if (!seenNames.contains(t.toLowerCase())) {
              seenNames.add(t.toLowerCase());
              combined.add(placeItem);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Load recent searches error: $e");
    }

    // 3. Query Wikimedia Geosearch for authentic local landmarks with genuine photographs around GPS
    try {
      final lat = _pickupLocation.lat;
      final lng = _pickupLocation.lng;
      final geoUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=geosearch'
        '&ggscoord=$lat|$lng&ggsradius=20000&ggslimit=8&prop=pageimages|coordinates&pithumbsize=600&format=json',
      );
      final gResp = await http.get(geoUrl, headers: {'User-Agent': 'SheRideApp/1.0 (contact@sheride.app)'}).timeout(const Duration(seconds: 3));
      if (gResp.statusCode == 200) {
        final gData = jsonDecode(gResp.body);
        final pages = gData['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          for (final p in pages.values) {
            final title = (p['title'] as String?) ?? '';
            final thumb = p['thumbnail']?['source'] as String?;
            final coords = p['coordinates'] as List<dynamic>?;
            if (title.isNotEmpty && coords != null && coords.isNotEmpty) {
              final cLat = (coords.first['lat'] as num).toDouble();
              final cLng = (coords.first['lon'] as num).toDouble();
              final key = title.toLowerCase();
              if (!seenNames.contains(key)) {
                seenNames.add(key);
                final dist = _locationService.calculateDistanceKm(lat, lng, cLat, cLng);
                combined.add(DynamicPlaceItem(
                  title: title,
                  address: title,
                  lat: cLat,
                  lng: cLng,
                  tag: 'Nearby',
                  distanceKm: dist,
                  zoom: 15.2,
                  photoUrl: thumb,
                ));
              }
            }
          }
        }
      }
    } catch (_) {}

    // 4. Dynamically Query Mapbox Search Box & Geocoding for POIs
    try {
      final lat = _pickupLocation.lat;
      final lng = _pickupLocation.lng;
      final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

      // Query prominent nearby transit hubs, shopping malls, railway stations and landmarks around user coordinates
      final categories = ['railway station', 'bus station', 'shopping mall', 'hospital', 'complex'];
      for (final cat in categories) {
        if (combined.length >= 12) break;

        // Try Mapbox Search Box API first for POIs with photo metadata
        try {
          final searchBoxUrl = Uri.parse(
            'https://api.mapbox.com/search/searchbox/v1/suggest'
            '?q=${Uri.encodeComponent(cat)}&language=en&proximity=$lng,$lat&types=poi&limit=2'
            '&session_token=$sessionToken&access_token=${ApiConstants.mapboxAccessToken}',
          );

          final sbResp = await http.get(searchBoxUrl).timeout(const Duration(seconds: 3));
          if (sbResp.statusCode == 200) {
            final sbData = jsonDecode(sbResp.body);
            final suggestions = sbData['suggestions'] as List<dynamic>? ?? [];
            for (final s in suggestions) {
              final mapboxId = s['mapbox_id'] as String? ?? '';
              final name = s['name'] as String? ?? '';
              final fullAddr = s['full_address'] as String? ?? (s['place_formatted'] as String? ?? name);

              if (mapboxId.isNotEmpty && name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
                // Retrieve POI details with photos attribute set
                final retrieveUrl = Uri.parse(
                  'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
                  '?attribute_sets=photos&session_token=$sessionToken&access_token=${ApiConstants.mapboxAccessToken}',
                );
                final retResp = await http.get(retrieveUrl).timeout(const Duration(seconds: 3));
                if (retResp.statusCode == 200) {
                  final retData = jsonDecode(retResp.body);
                  final feats = retData['features'] as List<dynamic>? ?? [];
                  if (feats.isNotEmpty) {
                    final f = feats.first;
                    final coords = f['geometry']?['coordinates'] as List<dynamic>?;
                    if (coords != null && coords.length >= 2) {
                      final pLng = (coords[0] as num).toDouble();
                      final pLat = (coords[1] as num).toDouble();

                      // Check for photo metadata in Mapbox Search Box response
                      String? extractedPhotoUrl;
                      final photos = f['properties']?['metadata']?['photos'] as List<dynamic>? ??
                          f['properties']?['photos'] as List<dynamic>?;
                      if (photos != null && photos.isNotEmpty) {
                        final firstPhoto = photos.first;
                        if (firstPhoto is Map<String, dynamic>) {
                          extractedPhotoUrl = firstPhoto['url'] as String? ??
                              firstPhoto['urls']?['regular'] as String? ??
                              firstPhoto['urls']?['small'] as String?;
                        } else if (firstPhoto is String) {
                          extractedPhotoUrl = firstPhoto;
                        }
                      }

                      seenNames.add(name.toLowerCase());
                      final dist = _locationService.calculateDistanceKm(lat, lng, pLat, pLng);
                      combined.add(DynamicPlaceItem(
                        title: name,
                        address: fullAddr,
                        lat: pLat,
                        lng: pLng,
                        tag: 'Nearby',
                        distanceKm: dist,
                        zoom: 15.2,
                        photoUrl: extractedPhotoUrl,
                      ));
                    }
                  }
                }
              }
            }
          }
        } catch (_) {}

        // Fallback: Mapbox Geocoding v5 for reliable location discovery
        if (combined.length < 12) {
          final url = Uri.parse(
            'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(cat)}.json'
            '?proximity=$lng,$lat&types=poi,address,neighborhood,locality&limit=3&access_token=${ApiConstants.mapboxAccessToken}',
          );

          final resp = await http.get(url).timeout(const Duration(seconds: 3));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            final features = data['features'] as List<dynamic>? ?? [];
            for (final f in features) {
              final placeName = f['text'] as String? ?? '';
              final fullAddr = f['place_name'] as String? ?? placeName;
              final center = f['center'] as List<dynamic>?;
              if (center != null && center.length >= 2 && placeName.isNotEmpty) {
                final pLng = (center[0] as num).toDouble();
                final pLat = (center[1] as num).toDouble();
                final key = placeName.toLowerCase();

                if (!seenNames.contains(key)) {
                  seenNames.add(key);
                  final dist = _locationService.calculateDistanceKm(lat, lng, pLat, pLng);
                  combined.add(DynamicPlaceItem(
                    title: placeName,
                    address: fullAddr,
                    lat: pLat,
                    lng: pLng,
                    tag: 'Nearby',
                    distanceKm: dist,
                    zoom: 15.2,
                  ));
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Mapbox dynamic POI query error: $e");
    }

    // 4. Fallback Curated Hubs if Offline or Initializing
    if (combined.length < 6) {
      final fallbackHubs = [
        {'title': 'Railway Station', 'address': 'Railway Station Main Junction', 'lat': _pickupLocation.lat + 0.008, 'lng': _pickupLocation.lng - 0.005},
        {'title': 'RTC Complex', 'address': 'Central Bus Terminal & Hub', 'lat': _pickupLocation.lat - 0.006, 'lng': _pickupLocation.lng + 0.004},
        {'title': 'City Mall', 'address': 'Shopping Mall & Multiplex', 'lat': _pickupLocation.lat + 0.004, 'lng': _pickupLocation.lng + 0.008},
        {'title': 'Commercial Center', 'address': 'Main Market Road', 'lat': _pickupLocation.lat - 0.005, 'lng': _pickupLocation.lng - 0.006},
        {'title': 'Bus Stand Road', 'address': 'Transit Stand & Market', 'lat': _pickupLocation.lat + 0.012, 'lng': _pickupLocation.lng + 0.010},
        {'title': 'Town Hall / Circle', 'address': 'Central Town Circle', 'lat': _pickupLocation.lat - 0.010, 'lng': _pickupLocation.lng + 0.002},
      ];

      for (final h in fallbackHubs) {
        final title = h['title'] as String;
        if (!seenNames.contains(title.toLowerCase())) {
          seenNames.add(title.toLowerCase());
          final hLat = h['lat'] as double;
          final hLng = h['lng'] as double;
          final dist = _locationService.calculateDistanceKm(_pickupLocation.lat, _pickupLocation.lng, hLat, hLng);
          combined.add(DynamicPlaceItem(
            title: title,
            address: h['address'] as String,
            lat: hLat,
            lng: hLng,
            tag: 'Nearby',
            distanceKm: dist,
            zoom: 15.0,
          ));
        }
      }
    }

    // Sort by proximity & visits
    combined.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (mounted) {
      setState(() {
        _dynamicPlaces = combined;
        _recentSearches = recentsList;
        _isLoadingNearby = false;
      });
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

      final raw = prefs.getString('sheride_recent_destinations');
      List<dynamic> list = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];
      list.removeWhere((x) => x['title'] == title || (x['lat'] == lat && x['lng'] == lng));
      list.insert(0, item);
      if (list.length > 8) {
        list = list.sublist(0, 8);
      }
      await prefs.setString('sheride_recent_destinations', jsonEncode(list));
    } catch (e) {
      debugPrint("Save recent search error: $e");
    }
  }

  @override
  void dispose() {
    DestinationPreloadService().removeListener(_onPreloadUpdated);
    _searchController.dispose();
    super.dispose();
  }

  // Official Mapbox Static Images API URL with high-res tile & custom pin
  String _getMapboxImageUrl(double lat, double lng, {double zoom = 15.0, int width = 300, int height = 200}) {
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

            // Content
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
              child: MapboxPoiImage(
                placeName: res.locality,
                lat: res.lat,
                lng: res.lng,
                fit: BoxFit.cover,
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
    if (_isLoadingNearby && _dynamicPlaces.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFE91E63), strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                'Fetching nearby places from Mapbox...',
                style: TextStyle(color: Color(0xFF757575), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final displayedNearby = _showAllNearby ? _dynamicPlaces : _dynamicPlaces.take(6).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Nearby & Visited Places Header
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
            if (_dynamicPlaces.length > 6)
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

        // 2. 3-Column Grid of Dynamic Nearby Places with Mapbox POI Images
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

            return InkWell(
              onTap: () => _onSelectDropLocation(place.title, place.address, place.lat, place.lng),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gesture-Controlled Image Slider (No dots, No arrows)
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
                        child: PlaceCardImageSlider(
                          photoUrls: place.photoUrls,
                          placeName: place.title,
                          onTap: () => _onSelectDropLocation(place.title, place.address, place.lat, place.lng),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Place Title
                  SizedBox(
                    height: 30,
                    child: Text(
                      place.title,
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

        // 3. Recently Visited / Past Searches (if available)
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

          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentSearches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final r = _recentSearches[idx];
                final rImage = _getMapboxImageUrl(r.lat, r.lng, zoom: 15.0, width: 160, height: 120);

                return InkWell(
                  onTap: () => _onSelectDropLocation(r.title, r.address, r.lat, r.lng),
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
                                r.title,
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
                                '${r.distanceKm.toStringAsFixed(1)} km away',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w600,
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

