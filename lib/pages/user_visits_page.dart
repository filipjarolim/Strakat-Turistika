import 'package:flutter/material.dart';
import '../services/visit_data_service.dart';
import '../models/visit_data.dart';
import '../widgets/ui/app_toast.dart';

class UserVisitsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const UserVisitsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserVisitsPage> createState() => _UserVisitsPageState();
}

class _UserVisitsPageState extends State<UserVisitsPage> {
  final VisitDataService _visitDataService = VisitDataService();
  List<VisitData> _visits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVisits();
  }

  Future<void> _loadUserVisits() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all visits for this user
      final result = await _visitDataService.getPaginatedVisitData(
        page: 1,
        limit: 1000, // Large limit to get all visits
        userId: widget.userId,
        state: VisitState.APPROVED,
      );

      if (mounted) {
        setState(() {
          _visits = (result['data'] as List<dynamic>).cast<VisitData>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user visits: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppToast.showError(context, 'Chyba načítání návštěv uživatele');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Návštěvy uživatele ${widget.userName}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : _visits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Opacity(
                         opacity: 0.8,
                         child: Image.asset(
                          'assets/empty_state_illustration.png',
                          height: 150,
                        ),
                       ),
                      const SizedBox(height: 24),
                      Text(
                        'Uživatel zatím nemá žádné schválené návštěvy',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _visits.length,
                  itemBuilder: (context, index) {
                    final visit = _visits[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showRouteDetailsSheet(visit),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _getShortVisitTitle(visit),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${visit.points.toStringAsFixed(1)} bodů',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (visit.visitedPlaces.isNotEmpty)
                                  _buildPlaceTags(visit.visitedPlaces),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (visit.visitDate != null) ...[
                                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF9E9E9E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${visit.visitDate!.day}.${visit.visitDate!.month}.${visit.visitDate!.year}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    if (visit.year != 0) ...[
                                      const Icon(Icons.calendar_month, size: 14, color: Color(0xFF9E9E9E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sezóna ${visit.year}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (visit.route != null && (visit.route!['trackPoints'] as List?)?.isNotEmpty == true)
                                      Row(
                                        children: [
                                          const Icon(Icons.route, size: 14, color: Color(0xFF4CAF50)),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Trasa',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4CAF50),
                                              fontWeight: FontWeight.w600,
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
                      ),
                    );
                  },
                ),
    );
  }

  String _getShortVisitTitle(VisitData visit) {
    // Prefer route title if available and not too long
    if (visit.routeTitle != null && visit.routeTitle!.isNotEmpty && visit.routeTitle!.length <= 50) {
      return visit.routeTitle!;
    }
    
    // If no route title or too long, use visited places
    final places = visit.visitedPlaces.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (places.isEmpty) return 'Bez názvu trasy';
    
    // Show first 3 places and add ellipsis if more
    if (places.length <= 3) {
      return places.join(', ');
    } else {
      return '${places.take(3).join(', ')}...';
    }
  }

  Widget _buildPlaceTags(String places) {
    final placeList = places.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (placeList.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: placeList.map((place) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
        ),
        child: Text(
          place,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }

  void _showRouteDetailsSheet(VisitData visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.hiking,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getShortVisitTitle(visit),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Návštěva uživatele ${widget.userName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.star_outline, 'Body', '${visit.points.toStringAsFixed(1)} bodů'),
                    if (visit.route != null && visit.route!['totalDistance'] != null)
                      _buildDetailRow(Icons.route_outlined, 'Vzdálenost', '${((visit.route!['totalDistance'] as num) / 1000).toStringAsFixed(1)} km'),
                    if (visit.visitDate != null)
                      _buildDetailRow(Icons.calendar_today_outlined, 'Datum návštěvy', '${visit.visitDate!.day}.${visit.visitDate!.month}.${visit.visitDate!.year}'),
                    if (visit.year != 0)
                      _buildDetailRow(Icons.calendar_month, 'Sezóna', '${visit.year}'),
                    if (visit.dogName != null && visit.dogName!.isNotEmpty)
                      _buildDetailRow(Icons.pets, 'Jméno psa', visit.dogName!),
                    if (visit.routeDescription != null && visit.routeDescription!.isNotEmpty)
                      _buildDetailRow(Icons.description_outlined, 'Popis trasy', visit.routeDescription!),
                    // Navštívená místa jako tagy
                    if (visit.visitedPlaces.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, color: const Color(0xFF6B7280), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Navštívená místa',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildPlaceTags(visit.visitedPlaces),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (visit.dogNotAllowed != null && visit.dogNotAllowed!.isNotEmpty)
                      _buildDetailRow(Icons.warning_outlined, 'Pes není povolen', visit.dogNotAllowed!),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B7280), size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
