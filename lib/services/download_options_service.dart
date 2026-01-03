import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Download options for users to choose between different zoom levels and speeds
class DownloadOptionsService {
  static const String _downloadOptionKey = 'download_option';
  static const String _downloadCompletedKey = 'download_completed';
  
  // Download options
  static const String optionSmall = 'small'; // Zoom 5-13, current speed
  static const String optionLarge = 'large'; // Zoom 5-17, enhanced speed
  
  // Stream controllers for option changes
  static final StreamController<String> _optionController = 
      StreamController<String>.broadcast();
  
  static Stream<String> get optionStream => _optionController.stream;
  
  /// Get current download option
  static Future<String> getCurrentOption() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadOptionKey) ?? optionSmall; // Default to small
  }
  
  /// Set download option
  static Future<void> setDownloadOption(String option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadOptionKey, option);
    _optionController.add(option);
    print('🗺️ Download option set to: $option');
  }
  
  /// Get download configuration based on option
  static Map<String, dynamic> getDownloadConfig(String option) {
    switch (option) {
      case optionSmall:
        return {
          'name': 'Small Download',
          'description': 'Optimized download with good detail',
          'minZoom': 5,
          'maxZoom': 13,
          'batchSize': 100, // CPU optimized (was 250)
          'batchDelay': 3, // CPU optimized (was 1)
          'zoomDelay': 10, // CPU optimized (was 2)
          'estimatedSize': '500MB - 1GB',
          'estimatedTime': '3-5 minutes', // CPU optimized
          'tileCount': '~500K tiles',
        };
      case optionLarge:
        return {
          'name': 'Large Download',
          'description': 'Maximum detail with optimized speed',
          'minZoom': 5,
          'maxZoom': 17,
          'batchSize': 200, // CPU optimized (was 500)
          'batchDelay': 3, // CPU optimized (was 1)
          'zoomDelay': 5, // CPU optimized (was 1)
          'estimatedSize': '2-4GB',
          'estimatedTime': '5-8 minutes', // CPU optimized
          'tileCount': '~2M tiles',
        };
      default:
        return getDownloadConfig(optionSmall);
    }
  }
  
  /// Check if download is completed for current option
  static Future<bool> isDownloadCompleted(String option) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_downloadCompletedKey}_$option') ?? false;
  }
  
  /// Mark download as completed for option
  static Future<void> markDownloadCompleted(String option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_downloadCompletedKey}_$option', true);
    print('🗺️ Download completed for option: $option');
  }
  
  /// Get download progress for option
  static Future<Map<String, dynamic>> getDownloadProgress(String option) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = prefs.getDouble('download_progress_$option') ?? 0.0;
    final downloadedTiles = prefs.getInt('downloaded_tiles_$option') ?? 0;
    final totalTiles = prefs.getInt('total_tiles_$option') ?? 0;
    
    return {
      'progress': progress,
      'downloadedTiles': downloadedTiles,
      'totalTiles': totalTiles,
      'isCompleted': await isDownloadCompleted(option),
    };
  }
  
  /// Save download progress for option
  static Future<void> saveDownloadProgress(String option, double progress, int downloadedTiles, int totalTiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('download_progress_$option', progress);
    await prefs.setInt('downloaded_tiles_$option', downloadedTiles);
    await prefs.setInt('total_tiles_$option', totalTiles);
  }
  
  /// Clear download progress for option
  static Future<void> clearDownloadProgress(String option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('download_progress_$option');
    await prefs.remove('downloaded_tiles_$option');
    await prefs.remove('total_tiles_$option');
    await prefs.remove('${_downloadCompletedKey}_$option');
  }
  
  /// Get all download options
  static List<Map<String, dynamic>> getAllOptions() {
    return [
      getDownloadConfig(optionSmall),
      getDownloadConfig(optionLarge),
    ];
  }
  
  /// Get recommended option based on device capabilities
  static Future<String> getRecommendedOption() async {
    // For now, default to small for better user experience
    // In the future, we could check device storage, network speed, etc.
    return optionSmall;
  }
} 