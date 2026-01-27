import 'dart:io';
import 'package:flutter/material.dart';
import '../visit_data.dart';
import '../tracking_summary.dart';

class FormContext extends ChangeNotifier {
  // System Fields
  String? routeTitle;
  String? routeDescription;
  DateTime visitDate = DateTime.now();
  bool dogNotAllowed = false;
  
  // Data Objects
  TrackingSummary? trackingSummary;
  List<File> selectedImages = [];
  List<Place> places = [];
  
  // Dynamic Fields
  Map<String, dynamic> extraData = {};

  // Initialization
  void initializeWith({
    TrackingSummary? summary,
    VisitData? existingVisit,
  }) {
    if (summary != null) {
      trackingSummary = summary;
      visitDate = summary.startTime ?? DateTime.now();
    }
    
    if (existingVisit != null) {
      routeTitle = existingVisit.routeTitle;
      routeDescription = existingVisit.routeDescription;
      visitDate = existingVisit.visitDate ?? DateTime.now();
      dogNotAllowed = existingVisit.dogNotAllowed == 'true' || existingVisit.dogNotAllowed == 'on'; // web often sends string check
      places = List.from(existingVisit.places);
      extraData = Map.from(existingVisit.extraData ?? {});
      // Photos handling would ideally go here if we had File objects, 
      // but existing photos are usually URLs. We might need a separate 'existingPhotos' list.
    }
    notifyListeners();
  }

  void updateField(String key, dynamic value) {
    switch (key) {
      case 'routeTitle':
        routeTitle = value?.toString();
        break;
      case 'routeDescription':
        routeDescription = value?.toString();
        break;
      case 'visitDate':
        if (value is DateTime) visitDate = value;
        break;
      case 'dogNotAllowed':
        dogNotAllowed = value == true;
        break;
      default:
        extraData[key] = value;
    }
    notifyListeners();
  }

  void addPhoto(File file) {
    selectedImages.add(file);
    notifyListeners();
  }

  void removePhoto(File file) {
    selectedImages.remove(file);
    notifyListeners();
  }

  void updatePlaces(List<Place> newPlaces) {
    places = newPlaces;
    notifyListeners();
  }

  void setTrackingSummary(TrackingSummary summary) {
    trackingSummary = summary;
    notifyListeners();
  }
}
