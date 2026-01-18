import 'dart:async';
import 'package:flutter/material.dart';
import '../services/visit_data_service.dart';
import '../models/visit_data.dart';
import '../models/leaderboard_entry.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/error_recovery_service.dart';
import 'user_visits_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/route_thumbnail.dart';
import 'visit_data_form_page.dart';
import '../models/tracking_summary.dart';
import '../services/auth_service.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsScreenshotPreview extends StatelessWidget {
  final Map<String, dynamic> photo;
  const _ResultsScreenshotPreview({Key? key, required this.photo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final url = (photo['url'] ?? '').toString();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF5F6F7),
                child: const Center(
                  child: Icon(Icons.broken_image, color: Color(0xFF9E9E9E), size: 48),
                ),
              ),
            ),
            // Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.watch, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'GPS Screenshot z hodinek',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsRoutePreview extends StatelessWidget {
  final List<dynamic> trackPoints;
  const _ResultsRoutePreview({Key? key, required this.trackPoints}) : super(key: key);

  LatLng _center() {
    if (trackPoints.isEmpty) return const LatLng(49.8175, 15.4730);
    double lat = 0, lng = 0;
    for (final p in trackPoints) {
      lat += (p['latitude'] as num).toDouble();
      lng += (p['longitude'] as num).toDouble();
    }
    lat /= trackPoints.length;
    lng /= trackPoints.length;
    return LatLng(lat, lng);
  }

  double _zoom() {
    if (trackPoints.length < 2) return 13.0;
    double minLat = (trackPoints.first['latitude'] as num).toDouble();
    double maxLat = minLat;
    double minLng = (trackPoints.first['longitude'] as num).toDouble();
    double maxLng = minLng;
    for (final p in trackPoints) {
      final la = (p['latitude'] as num).toDouble();
      final lo = (p['longitude'] as num).toDouble();
      if (la < minLat) minLat = la;
      if (la > maxLat) maxLat = la;
      if (lo < minLng) minLng = lo;
      if (lo > maxLng) maxLng = lo;
    }
    final span = (maxLat - minLat).abs() > (maxLng - minLng).abs()
        ? (maxLat - minLat).abs()
        : (maxLng - minLng).abs();
    if (span > 0.1) return 10.0;
    if (span > 0.05) return 11.0;
    if (span > 0.01) return 12.0;
    if (span > 0.005) return 13.0;
    return 14.0;
  }

  @override
  Widget build(BuildContext context) {
    final pts = trackPoints
        .map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: MapController(),
          options: MapOptions(
            initialCenter: _center(),
            initialZoom: _zoom(),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            FutureBuilder<bool>(
              future: ErrorRecoveryService().isNetworkAvailable(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'cz.strakata.turistika.strakataturistikaandroidapp',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (pts.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(points: pts, strokeWidth: 6, color: const Color(0xFF4CAF50)),
                ],
              ),
            if (pts.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: pts.first,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.trip_origin, color: Colors.white, size: 12),
                    ),
                  ),
                  if (pts.length > 1)
                    Marker(
                      point: pts.last,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultsPageState extends State<ResultsPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Data
  final VisitDataService _visitDataService = VisitDataService();
  List<int> availableSeasons = [];
  int? selectedSeason;

  // Paging state for the selected season
  final List<VisitData> _items = [];
  final List<LeaderboardEntry> _leaders = [];

  int _page = 1;
  final int _limit = 50; // tune for performance
  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String _sortBy = 'points';
  bool _sortDesc = true;
  // Always use approved results
  final VisitState _effectiveState = VisitState.APPROVED;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _showLeaderboard = true; // always show leaderboard only
  bool _sortLeaderboardByVisits = false;
  
  // Network state
  bool _isOnline = true;
  Timer? _networkTimer;

  // UI
  late final ScrollController _scrollController;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    _scrollController = ScrollController()..addListener(_onScroll);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
    
    // Start network monitoring
    _startNetworkMonitor();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSeasons();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _networkTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app returns to foreground, reload seasons if we have no data
    if (state == AppLifecycleState.resumed) {
      if (availableSeasons.isEmpty && !_isInitialLoading) {
        print('📱 App resumed in ResultsPage, reloading seasons...');
        _loadSeasons();
      }
    }
  }

  void _startNetworkMonitor() {
    // Initial check
    ErrorRecoveryService().isNetworkAvailable().then((available) {
      if (mounted) {
        _updateOnlineState(available);
      }
    });
    _networkTimer?.cancel();
    _networkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final available = await ErrorRecoveryService().isNetworkAvailable();
      if (mounted) {
        _updateOnlineState(available);
      }
    });
  }

  void _updateOnlineState(bool online) {
    if (_isOnline == online) return;
    setState(() {
      _isOnline = online;
    });
    
    // When coming back online, reload data if we have no data
    if (online && (_items.isEmpty && _leaders.isEmpty)) {
      _loadSeasons();
    }
  }

  Future<void> _loadSeasons() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
    });
    try {
      final seasons = await _visitDataService.getAvailableSeasons();
      if (!mounted) return;
      setState(() {
        availableSeasons = seasons;
        selectedSeason = seasons.isNotEmpty ? seasons.first : null;
      });
      if (_animationController != null) {
        _animationController!.forward();
      }
      if (selectedSeason != null) {
        await _reloadForCurrentFilters(resetScroll: true);
      } else {
        setState(() {
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading seasons: $e');
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });
      _showErrorSnackBar('Chyba načítání sezón');
    }
  }

  void _onScroll() {
    // Leaderboard loads all data at once, no pagination needed
    return;
  }

  Future<void> _reloadForCurrentFilters({bool resetScroll = false}) async {
    if (selectedSeason == null) return;
    setState(() {
      _isInitialLoading = true;
      _items.clear();
      _leaders.clear();
      _page = 1;
      _hasMore = true;
    });
    if (resetScroll) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    }
    await _loadNextLeaderboardPage();
    if (!mounted) return;
    setState(() {
      _isInitialLoading = false;
    });
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore || selectedSeason == null) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final result = await _visitDataService.getPaginatedVisitData(
        page: _page,
        limit: _limit,
        season: selectedSeason,
        state: _effectiveState,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        sortDescending: _sortDesc,
      );
      final data = (result['data'] as List<dynamic>).cast<VisitData>();
      final hasMore = result['hasMore'] == true;
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _hasMore = hasMore;
        _page += 1;
        _isLoadingMore = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading page: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      _showErrorSnackBar('Chyba načítání výsledků');
    }
  }

  Future<void> _loadNextLeaderboardPage() async {
    if (_isLoadingMore || selectedSeason == null) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final result = await _visitDataService.getLeaderboard(
        season: selectedSeason!,
        page: 1,
        limit: 10000, // Velký limit pro načtení všech záznamů
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        sortByVisits: _sortLeaderboardByVisits,
      );
      final raw = (result['data'] as List<dynamic>).cast<Map<String, dynamic>>();
      final data = raw.map((m) => LeaderboardEntry.fromMap(m)).toList();
      if (!mounted) return;

      setState(() {
        _leaders.clear(); // Vymazat existující data
        _leaders.addAll(data);
        _hasMore = false; // Už nejsou další data k načtení
        _isLoadingMore = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading leaderboard: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      _showErrorSnackBar('Chyba načítání žebříčku');
    }
  }

  void _showErrorSnackBar(String message) {
    AppToast.showError(context, message);
  }

  String _getStateText(VisitState state) {
    switch (state) {
      case VisitState.DRAFT:
        return 'Koncept';
      case VisitState.PENDING_REVIEW:
        return 'Čekající';
      case VisitState.APPROVED:
        return 'Schválené';
      case VisitState.REJECTED:
        return 'Odmítnuté';
    }
  }

  Color _getStateColor(VisitState state) {
    switch (state) {
      case VisitState.DRAFT:
        return const Color(0xFF666666);
      case VisitState.PENDING_REVIEW:
        return const Color(0xFFFF9800);
      case VisitState.APPROVED:
        return const Color(0xFF4CAF50);
      case VisitState.REJECTED:
        return const Color(0xFFF44336);
    }
  }

  Future<void> _handleEditVisit(VisitData visit) async {
    // Construct TrackingSummary from visit data
    final routeData = visit.route ?? {};
    final trackPointsData = (routeData['trackPoints'] as List?) ?? [];
    
    final List<TrackPoint> trackPoints = trackPointsData.map((p) {
       return TrackPoint.fromJson(Map<String, dynamic>.from(p));
    }).toList();
    
    final summary = TrackingSummary(
      isTracking: false,
      startTime: visit.visitDate ?? DateTime.now(),
      // Use duration to estimate end time
 
      duration: Duration(seconds: (routeData['duration'] as num?)?.toInt() ?? 0),
      totalDistance: (routeData['totalDistance'] as num?)?.toDouble() ?? 0.0,
      averageSpeed: (routeData['averageSpeed'] as num?)?.toDouble() ?? 0.0,
      maxSpeed: (routeData['maxSpeed'] as num?)?.toDouble() ?? 0.0,
      totalElevationGain: (routeData['totalElevationGain'] as num?)?.toDouble() ?? 0.0,
      totalElevationLoss: (routeData['totalElevationLoss'] as num?)?.toDouble() ?? 0.0,
      minAltitude: (routeData['minAltitude'] as num?)?.toDouble(),
      maxAltitude: (routeData['maxAltitude'] as num?)?.toDouble(),
      trackPoints: trackPoints,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VisitDataFormPage(
          trackingSummary: summary,
          existingVisit: visit,
        ),
      ),
    );
    
    // Always reload to reflect changes
    _reloadForCurrentFilters(resetScroll: false);
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        toolbarHeight: 70,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Žebříček',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -1.0,
                ),
              ),
              if (selectedSeason != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Sezóna $selectedSeason',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• Nejlepší turisti',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final url = Uri.parse('https://strakataturistika.vercel.app/pravidla');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.description_outlined, size: 20),
            label: const Text('Pravidla'),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF1A1A1A),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              backgroundColor: const Color(0xFFF3F4F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: IconButton(
              onPressed: () => _showFilterSheet(),
              icon: Icon(Icons.filter_list, color: AppColors.primary, size: 22),
              tooltip: 'Filtrovat',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: _isInitialLoading
          ? _buildInitialSkeleton()
          : availableSeasons.isEmpty
              ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                await _reloadForCurrentFilters(resetScroll: false);
              },
              color: AppColors.primary,
              backgroundColor: Colors.white,
              child: _buildLeaderboardList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppColors.primary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Žádné výsledky',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buďte první a zaznamenejte svůj výlet!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return _fadeAnimation != null
        ? FadeTransition(
            opacity: _fadeAnimation!,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              itemCount: _items.isEmpty ? 1 : _items.length + 1,
              itemBuilder: (context, index) {
                if (index < _items.length) {
                  return _buildResultCard(_items[index]);
                }
                // loader/footer
                if (_isLoadingMore) {
                  return _buildLoadMoreSkeleton();
                }
                if (!_hasMore && _items.isNotEmpty) {
                  return _buildEndOfList();
                }
                
                // If list is completely empty AND we are not initially loading (handled by _buildInitialSkeleton), show empty state inside the list
                if (_items.isEmpty && !_isInitialLoading && !_isLoadingMore) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildEmptyState(),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          )
        : const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4CAF50),
            ),
          );
  }

  Widget _buildLeaderboardList() {
    return _fadeAnimation != null
        ? FadeTransition(
            opacity: _fadeAnimation!,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              itemCount: _leaders.isEmpty ? 1 : _leaders.length + 1,
              itemBuilder: (context, index) {
                if (index < _leaders.length) {
                  return _buildLeaderCard(index + 1, _leaders[index]);
                }
                if (_isLoadingMore) return _buildLoadMoreSkeleton();
                if (!_hasMore && _leaders.isNotEmpty) return _buildEndOfList();
                
                 // Empty state for leaderboard
                if (_leaders.isEmpty && !_isInitialLoading && !_isLoadingMore) {
                   return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildEmptyState(),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          )
        : const Center(
            child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
          );
  }

  Widget _buildResultCard(VisitData result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final full = await _visitDataService.getVisitById(result.id);
            if (!mounted) return;
            _showRouteDetailsSheet(full ?? result);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail Area with Overlays
              Stack(
                children: [
                  RouteThumbnail(
                    visit: result,
                    height: 150,
                    borderRadius: 0,
                  ),
                  
                  // State Badge (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Container(
                             width: 8, height: 8,
                             decoration: BoxDecoration(
                               color: _getStateColor(result.state),
                               shape: BoxShape.circle,
                             ),
                           ),
                           const SizedBox(width: 6),
                           Text(
                            _getStateText(result.state),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Points Badge (Bottom Left)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700), // Gold
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.black, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${result.points.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Content Area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Title
                     Text(
                        _getShortVisitTitle(result),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                     ),
                     const SizedBox(height: 6),
                     
                     // User & Date & Actions
                     Row(
                       children: [
                         const Icon(Icons.person_outline, size: 14, color: Color(0xFF999999)),
                         const SizedBox(width: 4),
                         Flexible(
                           child: Text(
                              _displayUserName(result),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                           ),
                         ),
                         const SizedBox(width: 12),
                         const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF999999)),
                         const SizedBox(width: 4),
                         if (result.visitDate != null)
                           Text(
                             '${result.visitDate!.day}.${result.visitDate!.month}.${result.visitDate!.year}',
                             style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                           ),
                           
                         const Spacer(),
                         
                         // Trasa Button
                         if (result.route != null && (result.route!['trackPoints'] as List?)?.isNotEmpty == true)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: () => _showRoutePreview(result),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.map_outlined, size: 20, color: AppColors.primary),
                              ),
                            ),
                          ),

                         // Admin Edit Button
                         if (AuthService.currentUser?.role == UserRole.ADMIN.name)
                             Container(
                               margin: const EdgeInsets.only(left: 4),
                               child: InkWell(
                                 onTap: () => _handleEditVisit(result),
                                 borderRadius: BorderRadius.circular(8),
                                 child: const Padding(
                                   padding: EdgeInsets.all(6),
                                   child: Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                 ),
                               ),
                             ),
                       ],
                     ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayUserName(VisitData v) {
    // Prefer displayName computed from JOIN with User collection
    if (v.displayName != null && v.displayName!.isNotEmpty) {
      return v.displayName!;
    }
    
    // Fallback to user.name from JOIN data
    if (v.user != null && v.user!['name'] != null && v.user!['name'].toString().isNotEmpty) {
      return v.user!['name'].toString();
    }
    
    // Legacy fallback to extraPoints names
    final fromExtra = (v.extraPoints['fullName'] ?? v.extraPoints['displayName'] ?? '').toString().trim();
    if (fromExtra.isNotEmpty) return fromExtra;
    
    // Last resort fallback
    final uid = (v.userId ?? '').trim();
    return uid.isNotEmpty ? uid : 'Neznámý uživatel';
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

  void _showRoutePreview(VisitData visit) {
    final track = (visit.route?['trackPoints'] as List?) ?? [];
    
    // Check if this is a screenshot upload (no GPS data)
    final legacy = visit.photos ?? [];
    final firstPhoto = legacy.isNotEmpty ? legacy.first : null;
    final isScreenshot = track.isEmpty && firstPhoto != null && (
      (firstPhoto['title']?.toString().toLowerCase().contains('screenshot') ?? false) ||
      (firstPhoto['title']?.toString().toLowerCase().contains('watch') ?? false) ||
      (firstPhoto['description']?.toString().toLowerCase().contains('screenshot') ?? false)
    );
    
    if (track.isEmpty && !isScreenshot) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          margin: const EdgeInsets.only(top: 64),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 40,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isScreenshot ? 'GPS Screenshot' : 'Náhled trasy', 
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.5,
                            )
                          ),
                          if (!isScreenshot)
                            const SizedBox(height: 4),
                          if (!isScreenshot)
                            Text(
                              'Detail zaznamenané trasy',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFD700)),
                          const SizedBox(width: 4),
                          Text(
                            visit.points.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isScreenshot 
                    ? _ResultsScreenshotPreview(photo: firstPhoto!)
                    : _ResultsRoutePreview(trackPoints: track),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderCard(int rank, LeaderboardEntry entry) {
    final Color badgeColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFFE0E0E0);
    
    final Color rankTextColor = rank <= 3 ? Colors.white : const Color(0xFF6B7280);
    final Color rankBgColor = rank <= 3 ? badgeColor : Colors.transparent;
    final BoxBorder? rankBorder = rank <= 3 ? null : Border.all(color: const Color(0xFFE5E7EB), width: 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showUserVisitsFromLeaderboard(entry),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankBgColor,
                    shape: BoxShape.circle,
                    border: rankBorder,
                    boxShadow: rank <= 3 
                      ? [BoxShadow(color: badgeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                      : null,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: rankTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Avatar with premium border
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: rank <= 3 
                      ? LinearGradient(colors: [badgeColor, badgeColor.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF3F4F6),
                    backgroundImage: entry.userImage != null ? NetworkImage(entry.userImage!) : null,
                    child: entry.userImage == null
                        ? Icon(Icons.person_rounded, color: Colors.grey[400], size: 24)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.userName.isEmpty ? 'Neznámý uživatel' : entry.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (entry.dogName != null && entry.dogName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pets, size: 10, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.dogName!,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          if (entry.dogName != null && entry.dogName!.isNotEmpty) const SizedBox(width: 8),
                          if (entry.visitsCount > 0)
                            Text(
                              '${entry.visitsCount} výletů',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Points
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 18),
                          const SizedBox(width: 4),
                          Text(
                            entry.totalPoints.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'bodů',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seasons chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: availableSeasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final season = availableSeasons[index];
              final selected = season == selectedSeason;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: FilterChip(
                  label: Text(
                    'Sezóna $season',
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF4B5563),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide(
                      color: selected ? Colors.transparent : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  elevation: selected ? 4 : 0,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                  onSelected: (value) async {
                    if (value && selectedSeason != season) {
                      setState(() => selectedSeason = season);
                      await _reloadForCurrentFilters(resetScroll: true);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final double searchWidth = screenWidth.clamp(220.0, 480.0);
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildInitialSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => _skeletonCard(),
    );
  }

  Widget _buildLoadMoreSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _skeletonCard(),
          _skeletonCard(),
        ],
      ),
    );
  }

  Widget _buildEndOfList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '— Konec seznamu —',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBox(height: 16, width: 180),
                    const SizedBox(height: 8),
                    _skeletonBox(height: 12, width: 120),
                  ],
                ),
              ),
              _skeletonBox(height: 22, width: 80),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _skeletonBox(height: 18, width: 90),
              const SizedBox(width: 12),
              _skeletonBox(height: 12, width: 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F2),
        borderRadius: BorderRadius.circular(6),
      ),
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
                      color: _getStateColor(visit.state).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _getStateIcon(visit.state),
                      color: _getStateColor(visit.state),
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
                          _getStateText(visit.state),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getStateColor(visit.state),
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
                    _buildClickableUserRow(visit),
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

  IconData _getStateIcon(VisitState state) {
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

  Widget _buildModernIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Icon(
            icon,
            color: const Color(0xFF6B7280),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildClickableUserRow(VisitData visit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showUserVisits(visit),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.person, color: const Color(0xFF6B7280), size: 20),
              const SizedBox(width: 12),
              const Text(
                'Uživatel: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              Expanded(
                child: Text(
                  _displayUserName(visit),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserVisits(VisitData visit) {
    final userId = visit.userId;
    if (userId == null || userId.isEmpty) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserVisitsPage(
          userId: userId,
          userName: _displayUserName(visit),
        ),
      ),
    );
  }

  void _showUserVisitsFromLeaderboard(LeaderboardEntry entry) {
    final userId = entry.userId;
    if (userId.isEmpty) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserVisitsPage(
          userId: userId,
          userName: entry.userName,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 40,
              offset: Offset(0, -10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtrovat výsledky',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Vyberte sezónu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableSeasons.map((season) {
                final isSelected = season == selectedSeason;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: isSelected 
                      ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      : null,
                  ),
                  child: InkWell(
                    onTap: () async {
                      if (season != selectedSeason) {
                        setState(() => selectedSeason = season);
                        Navigator.pop(context);
                        await _reloadForCurrentFilters(resetScroll: true);
                      }
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        'Sezóna $season',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
} 