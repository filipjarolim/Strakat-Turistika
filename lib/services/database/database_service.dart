import 'dart:developer';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Db? _db;
  Future<bool>? _connectFuture;
  Future? _lock;

  /// Returns the database instance.
  Db? get db => _db;

  /// Returns true if connected.
  bool get isConnected => _db != null && _db!.state == State.OPEN;

  /// Connects to the database using the URL from .env.
  /// This version is aggressive with TLS for Emulator compatibility.
  Future<bool> connect() async {
    // Synchronization: if a connection attempt is already in progress, wait for it.
    if (_connectFuture != null) {
      return _connectFuture!;
    }

    _connectFuture = _internalConnect();
    try {
      final result = await _connectFuture!;
      return result;
    } finally {
      _connectFuture = null;
    }
  }

  Future<bool> _internalConnect() async {
    // If already connected, do a quick health check
    if (isConnected) {
      try {
        await _db!.getCollectionNames(); // Lightweight ping
        return true;
      } catch (e) {
        print('⚠️ [DatabaseService] Health check failed, reconnecting...');
        await close();
      }
    }

    try {
      await dotenv.load();
      var url = dotenv.env['DATABASE_URL'];

      if (url == null || url.isEmpty) {
        print('❌ [DatabaseService] DATABASE_URL not found in .env');
        return false;
      }

      // 1. Force TLS/SSL for Atlas compatibility on Emulator
      if (!url.contains('tls=') && !url.contains('ssl=')) {
        url += (url.contains('?') ? '&' : '?') + 'tls=true';
      }
      
      // 2. Add extra safety for self-signed or emulator-proxy certs if needed
      if (!url.contains('tlsAllowInvalidCertificates=')) {
        url += '&tlsAllowInvalidCertificates=true&tlsInsecure=true';
      }

      // 3. Ensure authSource is set for Atlas
      if (!url.contains('authSource=')) {
        url += '&authSource=admin';
      }
      
      // 4. Increase timeouts for flaky networks.
      if (!url.contains('connectTimeoutMS=')) {
        url += '&connectTimeoutMS=30000&socketTimeoutMS=30000&serverSelectionTimeoutMS=30000';
      }

      print('🔗 [DatabaseService] Connecting to MongoDB...');
      
      _db = await Db.create(url);
      
      // 5. Open with explicit secure flag
      // Wait for the primary to be ready
      await _db!.open(secure: true);
      
      // Give the driver a moment to establish background pool/connections
      // Atlas replica sets can take a moment to "settle" after the socket opens
      await Future.delayed(const Duration(milliseconds: 3000));

      // 6. Verify primary is ready (Wait for master)
      bool isReady = false;
      int retries = 15;
      while (!isReady && retries > 0) {
        try {
          await _db!.getCollectionNames(); // This forces a master check
          isReady = true;
        } catch (e) {
          final errorStr = e.toString();
          final isRetryable = errorStr.contains('No master connection') || 
                             errorStr.contains('connection closed') ||
                             errorStr.contains('reset by peer');

          if (isRetryable) {
            print('⏳ [DatabaseService] Waiting for stable connection (${16-retries}/15): $e');
            await Future.delayed(const Duration(milliseconds: 2000));
            retries--;
          } else {
            rethrow;
          }
        }
      }

      if (isReady) {
        final dbName = _db?.databaseName ?? 'unknown';
        print('✅ [DatabaseService] Connected to database: $dbName');
        return true;
      } else {
        print('❌ [DatabaseService] Timed out waiting for master connection');
        await close();
        return false;
      }
    } catch (e) {
      print('❌ [DatabaseService] Connection failed: $e');
      _db = null;
      return false;
    }
  }

  /// Centralized execution wrapper for DB operations.
  /// Handles auto-connection, master election wait, socket reset retries, and strict serialization.
  Future<T> execute<T>(Future<T> Function(Db db) operation) async {
    // 1. Strict Mutex Chain to prevent concurrent DB requests
    final prevLock = _lock;
    final completer = Completer();
    _lock = completer.future;
    
    if (prevLock != null) {
      await prevLock.catchError((_) => null);
    }

    try {
      return await _internalExecute(operation);
    } finally {
      completer.complete();
      // Only clear if we are still the latest lock in the chain
      if (_lock == completer.future) {
        _lock = null;
      }
    }
  }

  Future<T> _internalExecute<T>(Future<T> Function(Db db) operation) async {
    int attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        if (!isConnected) {
          final success = await connect();
          if (!success) throw Exception('Nepodařilo se připojit k databázi');
        }

        return await operation(_db!);
      } catch (e) {
        final errorStr = e.toString();
        final isRetryable = errorStr.contains('No master connection') || 
                           errorStr.contains('connection closed') ||
                           errorStr.contains('reset by peer');

        if (isRetryable && attempts < maxAttempts) {
          final waitMs = attempts * 200;
          print('🔄 [DatabaseService] Retrying in ${waitMs}ms...');
          
          await close(); // Close existing just in case it's a dirty state
          await Future.delayed(Duration(milliseconds: waitMs));
          continue;
        }
        
        print('❌ [DatabaseService] Operation failed permanently: $e');
        rethrow;
      }
    }
    throw Exception('Neočekávaná chyba při provádění databázové operace');
  }

  /// Get a collection by name.
  /// DEPRECATED: Prefer [execute] to handle connection resilience.
  Future<DbCollection?> getCollection(String name) async {
    return execute((db) async => db.collection(name));
  }

  /// Close the connection.
  Future<void> close() async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
  }
}
