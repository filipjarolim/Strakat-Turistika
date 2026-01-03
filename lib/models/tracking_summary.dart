import 'package:latlong2/latlong.dart';

class TrackPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed;
  final double accuracy;
  final double? heading;
  final double? altitude;
  final double? verticalAccuracy;
  
  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speed,
    required this.accuracy,
    this.heading,
    this.altitude,
    this.verticalAccuracy,
  });
  
  LatLng toLatLng() => LatLng(latitude, longitude);
  
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'accuracy': accuracy,
      'heading': heading,
      'altitude': altitude,
      'verticalAccuracy': verticalAccuracy,
    };
  }
  
  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      speed: json['speed']?.toDouble() ?? 0.0,
      accuracy: json['accuracy']?.toDouble() ?? 0.0,
      heading: json['heading']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      verticalAccuracy: json['verticalAccuracy']?.toDouble(),
    );
  }
}

class TrackingSummary {
  final bool isTracking;
  final DateTime? startTime;
  final Duration duration;
  final double totalDistance;
  final double averageSpeed;
  final double maxSpeed;
  final double totalElevationGain;
  final double totalElevationLoss;
  final double? minAltitude;
  final double? maxAltitude;
  final List<TrackPoint> trackPoints;
  
  TrackingSummary({
    required this.isTracking,
    required this.startTime,
    required this.duration,
    required this.totalDistance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.totalElevationGain,
    required this.totalElevationLoss,
    required this.minAltitude,
    required this.maxAltitude,
    required this.trackPoints,
  });
} 