import '../models/visit_data.dart';
import 'mongodb_service.dart';
import 'auth_service.dart';
import '../models/tracking_summary.dart';
import 'scoring_config_service.dart';

class VisitDataService {
  static final VisitDataService _instance = VisitDataService._internal();
  factory VisitDataService() => _instance;
  VisitDataService._internal();

  static const String _collectionName = 'visits';
  static bool _indexesEnsured = false;

  Future<void> _ensureIndexes() async {
    if (_indexesEnsured) return;
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) return;
      // Compound index to support common queries
      await collection.createIndex(keys: {
        'seasonYear': 1,
        'state': 1,
        'points': -1,
        'visitDate': -1,
        'createdAt': -1,
      });
      // Index for leaderboard aggregation
      await collection.createIndex(keys: {
        'seasonYear': 1,
        'userId': 1,
        'state': 1,
      });
      // Additional single-field indexes (id is already indexed)
      await collection.createIndex(keys: {'userId': 1});
      _indexesEnsured = true;
      // ignore: avoid_print
      print('✅ VisitData indexes ensured');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Failed to ensure indexes (non-fatal): $e');
    }
  }

  // Save visit data to database
  Future<bool> saveVisitData(VisitData visitData) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return false;
      }

      final visitDataMap = visitData.toMap();
      
      // Insert the visit data
      await collection.insertOne(visitDataMap);
      
      print('✅ Visit data saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving visit data: $e');
      return false;
    }
  }
  
  // Update existing visit data
  Future<bool> updateVisitData(VisitData visitData) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return false;
      }
      
      // Update the document
      final result = await collection.replaceOne(
        {'_id': visitData.id},
        visitData.toMap(),
      );
      
      if (result.isFailure) {
         print('❌ Failed to update visit data: ${result.errmsg}');
         return false;
      }
      
      print('✅ Visit data updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating visit data: $e');
      return false;
    }
  }

  // Leaderboard: cumulative points per user with pagination
  Future<Map<String, dynamic>> getLeaderboard({
    required int season,
    int page = 1,
    int limit = 50,
    String? searchQuery, // filter by user name
    bool sortByVisits = false, // when true, sort by visitsCount instead of totalPoints
  }) async {
    try {
      await _ensureIndexes();
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        return {'data': [], 'total': 0, 'page': page, 'limit': limit, 'hasMore': false};
      }

      final match = <String, Object>{
        'seasonYear': season,
        'state': VisitState.APPROVED.name,
      };

      final groupStage = <String, Object>{
        '_id': '\$groupKey',
        'totalPoints': {'\$sum': '\$points'},
        'visitsCount': {'\$sum': 1},
        'lastVisitDate': {'\$max': '\$visitDate'},
        'firstUserId': {'\$first': '\$userId'},
        // Capture possible display names from both extraPoints.fullName and legacy root fullName
        'firstFullName': {'\$first': '\$extraPoints.fullName'},
        'firstLegacyFullName': {'\$first': '\$fullName'},
      };

      final List<Map<String, Object>> pipelineBase = [
        {'\$match': match},
        // compute grouping key: prefer userId else extraPoints.fullName (legacy)
        {
          '\$addFields': <String, Object>{
            'groupKey': {
              // Prefer userId; if missing, fall back to extraPoints.fullName; then legacy root fullName
              '\$ifNull': <Object>[
                '\$userId',
                {
                  '\$ifNull': <Object>['\$extraPoints.fullName', '\$fullName']
                }
              ],
            },
          },
        },
        {'\$group': groupStage},
        // join user info by firstUserId if present
        {
          '\$lookup': <String, Object>{
            'from': 'users',
            'localField': 'firstUserId',
            'foreignField': '_id',
            'as': 'userDocs',
          }
        },
        {
          '\$addFields': <String, Object>{
            'user': {'\$first': '\$userDocs'},
            'displayName': {
              // Prefer actual user.name; else extraPoints.fullName; else legacy fullName
              '\$ifNull': <Object>[
                '\$user.name',
                {
                  '\$ifNull': <Object>['\$firstFullName', '\$firstLegacyFullName']
                }
              ],
            },
          }
        },
        {
          '\$project': <String, Object>{
            'userDocs': 0,
          }
        },
      ];

      // Count total groups
      final countPipeline = [
        ...pipelineBase,
        if (searchQuery != null && searchQuery.isNotEmpty)
          {
            '\$match': <String, Object>{
              'displayName': {
                '\$regex': searchQuery,
                '\$options': 'i',
              }
            }
          },
        {'\$count': 'total'},
      ];

      final countDocs = await collection.aggregateToStream(countPipeline.cast<Map<String, Object>>()).toList();
      final int total = countDocs.isNotEmpty ? (countDocs.first['total'] as int? ?? 0) : 0;

      // Data pipeline with sort/skip/limit
      final List<Map<String, Object>> dataPipeline = [
        ...pipelineBase,
        if (searchQuery != null && searchQuery.isNotEmpty)
          {
            '\$match': <String, Object>{
              'displayName': {
                '\$regex': searchQuery,
                '\$options': 'i',
              }
            }
          },
        {
          '\$sort': <String, Object>{
            if (sortByVisits) 'visitsCount': -1 else 'totalPoints': -1,
            'lastVisitDate': -1,
          },
        },
        {'\$skip': (page - 1) * limit},
        {'\$limit': limit},
      ];

      final documents = await collection.aggregateToStream(dataPipeline).toList();

      return {
        'data': documents,
        'total': total,
        'page': page,
        'limit': limit,
        'hasMore': page * limit < total,
        'totalPages': (total / limit).ceil(),
      };
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching leaderboard: $e');
      return {'data': [], 'total': 0, 'page': page, 'limit': limit, 'hasMore': false};
    }
  }

  // Get all visit data for admin review
  Future<List<VisitData>> getAllVisitData() async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available - database not connected');
        return [];
      }

      // Test the connection before attempting to fetch data
      final isConnected = await MongoDBService.testConnection();
      if (!isConnected) {
        print('❌ Database connection test failed');
        return [];
      }

      final documents = await collection.find().toList();
      return documents.map((doc) => VisitData.fromMap(doc)).toList();
    } catch (e) {
      print('❌ Error fetching visit data: $e');
      // Return empty list instead of throwing exception
      return [];
    }
  }

  // Get visit data by state
  Future<List<VisitData>> getVisitDataByState(VisitState state) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return [];
      }

      final documents = await collection.find({'state': state.name}).toList();
      return documents.map((doc) => VisitData.fromMap(doc)).toList();
    } catch (e) {
      print('❌ Error fetching visit data by state: $e');
      return [];
    }
  }

  // Get visit data by user ID
  Future<List<VisitData>> getVisitDataByUserId(String userId) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return [];
      }

      final documents = await collection.find({'userId': userId}).toList();
      return documents.map((doc) => VisitData.fromMap(doc)).toList();
    } catch (e) {
      print('❌ Error fetching visit data by user: $e');
      return [];
    }
  }

  // Get single visit by ID (full document with route/photos and user data)
  Future<VisitData?> getVisitById(String id) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return null;
      }
      
      // Use aggregation to include user data
      final pipeline = [
        {'\$match': {'_id': id}},
        // Join with User collection to get current user names
        {
          '\$lookup': <String, Object>{
            'from': 'users',
            'localField': 'userId',
            'foreignField': '_id',
            'as': 'userDocs',
          }
        },
        {
          '\$addFields': <String, Object>{
            'user': {'\$first': '\$userDocs'},
            'displayName': {
              // Prefer actual user.name; else extraPoints.fullName; else legacy fullName
              '\$ifNull': <Object>[
                '\$user.name',
                {
                  '\$ifNull': <Object>['\$extraPoints.fullName', '\$fullName']
                }
              ],
            },
          }
        },
        {
          '\$project': <String, Object>{
            'userDocs': 0, // Remove userDocs array, keep only user object
          },
        },
      ];
      
      final docs = await collection.aggregateToStream(pipeline).toList();
      if (docs.isEmpty) return null;
      
      return VisitData.fromMap(docs.first);
    } catch (e) {
      print('❌ Error fetching visit by id: $e');
      return null;
    }
  }

  // Update visit data state (for admin approval/rejection)
  Future<bool> updateVisitDataState(String visitDataId, VisitState newState, {String? rejectionReason}) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return false;
      }

      final updateData = {
        'state': newState.name,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

      final result = await collection.updateOne(
        {'_id': visitDataId},
        {'\$set': updateData},
      );

      if (result.isSuccess) {
        print('✅ Visit data state updated successfully');
        return true;
      } else {
        print('❌ Failed to update visit data state');
        return false;
      }
    } catch (e) {
      print('❌ Error updating visit data state: $e');
      return false;
    }
  }

  // Alias for backward compatibility/consistency
  Future<bool> updateVisitState(String visitId, VisitState newState, {String? rejectionReason}) {
    return updateVisitDataState(visitId, newState, rejectionReason: rejectionReason);
  }

  // Create visit data from GPS tracking
  Future<VisitData> createVisitDataFromTracking({
    required String routeTitle,
    required String routeDescription,
    required String visitedPlaces,
    required List<TrackPoint> trackPoints,
    required double totalDistance,
    required Duration duration,
    String? dogName,
    String? dogNotAllowed,
    String? routeLink,
    List<Map<String, dynamic>>? photos,
    int? peaksCount,
    int? towersCount,
    int? treesCount,
    List<Place>? places,
    Map<String, dynamic>? extraData,
    VisitState? overrideState,
  }) async {
    final currentUser = AuthService.currentUser;
    final now = DateTime.now();
    
    // Calculate points based on current scoring configuration
    final cfg = await ScoringConfigService().getConfig();
    final distanceKm = totalDistance / 1000.0; // decimals allowed
    final peaks = (peaksCount ?? 0);
    final towers = (towersCount ?? 0);
    final trees = (treesCount ?? 0);

    // Distance points
    double distancePoints = 0.0;
    if (distanceKm >= cfg.minDistanceKm) {
      distancePoints = distanceKm * cfg.pointsPerKm;
    }
    
    // Place points - using new place type keys
    double placePoints = 0.0;
    placePoints += (peaks * cfg.getPointsForPlaceType('PEAK'));
    placePoints += (towers * cfg.getPointsForPlaceType('TOWER'));
    placePoints += (trees * cfg.getPointsForPlaceType('TREE'));
    
    // Total points
    double totalPoints = 0.0;
    if (cfg.requireAtLeastOnePlace) {
      if ((peaks + towers + trees) > 0) {
        totalPoints = distancePoints + placePoints;
      }
    } else {
      totalPoints = distancePoints + placePoints;
    }
    
    // Round down to 1 decimal place
    totalPoints = (totalPoints * 10).floor() / 10;

    // Convert track points to route JSON
    final routeJson = {
      'trackPoints': trackPoints.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': point.timestamp.toIso8601String(),
        'speed': point.speed,
        'accuracy': point.accuracy,
      }).toList(),
      'totalDistance': totalDistance,
      'duration': duration.inSeconds,
      'startTime': trackPoints.isNotEmpty ? trackPoints.first.timestamp.toIso8601String() : null,
      'endTime': trackPoints.isNotEmpty ? trackPoints.last.timestamp.toIso8601String() : null,
    };

    // Extra points breakdown
    final extraPoints = {
      'scoringModel': 'configurable_v1',
      'config': {
        'pointsPerKm': cfg.pointsPerKm,
        'minDistanceKm': cfg.minDistanceKm,
        'requireAtLeastOnePlace': cfg.requireAtLeastOnePlace,
        'placeTypePoints': cfg.placeTypePoints,
      },
      'distanceKm': distanceKm,
      'distancePoints': distancePoints,
      'placePoints': placePoints,
      'peaks': peaks,
      'towers': towers,
      'trees': trees,
      'places': (visitedPlaces.isNotEmpty)
          ? visitedPlaces.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : [],
      'totalPoints': totalPoints,
      'durationMinutes': duration.inMinutes,
    };

    return VisitData(
      id: _generateId(),
      visitDate: now,
      routeTitle: routeTitle,
      routeDescription: routeDescription,
      dogName: dogName,
      points: totalPoints,
      visitedPlaces: visitedPlaces,
      dogNotAllowed: dogNotAllowed,
      routeLink: routeLink,
      route: routeJson,
      year: now.year,
      extraPoints: extraPoints,
      extraData: extraData,
      places: places ?? [],
      state: overrideState ?? VisitState.PENDING_REVIEW,
      createdAt: now,
      photos: photos,
      userId: currentUser?.id,
    );
  }

  // Generate unique ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  // Check if user is admin
  bool isUserAdmin() {
    final currentUser = AuthService.currentUser;
    return currentUser?.role == 'ADMIN';
  }

  // New paginated methods for better performance
  Future<Map<String, dynamic>> getPaginatedVisitData({
    int page = 1,
    int limit = 10,
    int? season,
    VisitState? state,
    String? userId,
    String? searchQuery,
    String sortBy = 'visitDate',
    bool sortDescending = true,
    double? minPoints,
    double? maxPoints,
    double? minDistance,
    double? maxDistance,
    String? user,
  }) async {
    try {
      await _ensureIndexes();
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return {
          'data': [],
          'total': 0,
          'page': page,
          'limit': limit,
          'hasMore': false,
        };
      }

      // Build filter criteria
      final filter = <String, dynamic>{};
      if (season != null) filter['seasonYear'] = season;
      if (state != null) filter['state'] = state.name;
      if (userId != null) filter['userId'] = userId;
              if (searchQuery != null && searchQuery.isNotEmpty) {
          filter['\$or'] = [
            {'routeTitle': {'\$regex': searchQuery, '\$options': 'i'}},
            {'visitedPlaces': {'\$regex': searchQuery, '\$options': 'i'}},
          ];
        }

        // Advanced filters
        if (minPoints != null) filter['points'] = {'\$gte': minPoints};
        if (maxPoints != null) {
          if (filter['points'] != null) {
            filter['points']['\$lte'] = maxPoints;
          } else {
            filter['points'] = {'\$lte': maxPoints};
          }
        }
        
        if (minDistance != null || maxDistance != null) {
          final distanceFilter = <String, dynamic>{};
          if (minDistance != null) distanceFilter['\$gte'] = minDistance; // distanceKm stored in km
          if (maxDistance != null) distanceFilter['\$lte'] = maxDistance;
          filter['extraPoints.distanceKm'] = distanceFilter;
        }
        
        if (user != null && user.isNotEmpty) {
          filter['userId'] = user;
        }

      // Build sort criteria
      final sort = <String, dynamic>{};
      switch (sortBy) {
        case 'visitDate':
          sort['visitDate'] = sortDescending ? -1 : 1;
          break;
        case 'points':
          sort['points'] = sortDescending ? -1 : 1;
          break;
        case 'routeTitle':
          sort['routeTitle'] = sortDescending ? -1 : 1;
          break;
        case 'createdAt':
          sort['createdAt'] = sortDescending ? -1 : 1;
          break;
        case 'state':
          sort['state'] = sortDescending ? -1 : 1;
          break;
        case 'displayName':
          sort['displayName'] = sortDescending ? -1 : 1;
          break;
        default:
          sort['visitDate'] = sortDescending ? -1 : 1;
      }

      // Get total count for pagination
      final totalCount = await collection.count(filter);

      // Calculate skip value for pagination
      final skip = (page - 1) * limit;

      // Use aggregation for efficient server-side filtering/sorting/pagination with user data
      final List<Map<String, Object>> pipeline = [
        if (filter.isNotEmpty)
          {
            '\$match': Map<String, Object>.from(filter),
          },
        // Join with User collection to get current user names
        {
          '\$lookup': <String, Object>{
            'from': 'users',
            'localField': 'userId',
            'foreignField': '_id',
            'as': 'userDocs',
          }
        },
        {
          '\$addFields': <String, Object>{
            'user': {'\$first': '\$userDocs'},
            'displayName': {
              // Prefer actual user.name; else extraPoints.fullName; else legacy fullName
              '\$ifNull': <Object>[
                '\$user.name',
                {
                  '\$ifNull': <Object>['\$extraPoints.fullName', '\$fullName']
                }
              ],
            },
          }
        },
        if (searchQuery != null && searchQuery.isNotEmpty)
          {
            '\$match': <String, Object>{
              'displayName': {
                '\$regex': searchQuery!,
                '\$options': 'i',
              }
            }
          },
        {
          '\$sort': Map<String, Object>.from(sort),
        },
        {
          '\$skip': skip,
        },
        {
          '\$limit': limit,
        },
        // Project out large fields we don't need in the list to reduce payload
        {
          '\$project': <String, Object>{
            'route': 0,
            'routeDescription': 0,
            'photos': 0,
            'userDocs': 0, // Remove userDocs array, keep only user object
          },
        },
      ];

      final documents = await collection.aggregateToStream(pipeline).toList();
      final data = documents.map((doc) => VisitData.fromMap(doc)).toList();

      return {
        'data': data,
        'total': totalCount,
        'page': page,
        'limit': limit,
        'hasMore': (skip + limit) < totalCount,
        'totalPages': (totalCount / limit).ceil(),
      };
    } catch (e) {
      print('❌ Error fetching paginated visit data: $e');
      return {
        'data': [],
        'total': 0,
        'page': page,
        'limit': limit,
        'hasMore': false,
      };
    }
  }

  // Get available seasons for filtering
  Future<List<int>> getAvailableSeasons() async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return [];
      }

      // Efficient distinct seasons via aggregation
      final List<Map<String, Object>> pipeline = [
        {
          '\$group': <String, Object>{
            '_id': '\$seasonYear',
          },
        },
        {
          '\$sort': <String, Object>{'_id': -1},
        },
      ];

      final docs = await collection.aggregateToStream(pipeline).toList();
      final seasons = <int>[];
      for (final d in docs) {
        final val = d['_id'];
        if (val == null) continue;
        if (val is int) {
          seasons.add(val);
        } else {
          seasons.add(int.parse(val.toString()));
        }
      }
      return seasons;
    } catch (e) {
      print('❌ Error fetching available seasons: $e');
      return [];
    }
  }

  // Get visit data statistics
  Future<Map<String, dynamic>> getVisitDataStats({
    int? season,
    String? userId,
  }) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return {};
      }

      final filter = <String, dynamic>{};
      if (season != null) filter['seasonYear'] = season;
      if (userId != null) filter['userId'] = userId;

      // Use a simple find operation instead of aggregate
      final documents = await collection.find(filter).toList();

      final stats = <String, dynamic>{};
      for (final doc in documents) {
        final state = doc['state'] as String?;
        if (state != null) {
          if (!stats.containsKey(state)) {
            stats[state] = {
              'count': 0,
              'totalPoints': 0.0,
            };
          }
          stats[state]['count'] = (stats[state]['count'] as int) + 1;
          
          // Sum points as doubles
          final pointsValue = doc['points'];
          double points = 0.0;
          if (pointsValue != null) {
            if (pointsValue is num) {
              points = pointsValue.toDouble();
            } else {
              final parsed = double.tryParse(pointsValue.toString());
              if (parsed != null) points = parsed;
            }
          }
          stats[state]['totalPoints'] = (stats[state]['totalPoints'] as double) + points;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Error fetching visit data stats: $e');
      return {};
    }
  }

  // Get current season's top 10 results
  Future<List<VisitData>> getCurrentSeasonTopResults({int limit = 10}) async {
    try {
      final currentYear = DateTime.now().year;
      final result = await getPaginatedVisitData(
        page: 1,
        limit: limit,
        season: currentYear,
        state: VisitState.APPROVED,
        sortBy: 'points',
        sortDescending: true,
      );
      
      return (result['data'] as List<dynamic>).cast<VisitData>();
    } catch (e) {
      print('❌ Error fetching current season top results: $e');
      return [];
    }
  }

  // Get season's top results (all users, all states)
  Future<List<VisitData>> getSeasonTopResults({required int season, int limit = 10}) async {
    try {
      final result = await getPaginatedVisitData(
        page: 1,
        limit: limit,
        season: season,
        state: null, // Load all states, not just approved
        sortBy: 'points',
        sortDescending: true,
      );
      
      return (result['data'] as List<dynamic>).cast<VisitData>();
    } catch (e) {
      print('❌ Error fetching season $season top results: $e');
      return [];
    }
  }

  // Delete visit data by ID
  Future<bool> deleteVisitData(String visitId) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return false;
      }

      final result = await collection.deleteOne({'_id': visitId});
      
      if (result.isSuccess && result.nRemoved > 0) {
        print('✅ Visit data deleted successfully');
        return true;
      } else {
        print('⚠️ Visit data not found or already deleted');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting visit data: $e');
      return false;
    }
  }

  // Update visit data points and place counts (admin function)
  Future<bool> updateVisitDataPoints(
    String visitId,
    double newPoints,
    int peaksCount,
    int towersCount,
    int treesCount,
  ) async {
    try {
      final collection = await MongoDBService.getCollection(_collectionName);
      if (collection == null) {
        print('❌ VisitData collection not available');
        return false;
      }

      // Build visited places string based on new counts
      final List<String> places = [];
      if (peaksCount > 0) places.add('${peaksCount}x Vrchol');
      if (towersCount > 0) places.add('${towersCount}x Rozhledna');
      if (treesCount > 0) places.add('${treesCount}x Strom');
      final visitedPlaces = places.isEmpty ? 'Žádné' : places.join(', ');

      // Recompute place points using current scoring config
      final cfg = await ScoringConfigService().getConfig();
      final recalculatedPlacePoints =
          (peaksCount * cfg.getPointsForPlaceType('PEAK')) +
          (towersCount * cfg.getPointsForPlaceType('TOWER')) +
          (treesCount * cfg.getPointsForPlaceType('TREE'));

      // Update the main points field and related data
      final updateResult = await collection.updateOne(
        {'_id': visitId},
        {
          '\$set': {
            'points': newPoints,
            'visitedPlaces': visitedPlaces,
            'extraPoints.peaks': peaksCount,
            'extraPoints.towers': towersCount,
            'extraPoints.trees': treesCount,
            'extraPoints.placePoints': recalculatedPlacePoints,
            'extraPoints.totalPoints': newPoints,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        },
      );

      if (updateResult.isSuccess) {
        print('✅ Visit data points updated successfully');
        return true;
      } else {
        print('⚠️ No changes made to visit data points');
        return false;
      }
    } catch (e) {
      print('❌ Error updating visit data points: $e');
      return false;
    }
  }
} 