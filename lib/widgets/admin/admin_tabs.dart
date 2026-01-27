import 'package:flutter/material.dart';
import '../../models/visit_data.dart';
import '../../services/form_field_service.dart' as form_service;
import '../../services/scoring_config_service.dart';
import '../../models/place_type_config.dart';
import 'admin_control_tab.dart';
import 'admin_form_tab.dart';

class AdminTabs {
  // Control Tab - Visit Data Management
  static Widget buildControlTab({
    required List<VisitData> visitDataList,
    required bool isLoading,
    required bool isRefreshing,
    required Function(VisitData) onVisitTap,
    required VoidCallback onRefresh,
    required String searchQuery,
    required Function(String) onSearchChanged,
    required String sortBy,
    required Function(String) onSortChanged,
    required bool sortDesc,
    required VoidCallback onSortDirectionChanged,
    required bool isBulkMode,
    required Set<String> selectedVisitIds,
    required Function(String) onToggleVisitSelection,
    required VoidCallback onToggleBulkMode,
    required VoidCallback onShowAdminActivityLogs,
    required VoidCallback onBulkApprove,
    required VoidCallback onBulkReject,
    required TextEditingController searchController,
    required Function(VisitData) onShowRouteDetailsSheet,
  }) {
    return AdminControlTab.build(
      visitDataList: visitDataList,
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      onVisitTap: onVisitTap,
      onRefresh: onRefresh,
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      sortBy: sortBy,
      onSortChanged: onSortChanged,
      sortDesc: sortDesc,
      onSortDirectionChanged: onSortDirectionChanged,
      isBulkMode: isBulkMode,
      selectedVisitIds: selectedVisitIds,
      onToggleVisitSelection: onToggleVisitSelection,
      onToggleBulkMode: onToggleBulkMode,
      onShowAdminActivityLogs: onShowAdminActivityLogs,
      onBulkApprove: onBulkApprove,
      onBulkReject: onBulkReject,
      searchController: searchController,
      onShowRouteDetailsSheet: onShowRouteDetailsSheet,
    );
  }

  // Form Tab - Dynamic Form Management
  static Widget buildFormTab({
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
    // New place types section params
    required List<PlaceTypeConfig> placeTypes,
    required bool isPlaceTypesLoading,
    required Function(PlaceTypeConfig) onEditPlaceType,
    required Function(String) onDeletePlaceType,
    required VoidCallback onManagePlaceTypes,
    required Function(PlaceTypeConfig, bool) onTogglePlaceTypeStatus,
    // Collapsible state
    required bool isScoringExpanded,
    required bool isFormFieldsExpanded,
    required bool isPlaceTypesExpanded,
    required Function(bool) onScoringExpandedChanged,
    required Function(bool) onFormFieldsExpandedChanged,
    required Function(bool) onPlaceTypesExpandedChanged,
    required Function(int, int) onReorderFields,
    required Function(int, int) onReorderPlaceTypes,
  }) {
    return AdminFormTab.build(
      formFields: formFields,
      isLoading: isLoading,
      scoringConfig: scoringConfig,
      pointsPerKmController: pointsPerKmController,
      minDistanceKmController: minDistanceKmController,
      requireAtLeastOnePlace: requireAtLeastOnePlace,
      onRequireAtLeastOnePlaceChanged: onRequireAtLeastOnePlaceChanged,
      onPreview: onPreview,
      onAddField: onAddField,
      onEditField: onEditField,
      onDeleteField: onDeleteField,
      onSaveScoring: onSaveScoring,
      onSaveForm: onSaveForm,
      savingScoring: savingScoring,
      savingForm: savingForm,
      placeTypes: placeTypes,
      isPlaceTypesLoading: isPlaceTypesLoading,
      onEditPlaceType: onEditPlaceType,
      onDeletePlaceType: onDeletePlaceType,
      onManagePlaceTypes: onManagePlaceTypes,
      onTogglePlaceTypeStatus: onTogglePlaceTypeStatus,
      isScoringExpanded: isScoringExpanded,
      isFormFieldsExpanded: isFormFieldsExpanded,
      isPlaceTypesExpanded: isPlaceTypesExpanded,
      onScoringExpandedChanged: onScoringExpandedChanged,
      onFormFieldsExpandedChanged: onFormFieldsExpandedChanged,
      onPlaceTypesExpandedChanged: onPlaceTypesExpandedChanged,
      onReorderFields: onReorderFields,
      onReorderPlaceTypes: onReorderPlaceTypes,
    );
  }

}
