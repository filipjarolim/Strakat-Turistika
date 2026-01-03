import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/visit_data_service.dart';
import '../models/visit_data.dart';
import '../widgets/tab_switch.dart';
import 'login_page.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen height to determine hero height
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.42; 

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Very light grey base
      body: Stack(
        children: [
          // 1. Hero Image Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight + 30, // Extra bleed for curve overlap
            child: Image.asset(
              'assets/home_mascot.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          
          // 2. Gradient Overlay for status bar visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Content Sheet
          Positioned.fill(
            top: heroHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Greeting Section
                    const GreetingSection(),
                    const SizedBox(height: 24),

                    // Main Start Button
                    const MainActionCard(),
                    const SizedBox(height: 20),
                    
                    // Quick Stats & Actions Row
                    const Row(
                      children: [
                        Expanded(child: QuickStatCard(label: 'Moje data', icon: Icons.bar_chart_rounded, color: Colors.blue)),
                        SizedBox(width: 16),
                        Expanded(child: QuickStatCard(label: 'Mapa', icon: Icons.map_rounded, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Recent Activity
                    const RecentActivitySection(),
                  ],
                ),
              ),
            ),
          ),
          
          // App Bar Title (Floating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strakatá',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
                Text(
                  'TURISTIKA',
                  style: TextStyle(
                    color: Colors.white, // White text for hero
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 2.0,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
              ],
            ),
          ),
          
          // Profile Icon (Floating)
           Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Material(
              color: Colors.white.withOpacity(0.2),
              shape: const CircleBorder(),
              child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => TabSwitch.of(context)?.switchTo(3),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GreetingSection extends StatelessWidget {
  const GreetingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user != null ? 'Ahoj, ${user.name.split(' ')[0]}!' : 'Vítejte!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kam vyrazíme dnes?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class MainActionCard extends StatelessWidget {
  const MainActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Dark nice contrast
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => TabSwitch.of(context)?.switchTo(2), // GPS
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'NOVÝ VÝLET',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Zaznamenat',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.0),
                    ),
                     const Text(
                      'trasu',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.0),
                    ),
                  ],
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickStatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const QuickStatCard({super.key, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             if (label.contains('data')) TabSwitch.of(context)?.switchTo(1);
             else TabSwitch.of(context)?.switchTo(2);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reuse Activity Section mostly as is, but styled cleaner
class RecentActivitySection extends StatefulWidget {
  const RecentActivitySection({super.key});

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

class _RecentActivitySectionState extends State<RecentActivitySection> {
  final VisitDataService _visitDataService = VisitDataService();
  List<VisitData> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final season = DateTime.now().year;
      final currentUser = AuthService.currentUser;
      final result = await _visitDataService.getPaginatedVisitData(
        page: 1, limit: 3, season: season, state: null, userId: currentUser?.id, sortBy: 'createdAt', sortDescending: true,
      );
      if (!mounted) return;
      setState(() {
        _recent = (result['data'] as List<dynamic>).cast<VisitData>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Poslední aktivita',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            GestureDetector(
              onTap: () => TabSwitch.of(context)?.switchTo(1),
              child: const Text('Zobrazit vše', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
        else if (_recent.isEmpty)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
             child: const Center(child: Text('Zatím žádná aktivita.', style: TextStyle(color: Colors.grey))),
           )
        else
          Column(
            children: _recent.map((v) => ActivityItem(v)).toList(),
          ),
      ],
    );
  }
}

class ActivityItem extends StatelessWidget {
  final VisitData visit;
  const ActivityItem(this.visit, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.terrain, color: Colors.black54),
        ),
        title: Text(
          visit.routeTitle ?? visit.visitedPlaces,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
        ),
        subtitle: Text(
           '${visit.points.toStringAsFixed(0)} bodů',
           style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      ),
    );
  }
}
