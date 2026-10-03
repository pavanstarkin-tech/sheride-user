import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import '../constants/api_constants.dart';

class AddressInfo {
  final String fullAddress;
  final String locality;
  final String city;
  final String state;
  final double lat;
  final double lng;

  const AddressInfo({
    required this.fullAddress,
    required this.locality,
    required this.city,
    required this.state,
    required this.lat,
    required this.lng,
  });
}

class MapboxRouteInfo {
  final double distanceKm;
  final int durationMin;
  final List<mb.Position> routeCoordinates;

  const MapboxRouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.routeCoordinates,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal() {
    _initPassiveLocationStream();
  }

  void _initPassiveLocationStream() async {
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        _lastKnownPosition = cached;
        reverseGeocode(cached.latitude, cached.longitude);
      }

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (pos) {
          _lastKnownPosition = pos;
          reverseGeocode(pos.latitude, pos.longitude);
        },
        onError: (err) {
          debugPrint("Passive location stream notice: $err");
        },
      );
    } catch (e) {
      debugPrint("Init passive location stream error: $e");
    }
  }

  FirebaseDatabase? _db;
  StreamSubscription<Position>? _positionStreamSub;
  Position? _lastKnownPosition;
  AddressInfo? _currentAddress;

  Position? get lastKnownPosition => _lastKnownPosition;
  AddressInfo? get currentAddress => _currentAddress;

  FirebaseDatabase get db {
    if (_db == null) {
      try {
        _db = FirebaseDatabase.instance;
      } catch (e) {
        debugPrint("LocationService DB fallback: $e");
      }
    }
    return _db ?? FirebaseDatabase.instance;
  }

  // Request location permission
  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled on device");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Location permission check exception: $e");
      return false;
    }
  }

  // Get current GPS position with instant cache & multi-tier fast sensor fix
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        _lastKnownPosition = await Geolocator.getLastKnownPosition();
        return _lastKnownPosition;
      }

      // 1. Try to get last known position first for instant response
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        _lastKnownPosition = cached;
      }

      // 2. Fetch fresh high-accuracy position from FusedLocationProvider (fast 3.5s timeout)
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _lastKnownPosition = fresh;
        return fresh;
      } catch (e) {
        debugPrint("High accuracy GPS fetch notice: $e");
      }

      // 3. Fast fallback to medium accuracy if high accuracy timed out
      try {
        final medium = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 3),
          ),
        );
        _lastKnownPosition = medium;
        return medium;
      } catch (e) {
        debugPrint("Medium accuracy GPS fetch notice: $e");
      }

      return _lastKnownPosition;
    } catch (e) {
      debugPrint("Error in getCurrentPosition: $e");
      try {
        _lastKnownPosition = await Geolocator.getLastKnownPosition();
      } catch (_) {}
      return _lastKnownPosition;
    }
  }

  // Real-time reverse geocoding for coordinates to address (Mapbox + Nominatim Fallback)
  Future<AddressInfo> reverseGeocode(double lat, double lng) async {
    // 1. Try Mapbox Geocoding API
    try {
      final mapboxUrl = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=${ApiConstants.mapboxAccessToken}&types=poi,address,neighborhood,locality,place,district',
      );
      final response = await http.get(mapboxUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final top = features.first;
          final placeName = top['place_name'] as String? ?? '';
          final text = top['text'] as String? ?? '';
          
          String city = '';
          String state = '';
          for (final ctx in (top['context'] as List<dynamic>? ?? [])) {
            final id = (ctx['id'] as String? ?? '');
            if (id.startsWith('place') || id.startsWith('district')) {
              city = ctx['text'] as String? ?? city;
            } else if (id.startsWith('region')) {
              state = ctx['text'] as String? ?? state;
            }
          }

          final info = AddressInfo(
            fullAddress: placeName.isNotEmpty ? placeName : (text.isNotEmpty ? '$text, $city' : 'Current Location'),
            locality: text.isNotEmpty ? text : (city.isNotEmpty ? city : 'Current location'),
            city: city.isNotEmpty ? city : 'Local Area',
            state: state.isNotEmpty ? state : '',
            lat: lat,
            lng: lng,
          );
          _currentAddress = info;
          return info;
        }
      }
    } catch (e) {
      debugPrint("Mapbox reverse geocode notice: $e");
    }

    // 2. Try OpenStreetMap Nominatim Reverse Geocoding as high-precision fallback
    try {
      final nominatimUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final res = await http.get(nominatimUrl, headers: {
        'User-Agent': 'SheRide-WomenSafetyApp/1.0',
      }).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final displayName = data['display_name'] as String? ?? '';
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['road'] ?? addr['residential'] ?? '';
        final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? addr['state_district'] ?? 'Local City';
        final state = addr['state'] ?? '';

        final info = AddressInfo(
          fullAddress: displayName.isNotEmpty ? displayName : '$suburb, $city',
          locality: suburb.isNotEmpty ? suburb : city,
          city: city,
          state: state,
          lat: lat,
          lng: lng,
        );
        _currentAddress = info;
        return info;
      }
    } catch (e) {
      debugPrint("Nominatim reverse geocode notice: $e");
    }

    final fallback = AddressInfo(
      fullAddress: 'Current GPS Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
      locality: 'My Location',
      city: 'Live GPS',
      state: 'India',
      lat: lat,
      lng: lng,
    );
    _currentAddress = fallback;
    return fallback;
  }

  // Ultra-accurate proximity place search (Mapbox Autocomplete + Photon Landmark Fallback)
  Future<List<AddressInfo>> searchPlacesProximity({
    required String query,
    required double currentLat,
    required double currentLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <AddressInfo>[];
    final seen = <String>{};
    final encoded = Uri.encodeComponent(cleanQuery);

    // 1. Mapbox Geocoding Autocomplete with proximity prioritization
    try {
      final mapboxUrl = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json?access_token=${ApiConstants.mapboxAccessToken}&proximity=$currentLng,$currentLat&country=IN&types=poi,address,neighborhood,locality,place,district,poi.landmark&autocomplete=true&limit=10',
      );
      final res = await http.get(mapboxUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final features = data['features'] as List<dynamic>? ?? [];
        for (final f in features) {
          final center = f['center'] as List<dynamic>? ?? [currentLng, currentLat];
          final placeLng = (center[0] as num).toDouble();
          final placeLat = (center[1] as num).toDouble();
          final placeName = f['place_name'] as String? ?? cleanQuery;
          final text = f['text'] as String? ?? cleanQuery;

          String city = '';
          String state = '';
          for (final ctx in (f['context'] as List<dynamic>? ?? [])) {
            final id = ctx['id'] as String? ?? '';
            if (id.startsWith('place') || id.startsWith('district')) city = ctx['text'] ?? '';
            if (id.startsWith('region')) state = ctx['text'] ?? '';
          }

          final key = '${placeLat.toStringAsFixed(4)},${placeLng.toStringAsFixed(4)}';
          if (!seen.contains(key)) {
            seen.add(key);
            results.add(AddressInfo(
              fullAddress: placeName,
              locality: text.isNotEmpty ? text : placeName,
              city: city.isNotEmpty ? city : 'Local',
              state: state.isNotEmpty ? state : 'India',
              lat: placeLat,
              lng: placeLng,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Mapbox search error: $e");
    }

    // 2. Photon (OpenStreetMap) Proximity Fallback if fewer results
    if (results.length < 5) {
      try {
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=$encoded&lat=$currentLat&lon=$currentLng&limit=8',
        );
        final res = await http.get(photonUrl).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final features = data['features'] as List<dynamic>? ?? [];
          for (final f in features) {
            final geometry = f['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geometry['coordinates'] as List<dynamic>? ?? [currentLng, currentLat];
            final placeLng = (coords[0] as num).toDouble();
            final placeLat = (coords[1] as num).toDouble();
            final props = f['properties'] as Map<String, dynamic>? ?? {};

            final name = props['name'] as String? ?? cleanQuery;
            final street = props['street'] as String? ?? '';
            final district = props['district'] ?? props['suburb'] ?? '';
            final city = props['city'] ?? props['county'] ?? props['state'] ?? 'Local';
            final state = props['state'] as String? ?? '';

            final fullAddressParts = [name, street, district, city].where((s) => s != null && s.toString().isNotEmpty).toList();
            final fullAddress = fullAddressParts.join(', ');

            final key = '${placeLat.toStringAsFixed(4)},${placeLng.toStringAsFixed(4)}';
            if (!seen.contains(key) && !seen.contains(name.toLowerCase())) {
              seen.add(key);
              seen.add(name.toLowerCase());
              results.add(AddressInfo(
                fullAddress: fullAddress.isNotEmpty ? fullAddress : name,
                locality: name,
                city: city.toString(),
                state: state,
                lat: placeLat,
                lng: placeLng,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint("Photon search notice: $e");
      }
    }

    // Sort all results strictly by proximity distance to the user's live coordinates
    results.sort((a, b) {
      final distA = calculateDistanceKm(currentLat, currentLng, a.lat, a.lng);
      final distB = calculateDistanceKm(currentLat, currentLng, b.lat, b.lng);
      return distA.compareTo(distB);
    });

    return results;
  }

  // Get exact real-time driving route from Mapbox Directions API
  Future<MapboxRouteInfo?> getDrivingRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson&overview=full&access_token=${ApiConstants.mapboxAccessToken}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final r = routes.first;
          final distKm = ((r['distance'] as num).toDouble() / 1000.0);
          final durMin = max(2, ((r['duration'] as num).toDouble() / 60.0).round());
          final geom = r['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>? ?? [];

          final points = coords.map((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return mb.Position(lng, lat);
          }).toList();

          return MapboxRouteInfo(
            distanceKm: double.parse(distKm.toStringAsFixed(1)),
            durationMin: durMin,
            routeCoordinates: points,
          );
        }
      }
    } catch (e) {
      debugPrint("Mapbox Directions API note: $e");
    }

    // Fallback straight-line route simulation if network drops
    final straightDist = calculateDistanceKm(startLat, startLng, endLat, endLng) * 1.25;
    final fallbackCoords = <mb.Position>[
      mb.Position(startLng, startLat),
      mb.Position(
        startLng + (endLng - startLng) * 0.5 + 0.002,
        startLat + (endLat - startLat) * 0.5 + 0.001,
      ),
      mb.Position(endLng, endLat),
    ];
    return MapboxRouteInfo(
      distanceKm: double.parse(max(1.0, straightDist).toStringAsFixed(1)),
      durationMin: max(4, (straightDist * 3.0).round()),
      routeCoordinates: fallbackCoords,
    );
  }

  // Calculate distance in km (Haversine formula)
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
          cos(lat1 * p) * cos(lat2 * p) * 
          (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  // Start continuous location publishing to /userLocations/{userId}
  void startLocationPublishing(String userId) {
    _positionStreamSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _lastKnownPosition = position;
        try {
          db.ref('userLocations/$userId').set({
            'lat': position.latitude,
            'lng': position.longitude,
            'heading': position.heading,
            'updatedAt': ServerValue.timestamp,
          }).catchError((err) {
            debugPrint("userLocations write notice: $err");
          });
        } catch (_) {}
      },
      onError: (err) {
        debugPrint("Location stream error: $err");
      },
    );
  }

  // Stop location publishing
  void stopLocationPublishing() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }
}
