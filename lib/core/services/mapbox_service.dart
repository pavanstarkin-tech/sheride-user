import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../constants/api_constants.dart';
import '../../features/rides/domain/ride_model.dart';

class PlaceSearchResult {
  final String id;
  final String title;
  final String address;
  final double lat;
  final double lng;

  const PlaceSearchResult({
    required this.id,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class MapboxService {
  static final MapboxService _instance = MapboxService._internal();
  factory MapboxService() => _instance;
  MapboxService._internal();

  MapboxMap? mapboxMap;
  geo.Position? currentPosition;

  static void initMapbox() {
    try {
      MapboxOptions.setAccessToken(ApiConstants.mapboxAccessToken);
    } catch (e) {
      debugPrint("Mapbox token initialization notice: $e");
    }
  }

  // Geocoding / Search Places via Mapbox API with curated fallbacks
  Future<List<PlaceSearchResult>> searchPlaces(String query, {double? proximityLat, double? proximityLng}) async {
    if (query.trim().isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final proximity = (proximityLat != null && proximityLng != null)
          ? '&proximity=$proximityLng,$proximityLat'
          : '';
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=${ApiConstants.mapboxAccessToken}&country=IN$proximity&limit=5',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        return features.map((f) {
          final center = f['center'] as List<dynamic>;
          return PlaceSearchResult(
            id: f['id'] ?? '',
            title: f['text'] ?? f['place_name'] ?? query,
            address: f['place_name'] ?? '',
            lng: (center[0] as num).toDouble(),
            lat: (center[1] as num).toDouble(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Mapbox places fallback: $e");
    }

    // Curated high quality Indian regional places fallback
    return _curatedPlacesFallback(query);
  }

  List<PlaceSearchResult> _curatedPlacesFallback(String query) {
    final lower = query.toLowerCase();
    final all = [
      const PlaceSearchResult(
        id: 'place_1',
        title: 'Rajahmundry Railway Station',
        address: 'Station Road, Innespeta, Rajahmundry, Andhra Pradesh',
        lat: 17.0005,
        lng: 81.7800,
      ),
      const PlaceSearchResult(
        id: 'place_2',
        title: 'RTC Complex & Bus Station',
        address: 'Main Road, Danavaipeta, Rajahmundry, Andhra Pradesh',
        lat: 17.0125,
        lng: 81.7850,
      ),
      const PlaceSearchResult(
        id: 'place_3',
        title: 'Prasaditya Mall & Cinema',
        address: 'Stadium Road, Tilak Nagar, Rajahmundry',
        lat: 17.0080,
        lng: 81.7920,
      ),
      const PlaceSearchResult(
        id: 'place_4',
        title: 'Divancheruvu Hub & College',
        address: 'Palacherla Junction, Divancheruvu, Rajahmundry',
        lat: 17.0520,
        lng: 81.8210,
      ),
      const PlaceSearchResult(
        id: 'place_5',
        title: 'Kotipalli Bus Stand',
        address: 'Kotipalli Stand Road, Old Town, Rajahmundry',
        lat: 16.9920,
        lng: 81.7740,
      ),
      const PlaceSearchResult(
        id: 'place_6',
        title: 'Gokavaram Bus Stand',
        address: 'Aryapuram, Rajahmundry, Andhra Pradesh',
        lat: 17.0190,
        lng: 81.7780,
      ),
    ];

    final filtered = all.where((p) => p.title.toLowerCase().contains(lower) || p.address.toLowerCase().contains(lower)).toList();
    return filtered.isNotEmpty ? filtered : all.take(4).toList();
  }

  // Calculate distance between two coordinates in Kilometers
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
          cos(lat1 * p) * cos(lat2 * p) * 
          (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  // Generate intermediate route polyline points
  List<LocationPoint> generateRoutePoints(LocationPoint start, LocationPoint end, {int steps = 12}) {
    final points = <LocationPoint>[start];
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final lat = start.lat + (end.lat - start.lat) * t + (sin(t * pi) * 0.002);
      final lng = start.lng + (end.lng - start.lng) * t;
      points.add(LocationPoint(lat: lat, lng: lng, address: ''));
    }
    points.add(end);
    return points;
  }
}
