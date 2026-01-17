import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../services/mongodb_service.dart';
import '../services/auth_service.dart';

class PlaceTypeConfig {
  final String id;
  final String name;
  final String label;
  final IconData icon;
  final int points;
  final Color color;
  final bool isActive;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const PlaceTypeConfig({
    required this.id,
    required this.name,
    required this.label,
    required this.icon,
    required this.points,
    required this.color,
    this.isActive = true,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  PlaceTypeConfig copyWith({
    String? id,
    String? name,
    String? label,
    IconData? icon,
    int? points,
    Color? color,
    bool? isActive,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) => PlaceTypeConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    label: label ?? this.label,
    icon: icon ?? this.icon,
    points: points ?? this.points,
    color: color ?? this.color,
    isActive: isActive ?? this.isActive,
    order: order ?? this.order,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'label': label,
    'icon': icon.codePoint,
    'points': points,
    'color': color.value,
    'isActive': isActive,
    'order': order,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };

  factory PlaceTypeConfig.fromMap(Map<String, dynamic> map) {
    // Default icon and color mappings
    final iconMap = {
      'PEAK': Icons.terrain,
      'TOWER': Icons.attractions,
      'TREE': Icons.park,
      'OTHER': Icons.place_outlined,
    };
    
    final colorMap = {
      'PEAK': Colors.orange,
      'TOWER': Colors.blue,
      'TREE': Colors.green,
      'OTHER': Colors.grey,
    };

    return PlaceTypeConfig(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      icon: iconMap[map['name']] ?? Icons.place_outlined,
      points: _safeIntFromMap(map['points']),
      color: Color(_safeIntFromMap(map['color']) ?? Colors.grey.value),
      isActive: map['isActive'] != false,
      order: _safeIntFromMap(map['order']),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      createdBy: map['createdBy']?.toString(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  static int _safeIntFromMap(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }
}

class PlaceTypeConfigService {
  static final PlaceTypeConfigService _instance = PlaceTypeConfigService._internal();
  factory PlaceTypeConfigService() => _instance;
  PlaceTypeConfigService._internal();

  static const String _collection = 'place_type_configs';

  Future<List<PlaceTypeConfig>> getPlaceTypeConfigs() async {
    try {
      print('🔍 Loading place type configs from MongoDB...');
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) {
        print('❌ MongoDB collection is null - database not connected');
        throw Exception('Database connection failed');
      }

      print('🔍 Querying collection: $_collection');
      final configs = await collection.find().toList();
      print('🔍 Found ${configs.length} raw configs in database');
      
      // If no configs exist, create default ones
      if (configs.isEmpty) {
        print('🔍 No configs found, creating default ones...');
        await _createDefaultPlaceTypeConfigs();
        return await getPlaceTypeConfigs(); // Recursive call
      }
      
      // Sort by order field and filter active ones
      configs.sort((a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));
      final result = configs.map((doc) => PlaceTypeConfig.fromMap(doc)).toList();
      final activeConfigs = result.where((config) => config.isActive).toList();
      
      print('🔍 Successfully loaded ${activeConfigs.length} active place type configs');
      return activeConfigs;
    } catch (e) {
      print('❌ Error loading place type configs: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow; // Let the caller handle the error
    }
  }

  Future<void> _createDefaultPlaceTypeConfigs() async {
    try {
      print('🔍 Creating default place type configs...');
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) {
        print('❌ Cannot create default configs - collection is null');
        return;
      }

      final now = DateTime.now();
      final defaultConfigs = [
        PlaceTypeConfig(
          id: 'PEAK',
          name: 'PEAK',
          label: 'Vrchol',
          icon: Icons.terrain,
          points: 1,
          color: Colors.orange,
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
        PlaceTypeConfig(
          id: 'TOWER',
          name: 'TOWER',
          label: 'Rozhledna',
          icon: Icons.attractions,
          points: 1,
          color: Colors.blue,
          order: 1,
          createdAt: now,
          updatedAt: now,
        ),
        PlaceTypeConfig(
          id: 'TREE',
          name: 'TREE',
          label: 'Památný strom',
          icon: Icons.park,
          points: 1,
          color: Colors.green,
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
        PlaceTypeConfig(
          id: 'OTHER',
          name: 'OTHER',
          label: 'Jiné',
          icon: Icons.place_outlined,
          points: 0,
          color: Colors.grey,
          order: 3,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      print('🔍 Inserting ${defaultConfigs.length} default configs...');
      final configsToSave = defaultConfigs.map((config) => config.toMap()).toList();
      await collection.insertAll(configsToSave);
      print('✅ Default place type configs created successfully');
    } catch (e) {
      print('❌ Error creating default place type configs: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<bool> savePlaceTypeConfigs(List<PlaceTypeConfig> configs) async {
    try {
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) return false;

      // Clear existing configs
      await collection.deleteMany({});

      // Insert new configs
      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final configsToSave = configs.map((config) {
        return config.copyWith(
          updatedAt: now,
          updatedBy: currentUser,
        ).toMap();
      }).toList();

      if (configsToSave.isNotEmpty) {
        await collection.insertAll(configsToSave);
      }

      return true;
    } catch (e) {
      print('❌ Error saving place type configs: $e');
      return false;
    }
  }

  Future<bool> updatePlaceTypeConfig(PlaceTypeConfig config) async {
    try {
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) return false;

      final currentUser = AuthService.currentUser?.id;
      final now = DateTime.now();
      
      final configToUpdate = config.copyWith(
        updatedAt: now,
        updatedBy: currentUser,
      );

      final result = await collection.replaceOne(
        {'id': config.id},
        configToUpdate.toMap(),
      );

      return result.isSuccess;
    } catch (e) {
      print('❌ Error updating place type config: $e');
      return false;
    }
  }

  Future<bool> reorderPlaceTypeConfigs(List<String> configIds) async {
    try {
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) return false;

      for (int i = 0; i < configIds.length; i++) {
        await collection.updateOne(
          {'id': configIds[i]},
          {'\$set': {'order': i}},
        );
      }

      return true;
    } catch (e) {
      print('❌ Error reordering place type configs: $e');
      return false;
    }
  }

  Future<bool> deletePlaceTypeConfig(String configId) async {
    try {
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) return false;

      final result = await collection.deleteOne({'id': configId});
      return result.isSuccess;
    } catch (e) {
      print('❌ Error deleting place type config: $e');
      return false;
    }
  }

  Future<bool> updatePlaceTypeStatus(String configId, bool isActive) async {
    try {
      final collection = await MongoDBService.getCollection(_collection);
      if (collection == null) return false;

      final result = await collection.updateOne(
        {'id': configId},
        {'\$set': {'isActive': isActive}},
      );

      return result.isSuccess;
    } catch (e) {
      print('❌ Error updating place type status: $e');
      return false;
    }
  }

  Future<bool> reorderPlaceTypes(List<String> configIds) async {
    return await reorderPlaceTypeConfigs(configIds);
  }
}
