import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
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
  }

  @override
  void dispose() {
    _radarPulseController.dispose();
    _activeRideSub?.cancel();
    _searchTimer?.cancel();
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
    return [
      VehicleFareOption(
        id: 'scooty',
        name: 'Scooty',
        subtitle: 'Solo Swift & Affordable',
        etaMin: 2,
        capacity: 1,
        fare: max(25.0, (20.0 + (distKm * 9.0)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'scooter',
        imageUrl: 'assets/images/vehicles/scooty.png',
        isElectric: false,
        badge: '⭐ Best Value',
        nearbyCount: 4,
      ),
      VehicleFareOption(
        id: 'electric_scooty',
        name: 'Electric Scooty',
        subtitle: '100% Eco-friendly & Silent',
        etaMin: 3,
        capacity: 1,
        fare: max(28.0, (22.0 + (distKm * 8.5)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'scooter',
        imageUrl: 'assets/images/vehicles/electric_scooty.png',
        isElectric: true,
        badge: '⚡ 100% Electric',
        nearbyCount: 5,
      ),
      VehicleFareOption(
        id: 'bike',
        name: 'Bike',
        subtitle: 'Beat Traffic Fast',
        etaMin: 3,
        capacity: 1,
        fare: max(30.0, (25.0 + (distKm * 10.5)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'bike',
        imageUrl: 'assets/images/vehicles/bike.png',
        isElectric: false,
        badge: '⚡ Fast Commute',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'priority_bike',
        name: 'Priority Bike',
        subtitle: 'Top-Rated Captain Express',
        etaMin: 2,
        capacity: 1,
        fare: max(40.0, (35.0 + (distKm * 12.5)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'bike',
        imageUrl: 'assets/images/vehicles/priority_bike.png',
        isElectric: false,
        badge: '⭐ VIP Express',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'auto',
        name: 'Auto',
        subtitle: 'Safe, iconic 3-wheeler',
        etaMin: 4,
        capacity: 3,
        fare: max(40.0, (30.0 + (distKm * 13.0)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/auto.png',
        isElectric: false,
        badge: '🌱 Everyday Favorite',
        nearbyCount: 4,
      ),
      VehicleFareOption(
        id: 'priority_auto',
        name: 'Priority Auto',
        subtitle: 'Minimal Wait Times',
        etaMin: 2,
        capacity: 3,
        fare: max(48.0, (38.0 + (distKm * 14.5)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/priority_auto.png',
        isElectric: false,
        badge: '⚡ Quick Auto',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'premium_auto',
        name: 'Premium Auto',
        subtitle: 'Luxury Cushioned Ride',
        etaMin: 3,
        capacity: 3,
        fare: max(55.0, (45.0 + (distKm * 15.5)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'auto',
        imageUrl: 'assets/images/vehicles/premium_auto.png',
        isElectric: false,
        badge: '✨ Executive Auto',
        nearbyCount: 2,
      ),
      VehicleFareOption(
        id: 'mini_car',
        name: 'Mini Car',
        subtitle: 'AC Hatchback Comfort',
        etaMin: 5,
        capacity: 4,
        fare: max(75.0, (65.0 + (distKm * 16.0)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'cab_economy',
        imageUrl: 'assets/images/vehicles/mini_car.png',
        isElectric: false,
        badge: '❄️ Chilled AC',
        nearbyCount: 3,
      ),
      VehicleFareOption(
        id: 'premium_car',
        name: 'Premium Car',
        subtitle: 'Executive Prime Sedan',
        etaMin: 5,
        capacity: 4,
        fare: max(120.0, (95.0 + (distKm * 21.0)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'cab_premium',
        imageUrl: 'assets/images/vehicles/premium_car.png',
        isElectric: false,
        badge: '👑 Luxury Sedan',
        nearbyCount: 2,
      ),
      VehicleFareOption(
        id: 'ev_car',
        name: 'EV Car',
        subtitle: 'Green Electric Sedan',
        etaMin: 4,
        capacity: 4,
        fare: max(95.0, (80.0 + (distKm * 18.0)).roundToDouble()),
        distanceKm: distKm,
        durationMin: durationMin,
        icon: 'cab_premium',
        imageUrl: 'assets/images/vehicles/ev_car.png',
        isElectric: true,
        badge: '🌿 100% Green EV',
        nearbyCount: 3,
      ),
    ];
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
          lineColor: const Color(0xFFE91E63).toARGB32(),
          lineWidth: 5.5,
          lineJoin: mb.LineJoin.ROUND,
        );
        await _polylineAnnotationManager?.create(polylineOptions);
      }
    } catch (e) {
      debugPrint("Draw route on Mapbox notice: $e");
    }

    // 2. Draw Start (Pickup Pin) & End (Destination Pin) with Teardrop needle stem pointers
    try {
      if (_pointAnnotationManager != null) {
        await _pointAnnotationManager?.deleteAll();

        final pickupPinBytes = await _createMapPinImage(
          pinColor: const Color(0xFF2E7D32), // Emerald Green
          label: 'P',
        );

        final dropPinBytes = await _createMapPinImage(
          pinColor: const Color(0xFFE91E63), // Pink Accent
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
      }
    } catch (e) {
      debugPrint("Draw start/end pin pointers on Mapbox notice: $e");
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
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
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
                          color: isApplied ? const Color(0xFFE91E63) : Colors.grey.shade200,
                          width: isApplied ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE4EC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.percent_rounded, color: Color(0xFFE91E63), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(offer.code, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(offer.description, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF757575))),
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
                                  backgroundColor: const Color(0xFFE91E63),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
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
            Text('Choose Payment Method', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
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
      leading: Icon(icon, color: const Color(0xFFE91E63)),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF757575))),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFE91E63)) : null,
      onTap: () {
        setState(() => _selectedPaymentMethod = title);
        Navigator.pop(ctx);
      },
    );
  }

  void _showFareAdjustmentModal(double defaultBoost) {
    double currentSliderBoost = defaultBoost > 0 ? defaultBoost : (_fareBoost > 0 ? _fareBoost : 20.0);
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Higher fare attracts female captains nearby much faster.',
                    style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Extra Boost: +₹${currentSliderBoost.toInt()}',
                              style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF757575),
                              ),
                            ),
                            Text(
                              '₹${totalUpdatedFare.toInt()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFE91E63),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preset Quick Boost chips
                  Row(
                    children: [10.0, 20.0, 30.0, 50.0].map((amount) {
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
                              color: isSelected ? const Color(0xFFE91E63) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+₹${amount.toInt()}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
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

                  // Interactive Slider
                  Row(
                    children: [
                      Text(
                        '+₹10',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFE91E63),
                            inactiveTrackColor: const Color(0xFFF8BBD9),
                            thumbColor: const Color(0xFFE91E63),
                            overlayColor: const Color(0x29E91E63),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: currentSliderBoost,
                            min: 10.0,
                            max: 100.0,
                            divisions: 9,
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
                        '+₹100',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
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
                        backgroundColor: const Color(0xFFE91E63),
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
                            style: GoogleFonts.plusJakartaSans(
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
          backgroundColor: const Color(0xFFE91E63),
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
            _cancelSearchingLocally();
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Please let us know so we can improve your experience',
                              style: GoogleFonts.plusJakartaSans(
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
                          color: isChosen ? const Color(0xFFFFF0F5) : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChosen ? const Color(0xFFE91E63) : const Color(0xFFEEEEEE),
                            width: isChosen ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isChosen ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 19,
                              color: isChosen ? const Color(0xFFE91E63) : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: GoogleFonts.plusJakartaSans(
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
                              side: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              foregroundColor: const Color(0xFFE91E63),
                            ),
                            child: Text(
                              'Keep Searching',
                              style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
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
      backgroundColor: const Color(0xFFFDF7FA),
      body: Stack(
        children: [
          // Mapbox Native Driving Route Map View (Extends to top status bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapHeight + 24,
            child: mb.MapWidget(
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
                  border: Border.all(color: const Color(0xFFFCE4EC)),
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
                border: Border.all(color: const Color(0xFFFCE4EC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, size: 16, color: Color(0xFFE91E63)),
                  const SizedBox(width: 6),
                  Text(
                    _isLoadingRoute
                        ? 'Calculating route...'
                        : '${selected.distanceKm} km • ${selected.durationMin} mins',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
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
                              color: const Color(0xFFFFF0F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF8BBD9).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, size: 14, color: Color(0xFF4CAF50)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _pickupLocation.name?.isNotEmpty == true ? _pickupLocation.name! : _pickupLocation.address,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF757575)),
                                const SizedBox(width: 6),
                                const Icon(Icons.location_on, size: 14, color: Color(0xFFE91E63)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _dropLocation.name?.isNotEmpty == true ? _dropLocation.name! : _dropLocation.address,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w700),
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
                                        style: GoogleFonts.plusJakartaSans(
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
                                      const Icon(Icons.percent_rounded, size: 15, color: Color(0xFFE91E63)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _appliedOffer != null ? _appliedOffer!.code : 'Offers >',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _appliedOffer != null ? const Color(0xFFE91E63) : const Color(0xFF1A1A1A),
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
                              onPressed: _isBooking ? null : _handleBookRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              ),
                              child: _isBooking
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(
                                      'Book ${selected.name} • ₹${finalFare.toInt()}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
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
            color: isSelected ? const Color(0xFFE91E63) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFE91E63) : const Color(0xFFE0E0E0),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '+₹${amount.toInt()}',
              style: GoogleFonts.plusJakartaSans(
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
                                color: const Color(0xFFE91E63).withValues(alpha: (1.0 - progress) * 0.4),
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
                              color: const Color(0xFFE91E63).withValues(alpha: (1.0 - progress) * 0.1),
                              border: Border.all(
                                color: const Color(0xFFE91E63).withValues(alpha: (1.0 - progress) * 0.6),
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
                          color: const Color(0xFFFFF0F5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE91E63), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          selected.imageUrl.isNotEmpty ? selected.imageUrl : 'assets/images/vehicles/scooty.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.electric_scooter_rounded, color: Color(0xFFE91E63), size: 30),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Status Title
                Text(
                  'Finding Your ${selected.name} Captain...',
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
                                style: GoogleFonts.plusJakartaSans(
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
                                  style: GoogleFonts.plusJakartaSans(
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
                                    color: const Color(0xFFFFF0F5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF8BBD9)),
                                  ),
                                  child: Text(
                                    '+₹${_fareBoost.toInt()}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFE91E63),
                                    ),
                                  ),
                                ),
                              ],
                              Text(
                                '₹${finalFare.toInt()}',
                                style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF424242)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 13, color: Color(0xFFE91E63)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.drop.name?.isNotEmpty == true ? widget.drop.name! : widget.drop.address,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF424242)),
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
                    border: Border.all(color: const Color(0xFFF8BBD9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFE91E63)),
                              const SizedBox(width: 4),
                              Text(
                                'Finding Partner Faster',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Increase Fare',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE91E63),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Boost fare to increase priority for female captains:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF757575)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBoostChip(10.0),
                          const SizedBox(width: 6),
                          _buildBoostChip(20.0),
                          const SizedBox(width: 6),
                          _buildBoostChip(50.0),
                          const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              onTap: () => _showFareAdjustmentModal(_fareBoost > 0 ? _fareBoost : 20.0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE91E63), width: 1.2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 13, color: Color(0xFFE91E63)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Slider',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFE91E63),
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
                          style: GoogleFonts.plusJakartaSans(
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
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFE91E63) : const Color(0xFFEEEEEE),
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
                  color: isSelected ? const Color(0xFFFCE4EC) : Colors.transparent,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                option.imageUrl.isNotEmpty ? option.imageUrl : 'assets/images/vehicles/scooty.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.electric_scooter_rounded, color: Color(0xFFE91E63)),
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
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.isElectric) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⚡ EV',
                            style: GoogleFonts.plusJakartaSans(
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
                    option.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE91E63),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        '${option.etaMin} mins away',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF757575),
                        ),
                      ),
                      Text(
                        ' • ${option.nearbyCount} captains near',
                        style: GoogleFonts.plusJakartaSans(
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
                  '₹${option.fare.toInt()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
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
                      style: GoogleFonts.plusJakartaSans(
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
    );
  }
}
