import 'package:flutter/material.dart';

/// Gesture-Controlled Swipeable Image Slider for Destination Place Cards
/// - Allows swiping left and right to view all gallery photos of the place.
/// - Pure gesture slider with NO dots and NO arrows as per UX specifications.
class PlaceCardImageSlider extends StatefulWidget {
  final List<String> photoUrls;
  final String placeName;
  final VoidCallback? onTap;

  const PlaceCardImageSlider({
    super.key,
    required this.photoUrls,
    required this.placeName,
    this.onTap,
  });

  @override
  State<PlaceCardImageSlider> createState() => _PlaceCardImageSliderState();
}

class _PlaceCardImageSliderState extends State<PlaceCardImageSlider> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _resolvedPhotos {
    if (widget.photoUrls.isNotEmpty) return widget.photoUrls;
    return [_getCategoryFallbackPhoto(widget.placeName)];
  }

  String _getCategoryFallbackPhoto(String name) {
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
    final photos = _resolvedPhotos;

    return GestureDetector(
      onTap: widget.onTap,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final url = photos[index];
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.network(
              _getCategoryFallbackPhoto(widget.placeName),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFFCE4EC),
                child: const Center(
                  child: Icon(Icons.location_city_rounded, color: Color(0xFFE91E63), size: 26),
                ),
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
          );
        },
      ),
    );
  }
}
