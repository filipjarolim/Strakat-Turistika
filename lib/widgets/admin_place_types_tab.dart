import 'package:flutter/material.dart';
import '../models/place_type_config.dart';

class AdminPlaceTypesTab {
  static Widget build({
    required List<PlaceTypeConfig> placeTypes,
    required bool isLoading,
    required Function(PlaceTypeConfig) onEditPlaceType,
    required Function(String) onDeletePlaceType,
    required VoidCallback onManagePlaceTypes,
  }) {
    if (isLoading) {
      return _buildLoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Typy míst',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onManagePlaceTypes,
                      icon: const Icon(Icons.settings),
                      label: const Text('Spravovat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (placeTypes.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Žádné typy míst',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: placeTypes.length,
                    itemBuilder: (context, index) {
                      final placeType = placeTypes[index];
                      return _buildPlaceTypeCard(
                        placeType,
                        onEditPlaceType,
                        onDeletePlaceType,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  static Widget _buildPlaceTypeCard(
    PlaceTypeConfig placeType,
    Function(PlaceTypeConfig) onEdit,
    Function(String) onDelete,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            _getPlaceTypeIcon(placeType.name),
            color: const Color(0xFF6B7280),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placeType.label.isNotEmpty ? placeType.label : placeType.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  '${placeType.points} bodů',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onEdit(placeType),
            icon: const Icon(Icons.edit, size: 18),
            color: const Color(0xFF6B7280),
          ),
          IconButton(
            onPressed: () => onDelete(placeType.id),
            icon: const Icon(Icons.delete, size: 18),
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  static IconData _getPlaceTypeIcon(String placeType) {
    switch (placeType.toLowerCase()) {
      case 'peak':
        return Icons.landscape;
      case 'tower':
        return Icons.location_city;
      case 'tree':
        return Icons.park;
      default:
        return Icons.place;
    }
  }
}
