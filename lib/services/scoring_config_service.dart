import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'mongodb_service.dart';
import 'auth_service.dart';

class ScoringConfig {
  final String id;
  final double pointsPerKm;
  final double minDistanceKm;
  final bool requireAtLeastOnePlace;
  final Map<String, double> placeTypePoints; // Dynamické body za různé typy míst
  final bool active;
  final DateTime updatedAt;
  final String? updatedBy;

  const ScoringConfig({
    required this.id,
    required this.pointsPerKm,
    required this.minDistanceKm,
    required this.requireAtLeastOnePlace,
    required this.placeTypePoints,
    required this.active,
    required this.updatedAt,
    this.updatedBy,
  });

  ScoringConfig copyWith({
    String? id,
    double? pointsPerKm,
    double? minDistanceKm,
    bool? requireAtLeastOnePlace,
    Map<String, double>? placeTypePoints,
    bool? active,
    DateTime? updatedAt,
    String? updatedBy,
  }) => ScoringConfig(
        id: id ?? this.id,
        pointsPerKm: pointsPerKm ?? this.pointsPerKm,
        minDistanceKm: minDistanceKm ?? this.minDistanceKm,
        requireAtLeastOnePlace: requireAtLeastOnePlace ?? this.requireAtLeastOnePlace,
        placeTypePoints: placeTypePoints ?? this.placeTypePoints,
        active: active ?? this.active,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy ?? this.updatedBy,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': 'active',
        'pointsPerKm': pointsPerKm,
        'minDistanceKm': minDistanceKm,
        'requireAtLeastOnePlace': requireAtLeastOnePlace,
        'placeTypePoints': placeTypePoints,
        'active': active,
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': updatedBy,
      };

  static ScoringConfig fromMap(Map<String, dynamic> map) {
    // Zpětná kompatibilita - pokud existují staré pole, převedeme je na novou mapu
    Map<String, double> placeTypePoints = {};
    
    if (map['placeTypePoints'] != null) {
      // Nová verze s mapou
      final pointsMap = map['placeTypePoints'] as Map<String, dynamic>;
      pointsMap.forEach((key, value) {
        if (value is num) {
          placeTypePoints[key] = value.toDouble();
        }
      });
    } else {
      // Stará verze - převedeme na novou mapu
      placeTypePoints = {
        'vrchol': (map['peakPoints'] as num?)?.toDouble() ?? 1.0,
        'rozhledna': (map['towerPoints'] as num?)?.toDouble() ?? 1.0,
        'strom': (map['treePoints'] as num?)?.toDouble() ?? 1.0,
      };
    }
    
    return ScoringConfig(
      id: map['id']?.toString() ?? 'default_scoring_config',
      pointsPerKm: (map['pointsPerKm'] as num?)?.toDouble() ?? 1.0,
      minDistanceKm: (map['minDistanceKm'] as num?)?.toDouble() ?? 3.0,
      requireAtLeastOnePlace: map['requireAtLeastOnePlace'] == true,
      placeTypePoints: placeTypePoints,
      active: map['active'] == true,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    return ScoringConfig(
      id: json['id'],
      pointsPerKm: (json['pointsPerKm'] as num).toDouble(),
      minDistanceKm: (json['minDistanceKm'] as num).toDouble(),
      requireAtLeastOnePlace: json['requireAtLeastOnePlace'] as bool,
      placeTypePoints: Map<String, double>.from(
        json['placeTypePoints'] as Map
      ),
      active: json['active'] as bool,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedBy: json['updatedBy']?.toString(),
    );
  }
}

class ScoringConfigService {
  static final ScoringConfigService _instance = ScoringConfigService._internal();
  factory ScoringConfigService() => _instance;
  ScoringConfigService._internal();

  static const String _collection = 'scoring_configs';

  Future<ScoringConfig> getConfig() async {
    final collection = await MongoDBService.getCollection(_collection);
    if (collection == null) {
      return _defaultConfig();
    }
    final doc = await collection.findOne({'active': true});
    if (doc == null) return _defaultConfig();
    return ScoringConfig.fromMap(doc);
  }

  Future<bool> saveConfig(ScoringConfig config) async {
    try {
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) return false;
      final updatedBy = AuthService.currentUser?.id;
      final toSave = config.copyWith(updatedAt: DateTime.now(), updatedBy: updatedBy).toMap();

      // First, deactivate all existing configs
      await collection.updateMany(
        {'active': true}, 
        {'\$set': {'active': false}}
      );

      // Use modifier builder; setOnInsert for id and set each field explicitly
      var modifier = mongo.modify.setOnInsert('id', config.id);
      final fieldsToSet = Map<String, dynamic>.from(toSave)..remove('id');
      fieldsToSet.forEach((k, v) {
        modifier = modifier.set(k, v);
      });

      await collection.updateOne({'id': config.id}, modifier, upsert: true);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Failed to save scoring config: $e');
      return false;
    }
  }

  ScoringConfig _defaultConfig() => ScoringConfig(
        id: 'default_scoring_config',
        pointsPerKm: 2.0,
        minDistanceKm: 3.0,
        requireAtLeastOnePlace: true,
        placeTypePoints: {
          'PEAK': 1.0,
          'TOWER': 1.0,
          'TREE': 1.0,
          'OTHER': 0.0,
        },
        active: true,
        updatedAt: DateTime.now(),
        updatedBy: null,
      );

}

// Helper metody pro práci s place type points
extension ScoringConfigHelpers on ScoringConfig {
  double getPointsForPlaceType(String placeType) {
    return placeTypePoints[placeType] ?? 0.0;
  }

  void addPlaceTypePoints(String placeType, double points) {
    placeTypePoints[placeType] = points;
  }

  void removePlaceTypePoints(String placeType) {
    placeTypePoints.remove(placeType);
  }

  List<String> getPlaceTypes() {
    return placeTypePoints.keys.toList();
  }

  bool hasPlaceType(String placeType) {
    return placeTypePoints.containsKey(placeType);
  }
}



