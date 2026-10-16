import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/sheride_interactive_map.dart';
import '../../wallet/data/offer_service.dart';
import '../../wallet/data/wallet_service.dart';
import '../../wallet/domain/offer_model.dart';
import '../data/ride_service.dart';
import '../domain/ride_model.dart';

class RideSelectionScreen extends StatefulWidget {
  final LocationPoint pickup;
  final LocationPoint drop;

  const RideSelectionScreen({
    super.key,
    required this.pickup,
    required this.drop,
  });

  @override
  State<RideSelectionScreen> createState() => _RideSelectionScreenState();
}

class _RideSelectionScreenState extends State<RideSelectionScreen> with SingleTickerProviderStateMixin {
  late final RideService _rideService;
  late final OfferService _offerService;
  late final WalletService _walletService;
  final _locationService = LocationService();

  late LocationPoint _pickupLocation;
  late LocationPoint _dropLocation;
  late List<VehicleFareOption> _options;
  int _selectedIndex = 0;
  String _selectedPaymentMethod = 'Cash';
  OfferModel? _appliedOffer;
  bool _isBooking = false;

  // In-sheet Captain Searching State
  bool _isSearchingCaptain = false;
  bool _isCancelling = false;
  double _fareBoost = 0.0;
  RideModel? _activeRide;
  StreamSubscription<RideModel?>? _activeRideSub;
  Timer? _searchTimer;
  int _searchCountdownSeconds = 45;
  late AnimationController _radarPulseController;

  mb.MapboxMap? _mapboxMap;
  mb.PolylineAnnotationManager? _polylineAnnotationManager;
  mb.PointAnnotationManager? _pointAnnotationManager;
  MapboxRouteInfo? _routeInfo;
  bool _isLoadingRoute = true;
  List<NearbyRiderMarker> _nearbyVehicles = [];

  // Real-time Admin Vehicle Availability Settings & Custom Pricing Rates
  Map<String, bool> _vehicleAvailability = {};
  Map<String, Map<String, dynamic>> _vehicleCustomSettings = {};
  double _adminSurgeMultiplier = 1.0;
  StreamSubscription<DatabaseEvent>? _vehicleSettingsSub;
  StreamSubscription<DatabaseEvent>? _appConfigSub;

  @override
  void initState() {
    super.initState();
    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _rideService = RideService();
    _offerService = OfferService();
    _walletService = WalletService();

    // Lock pickup location strictly to user's real live position
    final livePos = _locationService.lastKnownPosition;
    final liveAddr = _locationService.currentAddress;
    if (livePos != null) {
      _pickupLocation = LocationPoint(
        lat: livePos.latitude,
        lng: livePos.longitude,
        address: liveAddr?.fullAddress ?? (widget.pickup.address.isNotEmpty ? widget.pickup.address : 'Current Location'),
        name: liveAddr?.locality ?? (widget.pickup.name?.isNotEmpty == true ? widget.pickup.name! : 'Current location'),
      );
    } else {
      _pickupLocation = widget.pickup;
    }
    _dropLocation = widget.drop;

    _options = _rideService.calculateFares(_pickupLocation, _dropLocation);
    _loadMapboxDrivingRoute();
    _loadNearbyVehicles();
    _listenToVehicleSettings();
  }

