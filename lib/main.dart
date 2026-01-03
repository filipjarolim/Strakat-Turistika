import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_theme.dart';
import 'config/app_colors.dart';
import 'animations/app_animations.dart';
import 'widgets/tab_switch.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'pages/explore_tab.dart';
import 'pages/map_tab.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notifications_service.dart';
import 'pages/webview_page.dart';
import 'services/mongodb_service.dart';


import 'services/auth_service.dart';
import 'services/visit_data_service.dart';


import 'pages/login_page.dart';
import 'pages/settings_page.dart';
import 'pages/admin_review_page.dart';
import 'pages/user_profile_page.dart';

import 'pages/visit_data_form_page.dart';
import 'pages/results_page.dart';

import 'models/tracking_summary.dart';
import 'services/haptic_service.dart';

import 'services/error_recovery_service.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/offline_ui_bridge.dart';
import 'services/app_update_service.dart';
import 'services/gps_services.dart'; // Added
import 'services/tracking_state_service.dart'; // Added

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize App Colors & Theme dependencies if needed (none for now)
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    
    // Initialize Crashlytics and Flutter error forwarding
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'Firebase init failed');
  }
  
  // Initialize MongoDB connection
  try {
    await MongoDBService.initialize();
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'Mongo init failed');
  }

  // Initialize Auth service
  try {
    await AuthService.initialize();
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'Auth init failed');
  }

  // Initialize new services
  try {

    await ErrorRecoveryService().initialize();
    // Notifications: background handler and service init
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationsService().initialize();
    
    // Initialize GPS Tracking Service immediately (even if not on map tab)
    // This allows pre-loading location and ensures permissions are checked
    try {
      final trackingStateService = TrackingStateService();
      await GpsServices.initializeEnhancedGPSTracking(trackingStateService);
    } catch (e) {
      print('⚠️ Extended GPS init failed in main: $e');
    }
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'Local services init failed');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strakatá Turistika',
      debugShowCheckedModeBanner: false,
      locale: const Locale('cs', 'CZ'),
      supportedLocales: const [
        Locale('cs', 'CZ'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      // Force text scale factor to 1.0, ignoring system font size settings
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
      home: const MyHomePage(),
      routes: {

        '/login': (context) => const LoginPage(),
        '/settings': (context) => const SettingsPage(),
        '/admin-review': (context) => const AdminReviewPage(),
        '/user-profile': (context) => const UserProfilePage(),
        '/visit-data-form': (context) {
          // Create a default tracking summary for the route
          final defaultSummary = TrackingSummary(
            isTracking: false,
            startTime: DateTime.now(),
            duration: const Duration(minutes: 30),
            totalDistance: 2500.0, // 2.5 km
            averageSpeed: 1.4, // m/s
            maxSpeed: 2.0, // m/s
            totalElevationGain: 0.0,
            totalElevationLoss: 0.0,
            minAltitude: null,
            maxAltitude: null,
            trackPoints: [],
          );
          return VisitDataFormPage(trackingSummary: defaultSummary);
        },
        '/tos': (context) => const WebViewPage(
              title: 'Podmínky použití',
              url: 'https://www.strakata.cz/terms',
            ),
        '/privacy': (context) => const WebViewPage(
              title: 'Zásady ochrany osobních údajů',
              url: 'https://www.strakata.cz/privacy',
            ),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  int _previousIndex = 0;
  int _slideDirection = 1; // 1 = slide from right, -1 = slide from left
  


  
  // Notification handling
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  final List<Widget> _pages = [
    const ExploreTab(),
    const ResultsPage(),
    const MapTab(),
    const UserProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer to handle app resume
    WidgetsBinding.instance.addObserver(this);
    

    
    // Create animations

    
    // Initialize notification handling
    _initializeNotificationHandling();
    // Listen for offline manager open requests
    OfflineUiBridge.openManager.addListener(() {
      if (OfflineUiBridge.openManager.value && mounted) {

        // Open settings and show the offline sheet
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        ).then((_) {
          // consume flag just in case
          OfflineUiBridge.consumeOpenManager();
        });
      }
    });
    
    // Check for app updates after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.checkForUpdate(context);
      }
    });
  }
  
  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app returns to foreground, reconnect to MongoDB
    if (state == AppLifecycleState.resumed) {
      _reconnectToDatabase();
    }
  }
  
  Future<void> _reconnectToDatabase() async {
    try {

      
      // Test if database is still connected
      final isConnected = await MongoDBService.testConnection();
      
      if (!isConnected) {
        await MongoDBService.reconnect();


      }
      
      // Always refresh user data from database when app resumes
      if (AuthService.isLoggedIn) {
        await AuthService.refreshCurrentUser();
      }
      
      // Refresh current page to reload data
      if (mounted) {
        setState(() {
          // Trigger rebuild to reload data on current page
        });
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, null, reason: 'Database reconnection failed');
    }
  }
  
  void _initializeNotificationHandling() {
    // Handle notification taps
    _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response);
      },
    );
  }
  
  void _handleNotificationTap(NotificationResponse response) {
    if (response.payload == 'gps_tracking_page') {
      // Switch to GPS tab instead of pushing a separate page
      _onNavItemTapped(2);
    }
  }

  void _onNavItemTapped(int index) async {
    if (index == _currentIndex) return;
    // Gate GPS tab for unauthenticated users
    if (index == 2 && AuthService.currentUser == null) {
      await HapticService.lightImpact();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
      return;
    }
    

    
    // Provide haptic feedback for navigation
    await HapticService.navigationTap();
    
    // Update the current index to trigger the animation
    setState(() {
      _previousIndex = _currentIndex;
      _slideDirection = index > _previousIndex ? 1 : -1;
      _currentIndex = index;

    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/mainBackground_optimized.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOut,
            opacity: _currentIndex == 0 ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.90),
                    Colors.black.withOpacity(0.75),
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                  ],
                  stops: const [0.0, 0.15, 0.32, 0.45, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedOpacity(
            duration: AppAnimations.durationPageTransition,
            curve: AppAnimations.curveStandard,
            opacity: _currentIndex == 0 ? 0.0 : 1.0,
            child: Container(color: const Color(0xFFFEFEFE)),
          ),
        ),
        Positioned.fill(
          child: Scaffold(
            extendBody: true, // Fixes navbar transparency issue by extending content behind it
            backgroundColor: Colors.transparent,
            body: TabSwitch(
              switchTo: _onNavItemTapped,
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.90),
                              Colors.black.withOpacity(0.75),
                              Colors.black.withOpacity(0.45),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.2),
                            ],
                            stops: const [0.0, 0.15, 0.32, 0.45, 0.8, 1.0],
                          ),
                        ),
                      ),
                      const ExploreTab(),
                    ],
                  ),
                  const ResultsPage(),
                  const MapTab(),
                  const UserProfilePage(),
                ],
              ),
            ),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavItemTapped,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody(int index) {
    return Stack(
      children: [
        if (index == 0)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.90),
                  Colors.black.withOpacity(0.75),
                  Colors.black.withOpacity(0.45),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.2),
                ],
                stops: const [0.0, 0.15, 0.32, 0.45, 0.8, 1.0],
              ),
            ),
          ),
        _pages[index],
      ],
    );
  }
}





