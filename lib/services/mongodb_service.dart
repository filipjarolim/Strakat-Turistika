import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoDBService {
  static MongoDBService? _instance;
  static MongoDBService get instance => _instance ??= MongoDBService._();
  MongoDBService._();

  static Db? _db;
  static bool _initialized = false;
  static DateTime? _lastConnectionCheck;
  static const Duration _connectionCheckInterval = Duration(minutes: 5);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  // Database configuration
  static const String _databaseUrl = 'mongodb+srv://jarolimfilip07:QSRNlqVjCJQW5g5F@cluster0.2x8zm.mongodb.net/strakataturistika?retryWrites=true&w=majority';
  static const String _fallbackDatabaseUrl = 'mongodb://localhost:27017/strakataturistika';
  
  // Initialize the database connection
  static Future<void> initialize({bool forceReconnect = false}) async {
    if (_initialized && !forceReconnect && _db != null) return;
    
    try {
      // Close existing connection if forcing reconnect
      if (forceReconnect && _db != null) {
        try {
          await _db!.close();
        } catch (e) {
          print('⚠️ Error closing existing connection: $e');
        }
        _db = null;
        _initialized = false;
      }
      
      // Try to load environment variables
      try {
        await dotenv.load();
      } catch (e) {
        print('⚠️ .env file not found, using fallback configuration');
      }
      
      // Get the database URL from environment variables or use a placeholder
      final databaseUrl = dotenv.env['DATABASE_URL'] ?? 'mongodb://localhost:27017/strakataturistika';
      
      if (databaseUrl == 'mongodb://localhost:27017/strakataturistika') {
        print('⚠️ Using fallback database URL. Please create a .env file with your DATABASE_URL');
        print('⚠️ App will continue without database connection - using local fallbacks');
        _initialized = true;
        return;
      }
      
      print('🔗 Attempting to connect to MongoDB: ${databaseUrl.substring(0, databaseUrl.indexOf('@') + 1)}***');
      
      // Connect to MongoDB
      _db = await Db.create(databaseUrl);
      await _db!.open();
      
      print('✅ Successfully connected to MongoDB');
      _initialized = true;
      _lastConnectionCheck = DateTime.now();
    } catch (e) {
      print('❌ Failed to connect to MongoDB: $e');
      print('ℹ️ App will continue without database connection');
      _initialized = true;
    }
  }
  
  // Get database instance
  static Db? get database => _db;
  
  // Reconnect to database
  static Future<void> _reconnect() async {
    try {
      print('🔄 Attempting to reconnect to MongoDB...');
      await initialize(forceReconnect: true);
    } catch (e) {
      print('❌ Failed to reconnect to MongoDB: $e');
    }
  }
  
  // Public method to force reconnection
  static Future<void> reconnect() async {
    await _reconnect();
  }

  // Check if database is available
  static bool get isAvailable => _db != null && _initialized;

  // Get a collection with connection health check and retry logic
  static Future<DbCollection?> getCollection(String collectionName) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _ensureConnection();
        if (_db == null) {
          print('⚠️ MongoDB not connected - returning null collection for $collectionName');
          return null;
        }
        return _db?.collection(collectionName);
      } catch (e) {
        print('❌ Error getting collection $collectionName (attempt $attempt/$_maxRetries): $e');
        if (attempt < _maxRetries) {
          print('⏳ Retrying in ${_retryDelay.inSeconds} seconds...');
          await Future.delayed(_retryDelay);
          await _reconnect();
        } else {
          print('❌ Max retries reached for collection $collectionName');
          return null;
        }
      }
    }
    return null;
  }
  
  // Ensure connection is healthy with better error handling
  static Future<void> _ensureConnection() async {
    if (_db == null) {
      await initialize();
      return;
    }
    
    // Check if we need to verify connection health
    final now = DateTime.now();
    if (_lastConnectionCheck == null || 
        now.difference(_lastConnectionCheck!) > _connectionCheckInterval) {
      _lastConnectionCheck = now;
      
      try {
        // Quick health check with timeout
        await _db!.getCollectionNames().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Connection health check timeout');
          },
        );
      } catch (e) {
        print('⚠️ Connection health check failed, attempting to reconnect: $e');
        if (e is TimeoutException || 
            e.toString().contains('connection') ||
            e.toString().contains('socket') ||
            e.toString().contains('master')) {
          await _reconnect();
        }
      }
    }
  }
  
  // Execute operation with retry logic
  static Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        await _ensureConnection();
        return await operation();
      } catch (e) {
        attempts++;
        print('❌ Operation failed (attempt $attempts/$_maxRetries): $e');
        
        if (attempts >= _maxRetries) {
          rethrow;
        }
        
        // Wait before retrying
        await Future.delayed(_retryDelay * attempts);
        
        // Try to reconnect on connection errors
        if (e.toString().contains('connection') || 
            e.toString().contains('master') ||
            e.toString().contains('socket')) {
          await _reconnect();
        }
      }
    }
    throw Exception('Operation failed after $_maxRetries attempts');
  }
  
  // Close the database connection
  static Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }
  
  // Simple test method to verify connection
  static Future<bool> testConnection() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      if (_db == null) {
        return false;
      }
      
      // Try to list collections to test the connection
      final collections = await _db!.getCollectionNames();
      print('📊 Available collections: $collections');
      return true;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }
  
  // Debug method to log user data
  static Future<void> logUserData() async {
    try {
      if (_db == null) {
        print('❌ Database not connected');
        return;
      }
      
      final userCollection = _db!.collection('User');
      final users = await userCollection.find().take(5).toList();
      
      print('👥 === USER DATA DEBUG ===');
      print('📊 Total users found: ${users.length}');
      
      for (int i = 0; i < users.length; i++) {
        final user = users[i];
        print('👤 User ${i + 1}:');
        print('   ID: ${user['_id']}');
        print('   Name: ${user['name'] ?? 'N/A'}');
        print('   Email: ${user['email'] ?? 'N/A'}');
        print('   Created: ${user['createdAt'] ?? 'N/A'}');
        print('   Updated: ${user['updatedAt'] ?? 'N/A'}');
        print('   ---');
      }
      
      if (users.isEmpty) {
        print('ℹ️ No users found in the database');
      }
    } catch (e) {
      print('❌ Error fetching user data: $e');
    }
  }
  
  // Debug method to log account data
  static Future<void> logAccountData() async {
    try {
      if (_db == null) {
        print('❌ Database not connected');
        return;
      }
      
      final accountCollection = _db!.collection('Account');
      final accounts = await accountCollection.find().take(5).toList();
      
      print('🏦 === ACCOUNT DATA DEBUG ===');
      print('📊 Total accounts found: ${accounts.length}');
      
      for (int i = 0; i < accounts.length; i++) {
        final account = accounts[i];
        print('🏦 Account ${i + 1}:');
        print('   ID: ${account['_id']}');
        print('   User ID: ${account['userId'] ?? 'N/A'}');
        print('   Type: ${account['type'] ?? 'N/A'}');
        print('   Provider: ${account['provider'] ?? 'N/A'}');
        print('   Provider Account ID: ${account['providerAccountId'] ?? 'N/A'}');
        print('   ---');
      }
      
      if (accounts.isEmpty) {
        print('ℹ️ No accounts found in the database');
      }
    } catch (e) {
      print('❌ Error fetching account data: $e');
    }
  }
  
  // Combined debug method to log both user and account data
  static Future<void> logAllData() async {
    await logUserData();
    print('');
    await logAccountData();
  }
} 