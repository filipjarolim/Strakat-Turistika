import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import '../services/tracking_state_service.dart';
import '../services/haptic_service.dart';
import '../services/logging_service.dart';
import '../utils/gps_utils.dart';
import '../models/tracking_summary.dart';
import '../services/visit_data_service.dart';
import '../models/visit_data.dart';

class GpsServices {
  static Future<void> checkPermissions(BuildContext context) async {
    try {
      final locationPermission = await Permission.location.status;
      final locationAlwaysPermission = await Permission.locationAlways.status;
      
      // Check if we need to guide user to settings for always permission
      if (locationPermission.isGranted && !locationAlwaysPermission.isGranted) {
        _showAlwaysPermissionDialog(context);
      } else if (locationPermission.isPermanentlyDenied) {
        _showPermissionDialog(context);
      }
    } catch (e) {
      LoggingService().log('Permission check failed: $e', level: 'ERROR');
    }
  }

  static void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Povolení GPS'),
        content: const Text('Pro sledování polohy je potřeba povolit přístup k GPS.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Nastavení'),
          ),
        ],
      ),
    );
  }

  static void _showAlwaysPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Povolení GPS - Vždy'),
        content: const Text(
          'Pro správné fungování sledování GPS v pozadí je potřeba povolit přístup k poloze "Vždy". '
          'Přejděte do nastavení a změňte oprávnění z "Pouze při používání aplikace" na "Vždy".'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Později'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Nastavení'),
          ),
        ],
      ),
    );
  }

  static void _showGPSDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 12),
            Text('GPS je vypnuto'),
          ],
        ),
        content: const Text(
          'Pro trackování trasy musíte zapnout GPS služby na vašem zařízení. '
          'Přejděte do nastavení a zapněte polohu.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Otevřít nastavení'),
          ),
        ],
      ),
    );
  }

  static Future<bool> showPrePermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oprávnění polohy'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pro správné fungování aplikace na pozadí je nutné nastavit:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '1. V následujícím okně vyberte "Povolit v nastavení" nebo "Allow in settings".',
            ),
            SizedBox(height: 8),
            Text(
              '2. Poté vyberte možnost "Vždy" (Allow all the time).',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
            SizedBox(height: 12),
            Text(
              'Pokud vyberete pouze "Při používání aplikace", trasování se při zhasnutí displeje vypne!',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rozumím, pokračovat'),
          ),
        ],
      ),
    ) ?? false;
  }

  static void _showBackgroundLocationWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('DŮLEŽITÉ!', style: TextStyle(color: Colors.red))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trackování běží, ale NEBUDE fungovat se zamčenou obrazovkou!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '❌ "Allow only while using the app" = trackování se ZASTAVÍ při zamčení',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(
              '✅ "Allow all the time" = trackování funguje i se zamčenou obrazovkou',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4CAF50)),
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              'JAK TO OPRAVIT:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 8),
            Text('1. Klikněte na "Otevřít nastavení"'),
            Text('2. Najděte "Location" / "Poloha"'),
            Text('3. Změňte na "Allow all the time"'),
            Text('   (česky: "Vždy povolit")'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nechci trackovat na pozadí'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Otevřít nastavení'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> initializeNotifications() async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload == 'gps_tracking_page') {
            // Navigation will be handled by main.dart
          }
        },
      );
    } catch (e) {
      LoggingService().log('Notification initialization failed: $e', level: 'ERROR');
    }
  }

  static Future<void> initializeEnhancedGPSTracking(TrackingStateService trackingStateService) async {
    try {
      await trackingStateService.initialize();
      print('Tracking State Service initialized');
    } catch (e) {
      LoggingService().log('Tracking State Service initialization failed: $e', level: 'ERROR');
    }
  }

  static Future<void> initializeCompass({
    required Function(double?) setDeviceHeading,
    required Function(StreamSubscription?) setCompassSubscription,
  }) async {
    try {
      // Get initial heading
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      if (currentPosition.heading != null) {
        setDeviceHeading(currentPosition.heading);
        print('Initial compass heading: ${currentPosition.heading}°');
      }
      
      // Start listening to compass updates
      final compassSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 8),
        ),
      ).listen(
        (Position position) {
          if (position.heading != null) {
            setDeviceHeading(position.heading);
            print('Compass heading: ${position.heading}°');
          }
        },
        onError: (error) {
          print('Compass error: $error');
        },
      );
      
      setCompassSubscription(compassSubscription);
      print('Compass initialized');
    } catch (e) {
      print('Failed to initialize compass: $e');
    }
  }

  static Future<void> startTracking({
    required TrackingStateService trackingStateService,
    required BuildContext context,
    required VoidCallback onSuccess,
  }) async {
    try {
      // Note: GPS service check is now done in gps_page.dart before calling this
      
      // Start tracking (permissions will be requested inside)
      final success = await trackingStateService.startTracking();
      if (success) {
        HapticService.lightImpact();
        onSuccess();
        
        // After successful start, check if background location is granted
        // If not, show a warning dialog
        final locationAlwaysStatus = await Permission.locationAlways.status;
        if (!locationAlwaysStatus.isGranted) {
          // Delay the dialog a bit so it doesn't interfere with the start animation
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              _showBackgroundLocationWarningDialog(context);
            }
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chyba při spuštění sledování: Nedostatečná oprávnění'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      LoggingService().log('Failed to start tracking: $e', level: 'ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba při spuštění sledování: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> stopTracking({
    required TrackingStateService trackingStateService,
    required BuildContext context,
    required VoidCallback onSuccess,
    required Function(TrackingSummary, String?) showTrackingSummary,
  }) async {
    try {
      await trackingStateService.stopTracking();
      
      HapticService.mediumImpact();
      onSuccess();
      
      final trackingSummary = trackingStateService.getSummary();
      if (trackingSummary.trackPoints.isNotEmpty) {
        // Offer: Save as draft now or fill details now
        // Default: save as DRAFT immediately for safety
        try {
          final visit = await VisitDataService().createVisitDataFromTracking(
            routeTitle: 'Trasa ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
            routeDescription: 'GPS trasa',
            visitedPlaces: '',
            trackPoints: trackingSummary.trackPoints,
            totalDistance: trackingSummary.totalDistance,
            duration: trackingSummary.duration,
            photos: const [],
            overrideState: VisitState.DRAFT,
          );
          await VisitDataService().saveVisitData(visit);
          // Show summary with clear actions, pass draft id
          showTrackingSummary(trackingSummary, visit.id);
        } catch (_) {
          // Fallback without draft id
          showTrackingSummary(trackingSummary, null);
        }
      }
      
      // Stop toast removed per request
    } catch (e) {
      LoggingService().log('Failed to stop tracking: $e', level: 'ERROR');
    }
  }

  static Future<void> checkGPSStatus(BuildContext context) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      
      print('GPS Status:');
      print('Service enabled: $serviceEnabled');
      print('Permission: $permission');
      
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS služby jsou vypnuté. Zapněte GPS v nastavení.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      LoggingService().log('GPS status check failed: $e', level: 'ERROR');
    }
  }

  static Future<void> forceLocationUpdate({
    required TrackingStateService trackingStateService,
    required Function(LatLng?, double?, double?, double?) setLocationData,
    required Function(LatLng) moveMap,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Add position to tracking service if tracking is active
      if (trackingStateService.isTracking) {
        trackingStateService.forceAddPosition(position);
      }
      
      final location = LatLng(position.latitude, position.longitude);
      setLocationData(location, position.speed, position.altitude, position.heading);
      
      if (location != null) {
        moveMap(location);
      }
    } catch (e) {
      LoggingService().log('Location update failed: $e', level: 'ERROR');
    }
  }

  static Future<void> addTestTrackPoint(TrackingStateService trackingStateService) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      trackingStateService.forceAddPosition(position);
      HapticService.lightImpact();
    } catch (e) {
      LoggingService().log('Failed to add test point: $e', level: 'ERROR');
    }
  }

  static Future<void> addDebugTrackPoints({
    required TrackingStateService trackingStateService,
    required BuildContext context,
  }) async {
    try {
      // Create a smart route with smooth curves and direction changes
      final List<LatLng> debugPoints = GpsUtils.generateSmartRoute();
      
      // Add each point to the tracking service
      for (final point in debugPoints) {
        final position = Position(
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 200.0,
          altitudeAccuracy: 5.0,
          heading: 90.0,
          headingAccuracy: 5.0,
          speed: 5.0,
          speedAccuracy: 1.0,
        );
        
        trackingStateService.forceAddPosition(position);
        await Future.delayed(const Duration(milliseconds: 100)); // Small delay between points
      }
      
      HapticService.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bug_report, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '🐛 Smart route with smooth curves added',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      LoggingService().log('Failed to add debug track points: $e', level: 'ERROR');
    }
  }

  static Future<void> restartTracking(TrackingStateService trackingStateService) async {
    try {
      await trackingStateService.stopTracking();
      final success = await trackingStateService.startTracking();
      if (success) {
        HapticService.mediumImpact();
      }
    } catch (e) {
      LoggingService().log('Failed to restart tracking: $e', level: 'ERROR');
    }
  }

  static void checkTrackingStatus(TrackingStateService trackingStateService) {
    final summary = trackingStateService.getSummary();
    print('Tracking Status:');
    print('Is tracking: ${trackingStateService.isTracking}');
    print('Background service running: ${summary.isTracking}');
    print('Track points: ${summary.trackPoints.length}');
    print('Total distance: ${summary.totalDistance}m');
    print('Duration: ${summary.duration}');
  }

  static Future<void> testCompass({
    required Function(double?) setDeviceHeading,
  }) async {
    try {
      print('Testing compass detection...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (position.heading != null) {
        setDeviceHeading(position.heading);
        print('Updated device heading to: ${position.heading}°');
      } else {
        print('No heading data available - trying alternative method');
        // Try to get heading from device orientation
        try {
          final orientation = await Geolocator.getLastKnownPosition();
          if (orientation?.heading != null) {
            setDeviceHeading(orientation!.heading);
            print('Updated device heading from last known position: ${orientation!.heading}°');
          }
        } catch (e) {
          print('Alternative compass method failed: $e');
        }
      }
    } catch (e) {
      print('Compass test failed: $e');
    }
  }
} 