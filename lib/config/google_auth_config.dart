import 'package:flutter_dotenv/flutter_dotenv.dart';

// Google OAuth Configuration
// Reads credentials from .env file (same as Next.js app)

class GoogleAuthConfig {
  // Get Google OAuth Client ID from .env file
  static String get clientId => 
    dotenv.env['GOOGLE_CLIENT_ID'] ?? 'YOUR_GOOGLE_CLIENT_ID_HERE';
  
  // Get Google OAuth Client Secret from .env file
  static String get clientSecret => 
    dotenv.env['GOOGLE_CLIENT_SECRET'] ?? 'YOUR_GOOGLE_CLIENT_SECRET_HERE';
  
  // OAuth scopes
  static const List<String> scopes = ['email', 'profile'];
  
  // Check if configuration is complete
  static bool get isConfigured => 
    clientId != 'YOUR_GOOGLE_CLIENT_ID_HERE' && 
    clientId.isNotEmpty;
} 