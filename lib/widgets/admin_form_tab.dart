import 'package:flutter/material.dart';
import '../services/form_field_service.dart' as form_service;
import '../services/scoring_config_service.dart';
import '../models/place_type_config.dart';
import 'admin_widgets.dart';
import 'ui/glass_ui.dart';
class AdminFormTab {
  static Widget build({
    required List<form_service.FormField> formFields,
    required bool isLoading,
    required ScoringConfig? scoringConfig,
    required TextEditingController pointsPerKmController,
    required TextEditingController minDistanceKmController,
    required bool requireAtLeastOnePlace,
    required Function(bool?) onRequireAtLeastOnePlaceChanged,
    required VoidCallback onPreview,
    required VoidCallback onAddField,
    required Function(form_service.FormField) onEditField,
    required Function(String) onDeleteField,
    required VoidCallback onSaveScoring,
    required VoidCallback onSaveForm,
    required bool savingScoring,
    required bool savingForm,
    // Place types (moved in as a new section from the Place Types tab)
    required List<PlaceTypeConfig> placeTypes,
    required bool isPlaceTypesLoading,
    required Function(PlaceTypeConfig) onEditPlaceType,
    required Function(String) onDeletePlaceType,
    required VoidCallback onManagePlaceTypes,
    required Function(PlaceTypeConfig, bool) onTogglePlaceTypeStatus,
    // Collapsible state callbacks
    required bool isScoringExpanded,
    required bool isFormFieldsExpanded,
    required bool isPlaceTypesExpanded,
    required Function(bool) onScoringExpandedChanged,
    required Function(bool) onFormFieldsExpandedChanged,
    required Function(bool) onPlaceTypesExpandedChanged,
    required Function(int, int) onReorderFields,
    required Function(int, int) onReorderPlaceTypes,
  }) {
    if (isLoading || isPlaceTypesLoading) {
      return _buildLoadingState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scoring Configuration Section
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onScoringExpandedChanged(!isScoringExpanded),
                        child: Row(
                          children: [
                            const Text(
                              'Konfigurace bodování',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GlassButton(
                      onPressed: () => onScoringExpandedChanged(!isScoringExpanded),
                      type: GlassButtonType.secondary,
                      icon: isScoringExpanded ? Icons.expand_less : Icons.expand_more,
                      child: const SizedBox.shrink(), // Icon only
                    ),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isScoringExpanded ? null : 0,
                  child: isScoringExpanded ? Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildScoringField(
                              'Body za km',
                              Icons.route_outlined,
                              pointsPerKmController,
                              'Např. 2.5',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildScoringField(
                              'Min. vzdálenost (km)',
                              Icons.straighten,
                              minDistanceKmController,
                              'Např. 1.0',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: requireAtLeastOnePlace,
                            onChanged: onRequireAtLeastOnePlaceChanged,
                          ),
                          const Text('Vyžadovat alespoň jedno místo'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          GlassButton(
                            onPressed: savingScoring ? null : onSaveScoring,
                            type: GlassButtonType.primary,
                            icon: savingScoring ? null : Icons.save,
                            child: Text(savingScoring ? 'Ukládání...' : 'Uložit bodování'),
                          ),
                          const SizedBox(width: 12),
                          GlassButton(
                            onPressed: onPreview,
                            type: GlassButtonType.secondary,
                            icon: Icons.preview,
                            child: const Text('Náhled'),
                          ),
                        ],
                      ),
                    ],
                  ) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Form Fields Section
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onFormFieldsExpandedChanged(!isFormFieldsExpanded),
                        child: Row(
                          children: [
                            const Text(
                              'Pole formuláře',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GlassButton(
                      onPressed: onAddField,
                      type: GlassButtonType.primary,
                      icon: Icons.add,
                      child: const Text('Přidat'),
                    ),
                    const SizedBox(width: 8),
                    GlassButton(
                      onPressed: () => onFormFieldsExpandedChanged(!isFormFieldsExpanded),
                      type: GlassButtonType.secondary,
                      icon: isFormFieldsExpanded ? Icons.expand_less : Icons.expand_more,
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isFormFieldsExpanded ? null : 0,
                  child: isFormFieldsExpanded ? Column(
                    children: [
                      const SizedBox(height: 16),
                      if (formFields.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Žádná pole formuláře',
                              style: TextStyle(
                                fontSize: 16,
                                  color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: formFields.length,
                          onReorder: onReorderFields,
                          itemBuilder: (context, index) {
                            final field = formFields[index];
                            return KeyedSubtree(
                              key: ValueKey(field.id),
                              child: AdminWidgets.buildFormFieldCard(
                                field: field,
                                onEdit: () => onEditField(field),
                                onDelete: () => onDeleteField(field.id),
                                onReorder: () {}, // Handled by list/drag handle
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      // Locked visited places card at the end
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.lock, size: 18, color: Color(0xFF9E9E9E)),
                            SizedBox(width: 12),
                            Icon(Icons.place, color: Color(0xFF4CAF50), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Navštívená místa (uzamčeno)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          GlassButton(
                            onPressed: savingForm ? null : onSaveForm,
                            type: GlassButtonType.primary,
                            icon: savingForm ? null : Icons.save,
                            child: Text(savingForm ? 'Ukládání...' : 'Uložit formulář'),
                          ),
                        ],
                      ),
                    ],
                  ) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          // Place Types Section
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onPlaceTypesExpandedChanged(!isPlaceTypesExpanded),
                        child: Row(
                          children: [
                            const Text(
                              'Typy míst',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassButton(
                      onPressed: () => onPlaceTypesExpandedChanged(!isPlaceTypesExpanded),
                      type: GlassButtonType.secondary,
                      icon: isPlaceTypesExpanded ? Icons.expand_less : Icons.expand_more,
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isPlaceTypesExpanded ? null : 0,
                  child: isPlaceTypesExpanded ? Column(
                    children: [
                      const SizedBox(height: 16),
                      if (placeTypes.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Žádné typy míst',
                              style: TextStyle(
                                fontSize: 16,
                                  color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: placeTypes.length,
                          onReorder: onReorderPlaceTypes,
                          itemBuilder: (context, index) {
                            final placeType = placeTypes[index];
                            return KeyedSubtree(
                              key: ValueKey(placeType.id),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24, right: 8),
                                    child: ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_indicator, color: Color(0xFF9AA5B1)),
                                    ),
                                  ),
                                  Expanded(
                                    child: AdminWidgets.buildPlaceTypeCard(
                                      placeType: placeType,
                                      onEdit: () => onEditPlaceType(placeType),
                                      onDelete: () => onDeletePlaceType(placeType.id),
                                      onToggleStatus: (v) => onTogglePlaceTypeStatus(placeType, v),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ) : const SizedBox.shrink(),
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
      child: CircularProgressIndicator(
        color: Color(0xFF4CAF50),
      ),
    );
  }

  static Widget _buildScoringField(String label, IconData icon, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF666666)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                                  color: Color(0xFF666666),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4CAF50)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

}
