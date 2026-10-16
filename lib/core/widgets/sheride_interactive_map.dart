import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';

class SheRideMarker {
  final LatLng point;
  final Widget child;
  final double width;
  final double height;
  final Alignment alignment;

  const SheRideMarker({
    required this.point,
    required this.child,
    this.width = 44,
    this.height = 44,
    this.alignment = Alignment.center,
  });
}

class SheRideInteractiveMap extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final List<SheRideMarker> markers;
  final List<LatLng>? routePoints;
  final bool showControls;
  final VoidCallback? onRecenter;
  final ValueChanged<LatLng>? onTap;

  const SheRideInteractiveMap({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialZoom = 15.0,
    this.markers = const [],
    this.routePoints,
    this.showControls = true,
    this.onRecenter,
    this.onTap,
  });

  @override
  State<SheRideInteractiveMap> createState() => SheRideInteractiveMapState();
}

class SheRideInteractiveMapState extends State<SheRideInteractiveMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant SheRideInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLat != widget.initialLat || oldWidget.initialLng != widget.initialLng) {
      _mapController.move(LatLng(widget.initialLat, widget.initialLng), _mapController.camera.zoom);
    }
  }

  void moveTo(double lat, double lng, [double? zoom]) {
    _mapController.move(LatLng(lat, lng), zoom ?? _mapController.camera.zoom);
  }

  void zoomIn() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current + 1.0);
  }

  void zoomOut() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current - 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = LatLng(widget.initialLat, widget.initialLng);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 3.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: widget.onTap != null
                ? (tapPos, latLng) => widget.onTap!(latLng)
                : null,
          ),
          children: [
            // High speed, gesture-friendly Carto Voyager / OpenStreetMap web tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sheride.user',
              maxZoom: 19,
            ),
            if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints!,
                    strokeWidth: 5.0,
                    color: AppColors.primary,
                  ),
                ],
              ),
            MarkerLayer(
              markers: widget.markers.map((m) {
                return Marker(
                  point: m.point,
                  width: m.width,
                  height: m.height,
                  alignment: m.alignment,
                  child: m.child,
                );
              }).toList(),
            ),
          ],
        ),

        // Floating gesture-friendly Web controls (Zoom in, Zoom out, Recenter GPS)
        if (widget.showControls)
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onPressed: zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onPressed: zoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Re-center Location',
                  color: AppColors.primary,
                  iconColor: Colors.white,
                  onPressed: () {
                    moveTo(widget.initialLat, widget.initialLng, 15.5);
                    if (widget.onRecenter != null) widget.onRecenter!();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.white,
    Color iconColor = AppColors.textPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12, width: 0.5),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
