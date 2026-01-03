import 'package:flutter/material.dart';
import '../models/visit_data.dart';
import '../services/visit_data_service.dart';
import '../services/auth_service.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({Key? key}) : super(key: key);

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final VisitDataService _visitDataService = VisitDataService();
  List<VisitData> _userVisits = [];
  bool _isLoading = true;
  VisitState? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _loadUserVisits();
  }

  Future<void> _loadUserVisits() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        final visits = await _visitDataService.getVisitDataByUserId(currentUser.id);
        setState(() {
          _userVisits = visits;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba načítání tras: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<VisitData> get _filteredVisits {
    if (_selectedFilter == null) return _userVisits;
    return _userVisits.where((visit) => visit.state == _selectedFilter).toList();
  }

  Map<VisitState, int> _getVisitStats() {
    final stats = <VisitState, int>{};
    for (final state in VisitState.values) {
      stats[state] = 0;
    }
    
    for (final visit in _userVisits) {
      stats[visit.state] = (stats[visit.state] ?? 0) + 1;
    }
    
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getVisitStats();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF111827),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                    'Mé trasy',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _statusChip('Všechny', _userVisits.length, null, _selectedFilter == null),
                  const SizedBox(width: 8),
                  _statusChip('Čekající', stats[VisitState.PENDING_REVIEW] ?? 0, VisitState.PENDING_REVIEW, _selectedFilter == VisitState.PENDING_REVIEW),
                  const SizedBox(width: 8),
                  _statusChip('Schválené', stats[VisitState.APPROVED] ?? 0, VisitState.APPROVED, _selectedFilter == VisitState.APPROVED),
                  const SizedBox(width: 8),
                  _statusChip('Odmítnuté', stats[VisitState.REJECTED] ?? 0, VisitState.REJECTED, _selectedFilter == VisitState.REJECTED),
                ],
              ),
            ),

            // Routes list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredVisits.isEmpty
                      ? const Center(
                          child: Text(
                            'Žádné trasy nenalezeny',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: _filteredVisits.length,
                          itemBuilder: (context, index) {
                            final visit = _filteredVisits[index];
                            return _buildRouteCard(visit, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, int count, VisitState? state, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = state;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(VisitData visit, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          onTap: () {
            _showRouteDetailsSheet(visit);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getStatusColor(visit.state).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        _getStatusIcon(visit.state),
                        color: _getStatusColor(visit.state),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.routeTitle ?? visit.visitedPlaces,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusText(visit.state),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(visit.state),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 18,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${visit.points.toStringAsFixed(1)} bodů',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const Spacer(),
                    if (visit.route != null && visit.route!['totalDistance'] != null)
                      Row(
                        children: [
                          Icon(
                            Icons.route_outlined,
                            size: 18,
                            color: const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${((visit.route!['totalDistance'] as num) / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (visit.visitDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${visit.visitDate!.day}.${visit.visitDate!.month}.${visit.visitDate!.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return const Color(0xFF10B981);
      case VisitState.PENDING_REVIEW:
        return const Color(0xFFF59E0B);
      case VisitState.REJECTED:
        return const Color(0xFFEF4444);
      case VisitState.DRAFT:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return Icons.check_circle_outline;
      case VisitState.PENDING_REVIEW:
        return Icons.schedule;
      case VisitState.REJECTED:
        return Icons.cancel_outlined;
      case VisitState.DRAFT:
        return Icons.edit_outlined;
    }
  }

  String _getStatusText(VisitState state) {
    switch (state) {
      case VisitState.APPROVED:
        return 'Schváleno';
      case VisitState.PENDING_REVIEW:
        return 'Čeká na schválení';
      case VisitState.REJECTED:
        return 'Odmítnuto';
      case VisitState.DRAFT:
        return 'Návrh';
    }
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
                      color: _getStatusColor(visit.state).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _getStatusIcon(visit.state),
                      color: _getStatusColor(visit.state),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.routeTitle ?? visit.visitedPlaces,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusText(visit.state),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(visit.state),
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
                    if (visit.dogName != null && visit.dogName!.isNotEmpty)
                      _buildDetailRow(Icons.pets, 'Jméno psa', visit.dogName!),
                    if (visit.routeDescription != null && visit.routeDescription!.isNotEmpty)
                      _buildDetailRow(Icons.description_outlined, 'Popis trasy', visit.routeDescription!),
                    if (visit.dogNotAllowed != null && visit.dogNotAllowed!.isNotEmpty)
                      _buildDetailRow(Icons.warning_outlined, 'Pes není povolen', visit.dogNotAllowed!),
                    if (visit.rejectionReason != null && visit.rejectionReason!.isNotEmpty)
                      _buildDetailRow(Icons.cancel_outlined, 'Důvod odmítnutí', visit.rejectionReason!),
                    if (visit.places.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Navštívená místa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...visit.places.map((place) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getPlaceTypeIcon(place.type),
                              color: const Color(0xFF6B7280),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                place.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
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

  IconData _getPlaceTypeIcon(PlaceType type) {
    switch (type) {
      case PlaceType.PEAK:
        return Icons.landscape;
      case PlaceType.TOWER:
        return Icons.location_city;
      case PlaceType.TREE:
        return Icons.park;
      case PlaceType.OTHER:
        return Icons.place;
    }
  }
}
