import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final List<Map<String, String>> _places = [
    {
      'title': 'Home',
      'subtitle': 'Flat 402, Sai Residency, Main Road',
      'type': 'home',
    },
    {
      'title': 'Work / Office',
      'subtitle': 'Cyber Towers, IT Corridor, Phase 1',
      'type': 'work',
    },
    {
      'title': 'College / University',
      'subtitle': 'University Campus, Gate No 3',
      'type': 'college',
    },
    {
      'title': 'Fitness Center & Gym',
      'subtitle': 'Pink Fitness Club, 2nd Floor, Commercial Hub',
      'type': 'gym',
    },
  ];

  void _addNewPlace() {
    final titleCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Add New Favorite Place', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: 'Place Name (e.g. Grandma House, Library)',
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              decoration: InputDecoration(
                hintText: 'Full Street Address',
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty && addrCtrl.text.isNotEmpty) {
                    setState(() {
                      _places.add({
                        'title': titleCtrl.text.trim(),
                        'subtitle': addrCtrl.text.trim(),
                        'type': 'other',
                      });
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Place saved successfully! 🌸'), backgroundColor: Color(0xFFE91E63)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Save Place', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      appBar: AppBar(
        title: Text(
          'Saved Places',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // List of places
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _places.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
              itemBuilder: (context, index) {
                final place = _places[index];
                IconData icon = Icons.place_rounded;
                if (place['type'] == 'home') icon = Icons.home_rounded;
                if (place['type'] == 'work') icon = Icons.work_rounded;
                if (place['type'] == 'college') icon = Icons.school_rounded;
                if (place['type'] == 'gym') icon = Icons.fitness_center_rounded;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFFE91E63), size: 20),
                  ),
                  title: Text(
                    place['title']!,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    place['subtitle']!,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF757575)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                    onPressed: () => setState(() => _places.removeAt(index)),
                  ),
                  onTap: () {
                    context.push('/destination-search', extra: {
                      'initialQuery': place['title'],
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Add New Place Button
          OutlinedButton.icon(
            onPressed: _addNewPlace,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE91E63),
              side: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 20),
            label: Text(
              'Add New Favorite Place',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