  void _listenToVehicleSettings() {
    _vehicleSettingsSub = FirebaseDatabase.instance.ref('settings/vehicleTypes').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value;
        final availability = <String, bool>{};
        final customSettings = <String, Map<String, dynamic>>{};
        if (data is Map) {
          data.forEach((k, v) {
            if (v is Map) {
              final id = k.toString();
              final map = Map<String, dynamic>.from(v);
              final active = map['isActive'] != false;
              availability[id] = active;
              customSettings[id] = map;
            }
          });
        }
        if (mounted) {
          setState(() {
            _vehicleAvailability = availability;
            _vehicleCustomSettings = customSettings;
            if (_routeInfo != null) {
              _options = _recalculateFaresWithRoadDistance(_routeInfo!.distanceKm, _routeInfo!.durationMin);
            }
          });
        }
      }
    });

    _appConfigSub = FirebaseDatabase.instance.ref('settings/appConfig').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final surge = (data['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
        if (mounted) {
          setState(() {
            _adminSurgeMultiplier = (surge > 0) ? surge : 1.0;
            if (_routeInfo != null) {
              _options = _recalculateFaresWithRoadDistance(_routeInfo!.distanceKm, _routeInfo!.durationMin);
            }
          });
        }
      }
    });
  }

  Future<void> _loadNearbyVehicles() async {
    try {
      final vehicles = await _rideService.getNearbyVehicles(_pickupLocation);
      if (mounted) {
        setState(() {
          _nearbyVehicles = vehicles;
          if (_routeInfo != null) {
            _options = _recalculateFaresWithRoadDistance(_routeInfo!.distanceKm, _routeInfo!.durationMin);
          }
        });
        _drawRouteAndFitCamera();
      }
    } catch (e) {
      debugPrint("Error loading nearby vehicles in ride selection: $e");
    }
  }

  @override
  void dispose() {
    _radarPulseController.dispose();
    _activeRideSub?.cancel();
    _searchTimer?.cancel();
    _vehicleSettingsSub?.cancel();
    _appConfigSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMapboxDrivingRoute() async {
    // Refresh with fresh GPS position if available
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        final addr = await _locationService.reverseGeocode(pos.latitude, pos.longitude);
        setState(() {
          _pickupLocation = LocationPoint(
            lat: pos.latitude,
            lng: pos.longitude,
            address: addr.fullAddress.isNotEmpty ? addr.fullAddress : _pickupLocation.address,
            name: addr.locality.isNotEmpty ? addr.locality : _pickupLocation.name,
          );
        });
      }
    } catch (e) {
      debugPrint("Live GPS fetch notice: $e");
    }

    final route = await _locationService.getDrivingRoute(
      _pickupLocation.lat,
      _pickupLocation.lng,
      _dropLocation.lat,
      _dropLocation.lng,
    );

    if (mounted && route != null) {
      setState(() {
        _routeInfo = route;
        _isLoadingRoute = false;
        _options = _recalculateFaresWithRoadDistance(route.distanceKm, route.durationMin);
      });
      _drawRouteAndFitCamera();
    }
  }

  List<VehicleFareOption> _recalculateFaresWithRoadDistance(double distKm, int durationMin) {
    int countFor(String key) {
      if (_nearbyVehicles.isEmpty) return 3;
      final c = _nearbyVehicles.where((v) {
        if (key == 'scooty') return v.vehicleType.contains('scoot');
        if (key == 'bike') return v.vehicleType.contains('bike');
        if (key == 'auto') return v.vehicleType.contains('auto');
        if (key == 'car') return v.vehicleType.contains('car') || v.vehicleType.contains('cab');
        return true;
      }).length;
      return max(1, c);
    }

    int minEtaFor(String key, int defaultEta) {
      if (_nearbyVehicles.isEmpty) return defaultEta;
      final matching = _nearbyVehicles.where((v) {
        if (key == 'scooty') return v.vehicleType.contains('scoot');
        if (key == 'bike') return v.vehicleType.contains('bike');
        if (key == 'auto') return v.vehicleType.contains('auto');
        if (key == 'car') return v.vehicleType.contains('car') || v.vehicleType.contains('cab');
        return true;
      }).toList();
      if (matching.isEmpty) return defaultEta;
      return matching.map((v) => v.etaMinutes).reduce(min);
    }

    double computeVehicleFare(
      String id, {
      required double defaultBase,
      required double defaultPerKm,
      required double defaultPerMin,
      required double defaultMinFare,
    }) {
      final setting = _vehicleCustomSettings[id];
      final base = (setting?['baseFare'] as num?)?.toDouble() ?? defaultBase;
      final perKm = (setting?['perKmRate'] as num?)?.toDouble() ?? defaultPerKm;
      final perMin = (setting?['perMinuteRate'] as num?)?.toDouble() ?? defaultPerMin;
      final minFare = (setting?['minimumFare'] as num?)?.toDouble() ?? defaultMinFare;

      final raw = base + (distKm * perKm) + (durationMin * perMin);
      final withSurge = raw * _adminSurgeMultiplier;
      return max(minFare, withSurge).roundToDouble();
    }

    bool isVehicleAvailable(String id) {
      if (_vehicleAvailability.containsKey(id)) {
        return _vehicleAvailability[id]!;
      }
      return true;
    }

    return [
      VehicleFareOption(
        id: 'scooty',
        name: (_vehicleCustomSettings['scooty']?['name'] as String?) ?? 'Scooty',
        subtitle: (_vehicleCustomSettings['scooty']?['tagline'] as String?) ?? 'Solo Swift & Affordable',
        etaMin: minEtaFor('scooty', 2),
        capacity: (_vehicleCustomSettings['scooty']?['capacity'] as num?)?.toInt() ?? 1,
        fare: computeVehicleFare('scooty', defaultBase: 20.0, defaultPerKm: 9.0, defaultPerMin: 1.0, defaultMinFare: 25.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'scooter',
        imageUrl: 'assets/images/vehicles/scooty.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['scooty']?['badge'] as String?) ?? '⭐ Best Value',
        nearbyCount: countFor('scooty'),
        isAvailable: isVehicleAvailable('scooty'),
      ),
      VehicleFareOption(
        id: 'electric_scooty',
        name: (_vehicleCustomSettings['electric_scooty']?['name'] as String?) ?? 'Electric Scooty',
        subtitle: (_vehicleCustomSettings['electric_scooty']?['tagline'] as String?) ?? '100% Eco-friendly & Silent',
        etaMin: minEtaFor('scooty', 3),
        capacity: (_vehicleCustomSettings['electric_scooty']?['capacity'] as num?)?.toInt() ?? 1,
        fare: computeVehicleFare('electric_scooty', defaultBase: 25.0, defaultPerKm: 10.0, defaultPerMin: 1.2, defaultMinFare: 30.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'scooter',
        imageUrl: 'assets/images/vehicles/electric_scooty.png',
        isElectric: true,
        badge: (_vehicleCustomSettings['electric_scooty']?['badge'] as String?) ?? '⚡ 100% Electric',
        nearbyCount: countFor('scooty'),
        isAvailable: isVehicleAvailable('electric_scooty'),
      ),
      VehicleFareOption(
        id: 'bike',
        name: (_vehicleCustomSettings['bike']?['name'] as String?) ?? 'Bike',
        subtitle: (_vehicleCustomSettings['bike']?['tagline'] as String?) ?? 'Beat Traffic Fast',
        etaMin: minEtaFor('bike', 2),
        capacity: (_vehicleCustomSettings['bike']?['capacity'] as num?)?.toInt() ?? 1,
        fare: computeVehicleFare('bike', defaultBase: 25.0, defaultPerKm: 11.0, defaultPerMin: 1.3, defaultMinFare: 30.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'bike',
        imageUrl: 'assets/images/vehicles/bike.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['bike']?['badge'] as String?) ?? '⚡ Fast Commute',
        nearbyCount: countFor('bike'),
        isAvailable: isVehicleAvailable('bike'),
      ),
      VehicleFareOption(
        id: 'priority_bike',
        name: (_vehicleCustomSettings['priority_bike']?['name'] as String?) ?? 'Priority Bike',
        subtitle: (_vehicleCustomSettings['priority_bike']?['tagline'] as String?) ?? 'Top-Rated Captain Express',
        etaMin: minEtaFor('bike', 2),
        capacity: (_vehicleCustomSettings['priority_bike']?['capacity'] as num?)?.toInt() ?? 1,
        fare: computeVehicleFare('priority_bike', defaultBase: 35.0, defaultPerKm: 13.0, defaultPerMin: 1.6, defaultMinFare: 40.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'bike',
        imageUrl: 'assets/images/vehicles/priority_bike.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['priority_bike']?['badge'] as String?) ?? '⭐ VIP Express',
        nearbyCount: countFor('bike'),
        isAvailable: isVehicleAvailable('priority_bike'),
      ),
      VehicleFareOption(
        id: 'auto',
        name: (_vehicleCustomSettings['auto']?['name'] as String?) ?? 'Auto',
        subtitle: (_vehicleCustomSettings['auto']?['tagline'] as String?) ?? 'Safe, iconic 3-wheeler',
        etaMin: minEtaFor('auto', 3),
        capacity: (_vehicleCustomSettings['auto']?['capacity'] as num?)?.toInt() ?? 3,
        fare: computeVehicleFare('auto', defaultBase: 30.0, defaultPerKm: 13.0, defaultPerMin: 1.6, defaultMinFare: 40.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/auto.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['auto']?['badge'] as String?) ?? '🌱 Safe & Reliable',
        nearbyCount: countFor('auto'),
        isAvailable: isVehicleAvailable('auto'),
      ),
      VehicleFareOption(
        id: 'priority_auto',
        name: (_vehicleCustomSettings['priority_auto']?['name'] as String?) ?? 'Priority Auto',
        subtitle: (_vehicleCustomSettings['priority_auto']?['tagline'] as String?) ?? 'Minimal Wait Times',
        etaMin: minEtaFor('auto', 2),
        capacity: (_vehicleCustomSettings['priority_auto']?['capacity'] as num?)?.toInt() ?? 3,
        fare: computeVehicleFare('priority_auto', defaultBase: 40.0, defaultPerKm: 15.0, defaultPerMin: 1.8, defaultMinFare: 50.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/priority_auto.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['priority_auto']?['badge'] as String?) ?? '🚀 Express Dispatch',
        nearbyCount: countFor('auto'),
        isAvailable: isVehicleAvailable('priority_auto'),
      ),
      VehicleFareOption(
        id: 'premium_auto',
        name: (_vehicleCustomSettings['premium_auto']?['name'] as String?) ?? 'Premium Auto',
        subtitle: (_vehicleCustomSettings['premium_auto']?['tagline'] as String?) ?? 'Luxury Cushioned Ride',
        etaMin: minEtaFor('auto', 3),
        capacity: (_vehicleCustomSettings['premium_auto']?['capacity'] as num?)?.toInt() ?? 3,
        fare: computeVehicleFare('premium_auto', defaultBase: 45.0, defaultPerKm: 16.0, defaultPerMin: 2.0, defaultMinFare: 55.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/premium_auto.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['premium_auto']?['badge'] as String?) ?? '👑 Premium Fleet',
        nearbyCount: countFor('auto'),
        isAvailable: isVehicleAvailable('premium_auto'),
      ),
      VehicleFareOption(
        id: 'mini_car',
        name: (_vehicleCustomSettings['mini_car']?['name'] as String?) ?? 'Mini Car',
        subtitle: (_vehicleCustomSettings['mini_car']?['tagline'] as String?) ?? 'AC Hatchback Comfort',
        etaMin: minEtaFor('car', 4),
        capacity: (_vehicleCustomSettings['mini_car']?['capacity'] as num?)?.toInt() ?? 4,
        fare: computeVehicleFare('mini_car', defaultBase: 55.0, defaultPerKm: 17.0, defaultPerMin: 2.2, defaultMinFare: 75.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'cab_economy',
        imageUrl: 'assets/images/vehicles/mini_car.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['mini_car']?['badge'] as String?) ?? '❄️ AC Hatchback',
        nearbyCount: countFor('car'),
        isAvailable: isVehicleAvailable('mini_car'),
      ),
      VehicleFareOption(
        id: 'premium_car',
        name: (_vehicleCustomSettings['premium_car']?['name'] as String?) ?? 'Premium Car',
        subtitle: (_vehicleCustomSettings['premium_car']?['tagline'] as String?) ?? 'Executive Prime Sedan',
        etaMin: minEtaFor('car', 5),
        capacity: (_vehicleCustomSettings['premium_car']?['capacity'] as num?)?.toInt() ?? 4,
        fare: computeVehicleFare('premium_car', defaultBase: 85.0, defaultPerKm: 22.0, defaultPerMin: 2.8, defaultMinFare: 120.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'cab_premium',
        imageUrl: 'assets/images/vehicles/premium_car.png',
        isElectric: false,
        badge: (_vehicleCustomSettings['premium_car']?['badge'] as String?) ?? '✨ Executive Comfort',
        nearbyCount: countFor('car'),
        isAvailable: isVehicleAvailable('premium_car'),
      ),
      VehicleFareOption(
        id: 'ev_car',
        name: (_vehicleCustomSettings['ev_car']?['name'] as String?) ?? 'EV Car',
        subtitle: (_vehicleCustomSettings['ev_car']?['tagline'] as String?) ?? 'Green Electric Sedan',
        etaMin: minEtaFor('car', 4),
        capacity: (_vehicleCustomSettings['ev_car']?['capacity'] as num?)?.toInt() ?? 4,
        fare: computeVehicleFare('ev_car', defaultBase: 70.0, defaultPerKm: 19.0, defaultPerMin: 2.4, defaultMinFare: 95.0),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'cab_premium',
        imageUrl: 'assets/images/vehicles/ev_car.png',
        isElectric: true,
        badge: (_vehicleCustomSettings['ev_car']?['badge'] as String?) ?? '⚡ Clean EV',
        nearbyCount: countFor('car'),
        isAvailable: isVehicleAvailable('ev_car'),
      ),
    ];
  }

  Future<Uint8List> _createVehicleMapMarkerImage({
    required String vehicleType,
    required bool isSelected,
    required int etaMin,
  }) async {
    const double width = 84;
    const double height = 84;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    final center = const Offset(42, 36);
    final radius = isSelected ? 24.0 : 19.0;

    // Drop shadow
    final shadowPaint = Paint()
      ..color = (isSelected ? const Color(0xFF7F00FD) : Colors.black).withValues(alpha: isSelected ? 0.35 : 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(center.dx, center.dy + 3), radius + 2, shadowPaint);

    // Outer glow / border circle
    final outerPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = isSelected ? const Color(0xFF7F00FD) : const Color(0xFF180D2B);
    canvas.drawCircle(center, radius, outerPaint);

    // Inner white circle
    final innerPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(center, radius - 2.5, innerPaint);

    // Vehicle icon glyph
    IconData iconData = Icons.electric_scooter_rounded;
    if (vehicleType.contains('bike')) {
      iconData = Icons.two_wheeler_rounded;
    } else if (vehicleType.contains('auto')) {
      iconData = Icons.electric_rickshaw_rounded;
    } else if (vehicleType.contains('car') || vehicleType.contains('cab')) {
      iconData = Icons.directions_car_rounded;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          fontSize: isSelected ? 20 : 16,
          color: isSelected ? const Color(0xFF7F00FD) : const Color(0xFF180D2B),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );

    // Small ETA badge pill underneath
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(42, 64), width: 38, height: 16),
      const Radius.circular(8),
    );
    final pillPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = isSelected ? const Color(0xFF7F00FD) : const Color(0xFF388E3C);
    canvas.drawRRect(pillRect, pillPaint);

    final etaTextPainter = TextPainter(
      text: TextSpan(
        text: '$etaMin m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    etaTextPainter.layout();
    etaTextPainter.paint(
      canvas,
      Offset(42 - (etaTextPainter.width / 2), 64 - (etaTextPainter.height / 2)),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _createMapPinImage({
    required Color pinColor,
    required String label,
  }) async {
    const double width = 80;
    const double height = 110;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    final paint = Paint()..isAntiAlias = true;

    // 1. Drop shadow under bottom tip
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(40, 102), width: 24, height: 9),
      shadowPaint,
    );

    // 2. Teardrop pin body with needle stem pointing down
    final path = Path();
    path.moveTo(40, 98);
    path.cubicTo(18, 72, 8, 52, 8, 36);
    path.arcToPoint(
      const Offset(72, 36),
      radius: const Radius.circular(32),
      clockwise: true,
    );
    path.cubicTo(72, 52, 62, 72, 40, 98);
    path.close();

    // Fill pin body
    paint.style = PaintingStyle.fill;
    paint.color = pinColor;
    canvas.drawPath(path, paint);

    // White outer border
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.white;
    paint.strokeWidth = 4.0;
    canvas.drawPath(path, paint);

    // Inner white circle
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(40, 36), 17, paint);

    // Inner label letter / symbol (P for Pickup, D for Destination)
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: pinColor,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(40 - (textPainter.width / 2), 36 - (textPainter.height / 2)),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    try {
      mapboxMap.location.updateSettings(
        mb.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
    } catch (e) {
      debugPrint("Ride selection mapbox location settings: $e");
    }
    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _drawRouteAndFitCamera();
  }

  void _drawRouteAndFitCamera() async {
    if (_mapboxMap == null) return;

    // Calculate dynamic zoom out to ensure both start and end pins are properly framed
    final distKm = _locationService.calculateDistanceKm(
      _pickupLocation.lat,
      _pickupLocation.lng,
      _dropLocation.lat,
      _dropLocation.lng,
    );

    double zoom = 12.8;
    if (distKm < 1.5) {
      zoom = 13.5;
    } else if (distKm < 4.0) {
      zoom = 12.2;
    } else if (distKm < 8.0) {
      zoom = 11.2;
    } else if (distKm < 15.0) {
      zoom = 10.2;
    } else {
      zoom = 9.2;
    }

    final midLat = (_pickupLocation.lat + _dropLocation.lat) / 2;
    final midLng = (_pickupLocation.lng + _dropLocation.lng) / 2;

    _mapboxMap?.setCamera(mb.CameraOptions(
      center: mb.Point(coordinates: mb.Position(midLng, midLat)),
      zoom: zoom,
    ));

    // 1. Draw Mapbox Polyline
    try {
      if (_polylineAnnotationManager != null && _routeInfo != null && _routeInfo!.routeCoordinates.isNotEmpty) {
        await _polylineAnnotationManager?.deleteAll();
        
        final polylineOptions = mb.PolylineAnnotationOptions(
          geometry: mb.LineString(coordinates: _routeInfo!.routeCoordinates),
          lineColor: const Color(0xFF7F00FD).toARGB32(),
          lineWidth: 5.5,
          lineJoin: mb.LineJoin.ROUND,
        );
        await _polylineAnnotationManager?.create(polylineOptions);
      }
    } catch (e) {
      debugPrint("Draw route on Mapbox notice: $e");
    }

    // 2. Draw Start (Pickup Pin), End (Destination Pin) and Nearby Vehicles (Rapido style)
    try {
      if (_pointAnnotationManager != null) {
        await _pointAnnotationManager?.deleteAll();

        final pickupPinBytes = await _createMapPinImage(
          pinColor: const Color(0xFF2E7D32), // Emerald Green
          label: 'P',
        );

        final dropPinBytes = await _createMapPinImage(
          pinColor: const Color(0xFF7F00FD), // Pink Accent
          label: 'D',
        );

        // Starting Pickup Pin (Anchored at bottom needle tip)
        await _pointAnnotationManager?.create(mb.PointAnnotationOptions(
          geometry: mb.Point(coordinates: mb.Position(_pickupLocation.lng, _pickupLocation.lat)),
          image: pickupPinBytes,
          iconAnchor: mb.IconAnchor.BOTTOM,
          iconSize: 0.8,
        ));

        // Destination Drop Pin (Anchored at bottom needle tip)
        await _pointAnnotationManager?.create(mb.PointAnnotationOptions(
          geometry: mb.Point(coordinates: mb.Position(_dropLocation.lng, _dropLocation.lat)),
          image: dropPinBytes,
          iconAnchor: mb.IconAnchor.BOTTOM,
          iconSize: 0.8,
        ));

        // 3. Draw Nearby Live Vehicles on Map (Rapido / Uber style)
        final selectedOption = _options.isNotEmpty && _selectedIndex < _options.length ? _options[_selectedIndex] : null;
        for (final vehicle in _nearbyVehicles) {
          final isMatchingCategory = selectedOption != null &&
              ((selectedOption.id.contains('scoot') && vehicle.vehicleType.contains('scoot')) ||
               (selectedOption.id.contains('bike') && vehicle.vehicleType.contains('bike')) ||
               (selectedOption.id.contains('auto') && vehicle.vehicleType.contains('auto')) ||
               (selectedOption.id.contains('car') && (vehicle.vehicleType.contains('car') || vehicle.vehicleType.contains('cab'))));

          final vehicleMarkerBytes = await _createVehicleMapMarkerImage(
            vehicleType: vehicle.vehicleType,
            isSelected: isMatchingCategory,
            etaMin: vehicle.etaMinutes,
          );

          await _pointAnnotationManager?.create(mb.PointAnnotationOptions(
            geometry: mb.Point(coordinates: mb.Position(vehicle.lng, vehicle.lat)),
            image: vehicleMarkerBytes,
            iconAnchor: mb.IconAnchor.CENTER,
            iconSize: isMatchingCategory ? 0.95 : 0.75,
          ));
        }
      }
    } catch (e) {
      debugPrint("Draw pins & nearby vehicles on Mapbox notice: $e");
    }
  }

  void _showOffersModal(double currentFare) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Promo Coupon',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<OfferModel>>(
              future: _offerService.getOffers(),
              builder: (context, snap) {
                final offers = snap.data ?? OfferService.defaultOffers;
                return Column(
                  children: offers.map((offer) {
                    final discount = offer.calculateDiscount(currentFare);
                    final isApplied = _appliedOffer?.code == offer.code;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isApplied ? const Color(0xFF7F00FD) : Colors.grey.shade200,
                          width: isApplied ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EEFD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.percent_rounded, color: Color(0xFF7F00FD), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(offer.code, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(offer.description, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF757575))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _appliedOffer = offer;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Coupon ${offer.code} applied! Saved ₹${discount.toInt()}'),
                                  backgroundColor: const Color(0xFF7F00FD),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7F00FD),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Choose Payment Method', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            _buildPaymentOption('Cash', 'Pay cash directly to Captain', Icons.money_rounded, ctx),
            _buildPaymentOption('UPI', 'Google Pay / PhonePe / Paytm', Icons.qr_code_2_rounded, ctx),
            _buildPaymentOption('Wallet', 'SheRide Wallet Balance', Icons.account_balance_wallet_rounded, ctx),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String title, String subtitle, IconData icon, BuildContext ctx) {
    final isSelected = _selectedPaymentMethod == title;
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7F00FD)),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF757575))),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF7F00FD)) : null,
      onTap: () {
        setState(() => _selectedPaymentMethod = title);
        Navigator.pop(ctx);
      },
    );
  }

  void _showFareAdjustmentModal(double defaultBoost) {
    double currentSliderBoost = defaultBoost >= 0 ? defaultBoost : (_fareBoost > 0 ? _fareBoost : 5.0);
    final selectedVehicle = _options[_selectedIndex];
    final originalFare = selectedVehicle.fare;
    final discount = _appliedOffer?.calculateDiscount(originalFare, vehicleType: selectedVehicle.id) ?? 0.0;
    final baseFare = (originalFare - discount).clamp(10.0, double.infinity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalUpdatedFare = baseFare + currentSliderBoost;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Boost Fare for Faster Pickup',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Higher fare attracts female captains nearby much faster.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fare Summary Card inside Modal
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Base Fare: ₹${baseFare.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Extra Boost: +₹${currentSliderBoost.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total New Fare',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF757575),
                              ),
                            ),
                            Text(
                              '₹${totalUpdatedFare.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF7F00FD),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preset Quick Lower Boost chips
                  Row(
                    children: [0.0, 5.0, 10.0, 15.0].map((amount) {
                      final isSelected = currentSliderBoost == amount;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentSliderBoost = amount;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF7F00FD) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF7F00FD) : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                amount == 0.0 ? 'Base ₹0' : '+₹${amount.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Interactive Slider (Economic range: ₹0 to ₹30)
                  Row(
                    children: [
                      Text(
                        '₹0',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF7F00FD),
                            inactiveTrackColor: const Color(0xFFEDDCFF),
                            thumbColor: const Color(0xFF7F00FD),
                            overlayColor: const Color(0x29E91E63),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: currentSliderBoost,
                            min: 0.0,
                            max: 30.0,
                            divisions: 6,
                            label: '+₹${currentSliderBoost.toInt()}',
                            onChanged: (val) {
                              setModalState(() {
                                currentSliderBoost = val;
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        '+₹30',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirm & Restart 45s Search Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _applyFareBoostAndRestart(currentSliderBoost);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F00FD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Confirm ₹${totalUpdatedFare.toInt()} & Find Partner',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _applyFareBoostAndRestart(double boost) async {
    final selectedVehicle = _options[_selectedIndex];
    final originalFare = selectedVehicle.fare;
    final discount = _appliedOffer?.calculateDiscount(originalFare, vehicleType: selectedVehicle.id) ?? 0.0;
    final newTotalFare = (originalFare - discount + boost).clamp(10.0, double.infinity);

    setState(() {
      _fareBoost = boost;
      _searchCountdownSeconds = 45;
    });

    if (_activeRide != null) {
      try {
        await _rideService.db.ref('rides/${_activeRide!.rideId}').update({
          'fare': newTotalFare,
          'fareBoost': boost,
          'updatedAt': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint("Error updating fare in Firebase: $e");
      }
    }

    _startSearchTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fare increased by ₹${boost.toInt()}! Restarting search for partners (45s) 🚀'),
          backgroundColor: const Color(0xFF7F00FD),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleBookRide() async {
    setState(() => _isBooking = true);
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.uid ?? 'guest_user_${DateTime.now().millisecondsSinceEpoch}';

    final selectedVehicle = _options[_selectedIndex];
    final originalFare = selectedVehicle.fare;
    final discount = _appliedOffer?.calculateDiscount(originalFare, vehicleType: selectedVehicle.id) ?? 0.0;
    final finalFare = (originalFare - discount + _fareBoost).clamp(10.0, double.infinity);

    if (_selectedPaymentMethod.toLowerCase() == 'wallet') {
      await _walletService.deductFare(userId, finalFare, 'ride_pending');
    }

    try {
      final ride = await _rideService.createRide(
        userId: userId,
        userName: authService.currentUser?.displayName ?? 'Passenger',
        userPhone: authService.currentUser?.phoneNumber ?? '',
        pickup: _pickupLocation,
        drop: _dropLocation,
        selectedVehicle: VehicleFareOption(
          id: selectedVehicle.id,
          name: selectedVehicle.name,
          subtitle: selectedVehicle.subtitle,
          fare: finalFare,
          etaMin: selectedVehicle.etaMin,
          capacity: selectedVehicle.capacity,
          distanceKm: selectedVehicle.distanceKm,
          durationMin: selectedVehicle.durationMin,
          icon: selectedVehicle.icon,
        ),
        paymentMethod: _selectedPaymentMethod.toLowerCase(),
      );

      if (mounted) {
        setState(() {
          _isBooking = false;
          _isSearchingCaptain = true;
          _activeRide = ride;
          _searchCountdownSeconds = 45;
        });

        _startSearchTimer();
        _listenToActiveRide(ride.rideId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking ride: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _startSearchTimer() {
    _searchTimer?.cancel();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_isSearchingCaptain) {
        t.cancel();
        return;
      }
      if (_searchCountdownSeconds > 0) {
        setState(() => _searchCountdownSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  void _listenToActiveRide(String rideId) {
    _activeRideSub?.cancel();
    _activeRideSub = _rideService.streamRide(rideId).listen(
      (updatedRide) {
        if (updatedRide != null && mounted) {
          setState(() => _activeRide = updatedRide);
          if (updatedRide.status == 'accepted') {
            _searchTimer?.cancel();
            context.push('/rider-assigned', extra: {'ride': updatedRide});
          } else if (updatedRide.status == 'cancelled') {
            final reason = updatedRide.cancelReason;
            final byAdmin = updatedRide.cancelledBy == 'admin';
            _cancelSearchingLocally();
            if (byAdmin && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Ride cancelled by SheRide Support${reason != null && reason.isNotEmpty ? ": $reason" : ""}'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      },
      onError: (err) {
        debugPrint("Active ride stream notice: $err");
      },
    );
  }

  void _showCancelConfirmationDialog() {
    final List<String> reasons = [
      'Selected wrong pickup or drop location',
      'Finding a female captain is taking too long',
      'Booked another vehicle / ride app',
      'Fare price is higher than expected',
      'Changed my plans / No longer need a ride',
      'Other reason',
    ];

    String selectedReason = reasons.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.help_outline_rounded, color: Color(0xFFE53935), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why are you cancelling?',
                              style: GoogleFonts.inter(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Please let us know so we can improve your experience',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reasons selection list
                  ...reasons.map((r) {
                    final isChosen = selectedReason == r;
                    return InkWell(
                      onTap: () => setModalState(() => selectedReason = r),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isChosen ? const Color(0xFFF0EEFD) : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen ? const Color(0xFF7F00FD) : const Color(0xFFEEEEEE),
                            width: isChosen ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isChosen ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 19,
                              color: isChosen ? const Color(0xFF7F00FD) : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                                  color: isChosen ? const Color(0xFF1A1A1A) : const Color(0xFF424242),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Actions: Keep Searching vs Confirm Cancellation
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF7F00FD), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              foregroundColor: const Color(0xFF7F00FD),
                            ),
                            child: Text(
                              'Keep Searching',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleCancelSearch(reason: selectedReason);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Confirm Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCancelSearch({String? reason}) async {
    setState(() => _isCancelling = true);
    if (_activeRide != null) {
      try {
        await _rideService.cancelRide(_activeRide!.rideId, cancelledBy: 'user', reason: reason);
      } catch (e) {
        debugPrint("Cancel ride notice: $e");
      }
    }
    _cancelSearchingLocally(reason: reason);
  }

  void _cancelSearchingLocally({String? reason}) {
    _searchTimer?.cancel();
    _activeRideSub?.cancel();
    if (mounted) {
      setState(() {
        _isSearchingCaptain = false;
        _isCancelling = false;
        _fareBoost = 0.0;
        _activeRide = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason != null ? 'Ride cancelled: $reason' : 'Search cancelled. Select another vehicle anytime'),
          backgroundColor: const Color(0xFF1A1A1A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _options[_selectedIndex];
    final originalFare = selected.fare;
    final discount = _appliedOffer?.calculateDiscount(originalFare, vehicleType: selected.id) ?? 0.0;
    final finalFare = (originalFare - discount + _fareBoost).clamp(10.0, double.infinity);

    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final mapHeight = screenHeight * 0.38;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FE),
      body: Stack(
        children: [
          // Interactive Driving Route Map View (Web: Gesture-friendly OpenStreetMap/Carto, Mobile: Mapbox)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapHeight + 24,
            child: kIsWeb
                ? SheRideInteractiveMap(
                    initialLat: (_pickupLocation.lat + _dropLocation.lat) / 2,
                    initialLng: (_pickupLocation.lng + _dropLocation.lng) / 2,
                    initialZoom: 12.8,
                    routePoints: (_routeInfo != null && _routeInfo!.routeCoordinates.isNotEmpty)
                        ? _routeInfo!.routeCoordinates.map((p) => ll.LatLng(p.lat.toDouble(), p.lng.toDouble())).toList()
                        : [
                            ll.LatLng(_pickupLocation.lat, _pickupLocation.lng),
                            ll.LatLng(_dropLocation.lat, _dropLocation.lng),
                          ],
                    markers: [
                      // Pickup Pin
                      SheRideMarker(
                        point: ll.LatLng(_pickupLocation.lat, _pickupLocation.lng),
                        width: 72,
                        height: 56,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Text('PICKUP', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                            const Icon(Icons.location_on_rounded, color: Color(0xFF00C853), size: 30),
                          ],
                        ),
                      ),
                      // Drop Pin
                      SheRideMarker(
                        point: ll.LatLng(_dropLocation.lat, _dropLocation.lng),
                        width: 72,
                        height: 56,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Text('DROP', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                            const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 30),
                          ],
                        ),
                      ),
                    ],
                  )
                : mb.MapWidget(
                    cameraOptions: mb.CameraOptions(
                      center: mb.Point(coordinates: mb.Position(
                        (_pickupLocation.lng + _dropLocation.lng) / 2,
                        (_pickupLocation.lat + _dropLocation.lat) / 2,
                      )),
                      zoom: 12.0,
                    ),
                    styleUri: ApiConstants.mapboxStyleUrl,
                    onMapCreated: _onMapCreated,
                  ),
          ),

          // Top White Fade Gradient Background (Exact match with Home Page)
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

          // Floating Back Button
          Positioned(
            top: statusBarHeight + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF0EEFD)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A1A1A)),
              ),
            ),
          ),

          // Floating Real Mapbox Driving Route Distance & ETA Pill
          Positioned(
            top: statusBarHeight + 8,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                border: Border.all(color: const Color(0xFFF0EEFD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, size: 16, color: Color(0xFF7F00FD)),
                  const SizedBox(width: 6),
                  Text(
                    _isLoadingRoute
                        ? 'Calculating route...'
                        : '${selected.distanceKm} km • ${selected.durationMin} mins',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Ride Selection / Searching Sheet
          Positioned(
            top: mapHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
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
              child: _isSearchingCaptain
                  ? _buildSearchingCaptainSheet(
                      selected: selected,
                      finalFare: finalFare,
                    )
                    : Column(
                        children: [
                          // Sheet Handle
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Pickup to Drop Route Preview Strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EEFD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEDDCFF).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, size: 14, color: Color(0xFF4CAF50)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _pickupLocation.name?.isNotEmpty == true ? _pickupLocation.name! : _pickupLocation.address,
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF757575)),
                                const SizedBox(width: 6),
                                const Icon(Icons.location_on, size: 14, color: Color(0xFF7F00FD)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _dropLocation.name?.isNotEmpty == true ? _dropLocation.name! : _dropLocation.address,
                                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 10 Vehicle Options List
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _options.length,
                              itemBuilder: (context, idx) {
                                final opt = _options[idx];
                                return _buildVehicleCard(
                                  index: idx,
                                  option: opt,
                                  isSelected: _selectedIndex == idx,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Payment & Offers Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Cash Selector
                              GestureDetector(
                                onTap: _showPaymentMethodModal,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F7F7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE5E5E5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF1A1A1A)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$_selectedPaymentMethod >',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Offers Selector
                              GestureDetector(
                                onTap: () => _showOffersModal(originalFare),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F7F7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE5E5E5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.percent_rounded, size: 15, color: Color(0xFF7F00FD)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _appliedOffer != null ? _appliedOffer!.code : 'Offers >',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _appliedOffer != null ? const Color(0xFF7F00FD) : const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Big "Book [Vehicle] - ₹[Price]" Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_isBooking || !selected.isAvailable) ? null : _handleBookRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selected.isAvailable ? const Color(0xFFFFB001) : Colors.grey.shade300,
                                foregroundColor: const Color(0xFF180D2B),
                                elevation: selected.isAvailable ? 3 : 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              ),
                              child: _isBooking
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF180D2B)),
                                    )
                                  : Text(
                                      selected.isAvailable
                                          ? 'Book ${selected.name} • ₹${finalFare.toInt()}'
                                          : '${selected.name} is Currently Unavailable',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: selected.isAvailable ? const Color(0xFF180D2B) : Colors.grey.shade700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildBoostChip(double amount) {
    final isSelected = _fareBoost == amount;
    return Expanded(
      child: InkWell(
        onTap: () => _showFareAdjustmentModal(amount),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7F00FD) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF7F00FD) : const Color(0xFFE0E0E0),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7F00FD).withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '+₹${amount.toInt()}',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingCaptainSheet({
    required VehicleFareOption selected,
    required double finalFare,
  }) {
    return Column(
      children: [
        // Sheet Handle
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Scrollable Upper Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Radar Wave Animation Behind Circular Avatar
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Radar Wave Ring 2
                      AnimatedBuilder(
                        animation: _radarPulseController,
                        builder: (context, child) {
                          final progress = (_radarPulseController.value + 0.5) % 1.0;
                          return Container(
                            width: 66 + (progress * 28),
                            height: 66 + (progress * 28),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF7F00FD).withValues(alpha: (1.0 - progress) * 0.4),
                                width: 1.5,
                              ),
                            ),
                          );
                        },
                      ),
                      // Outer Radar Wave Ring 1
                      AnimatedBuilder(
                        animation: _radarPulseController,
                        builder: (context, child) {
                          final progress = _radarPulseController.value;
                          return Container(
                            width: 66 + (progress * 26),
                            height: 66 + (progress * 26),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7F00FD).withValues(alpha: (1.0 - progress) * 0.1),
                              border: Border.all(
                                color: const Color(0xFF7F00FD).withValues(alpha: (1.0 - progress) * 0.6),
                                width: 1.5,
                              ),
                            ),
                          );
                        },
                      ),
                      // Central Circular Avatar
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEFD),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF7F00FD), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7F00FD).withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          selected.imageUrl.isNotEmpty ? selected.imageUrl : 'assets/images/vehicles/scooty.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.electric_scooter_rounded, color: Color(0xFF7F00FD), size: 30),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Status Title
                Text(
                  'Finding Your ${selected.name} Captain...',
                  style: GoogleFonts.inter(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  _searchCountdownSeconds > 0
                      ? 'Contacting verified female captains nearby (${_searchCountdownSeconds}s)...'
                      : 'Finding partner took longer. Boost fare below to get matched fast!',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _searchCountdownSeconds > 0 ? const Color(0xFF757575) : const Color(0xFFE53935),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Ride Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                selected.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedPaymentMethod,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (_fareBoost > 0) ...[
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0EEFD),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFEDDCFF)),
                                  ),
                                  child: Text(
                                    '+₹${_fareBoost.toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF7F00FD),
                                    ),
                                  ),
                                ),
                              ],
                              Text(
                                '₹${finalFare.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 12, color: Color(0xFFE0E0E0)),
                      Row(
                        children: [
                          const Icon(Icons.my_location, size: 13, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.pickup.name?.isNotEmpty == true ? widget.pickup.name! : widget.pickup.address,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF424242)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 13, color: Color(0xFF7F00FD)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.drop.name?.isNotEmpty == true ? widget.drop.name! : widget.drop.address,
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF424242)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Finding Partner - Increase Fare Price Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDDCFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF7F00FD)),
                              const SizedBox(width: 4),
                              Text(
                                'Finding Partner Faster',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Increase Fare',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7F00FD),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Boost fare to increase priority for female captains:',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF757575)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBoostChip(5.0),
                          const SizedBox(width: 6),
                          _buildBoostChip(10.0),
                          const SizedBox(width: 6),
                          _buildBoostChip(15.0),
                          const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              onTap: () => _showFareAdjustmentModal(_fareBoost > 0 ? _fareBoost : 5.0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF7F00FD), width: 1.2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF7F00FD)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Slider',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF7F00FD),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        // Bottom Action Button
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isCancelling ? null : _showCancelConfirmationDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                foregroundColor: const Color(0xFFE53935),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53935)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close_rounded, size: 18, color: Color(0xFFE53935)),
                        const SizedBox(width: 8),
                        Text(
                          'Cancel Ride Search',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE53935),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard({
    required int index,
    required VehicleFareOption option,
    required bool isSelected,
  }) {
    final bool isAvail = option.isAvailable;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        _drawRouteAndFitCamera();
      },
      child: Opacity(
        opacity: isAvail ? 1.0 : 0.60,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isAvail ? const Color(0xFFF0EEFD) : Colors.grey.shade100) 
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? (isAvail ? const Color(0xFF7F00FD) : Colors.grey.shade400) 
                  : const Color(0xFFEEEEEE),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Vehicle Image Artwork
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF0EEFD) : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  option.imageUrl.isNotEmpty ? option.imageUrl : 'assets/images/vehicles/scooty.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.electric_scooter_rounded, color: Color(0xFF7F00FD)),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.name,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isAvail ? const Color(0xFF1A1A1A) : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isAvail) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200, width: 0.8),
                            ),
                            child: Text(
                              '🚫 Unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ] else if (option.isElectric) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '⚡ EV',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAvail ? option.subtitle : 'Disabled by Admin in Fleet Settings',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isAvail ? const Color(0xFF7F00FD) : Colors.red.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          isAvail ? '${option.etaMin} mins away' : 'Not in service',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF757575),
                          ),
                        ),
                        if (isAvail)
                          Text(
                            ' • ${option.nearbyCount} captains near',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF388E3C),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Normal Price Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isAvail ? '₹${option.fare.toInt()}' : 'Off',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isAvail ? const Color(0xFF1A1A1A) : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 12, color: Color(0xFF757575)),
                      const SizedBox(width: 2),
                      Text(
                        '${option.capacity}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
