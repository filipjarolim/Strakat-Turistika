import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static CloudinaryPublic? _cloudinary;
  
  static CloudinaryPublic get cloudinary {
    if (_cloudinary == null) {
      _cloudinary = CloudinaryPublic(
        dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
        'ffenzeso', // Use your existing unsigned preset
        cache: false,
      );
    }
    return _cloudinary!;
  }
  
  static Future<String?> uploadImage(File imageFile) async {
    try {
      // Check if file exists and is readable
      if (!await imageFile.exists()) {
        print('❌ Image file does not exist: ${imageFile.path}');
        return null;
      }
      
      // Get file size
      final fileSize = await imageFile.length();
      print('📁 File size: ${fileSize} bytes');
      
      // Try the public upload first
      try {
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageFile.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'strakataturistika', // Add folder for organization
          ),
        );
        
        print('✅ Image uploaded successfully: ${response.secureUrl}');
        return response.secureUrl;
      } catch (e) {
        print('❌ Public upload failed: $e');
        
        // Try multiple upload presets
        final presetResult = await _tryMultiplePresets(imageFile);
        if (presetResult != null) {
          return presetResult;
        }
        
        // Fallback to API key/secret method
        return await _uploadWithApiKey(imageFile);
      }
    } catch (e) {
      print('❌ Error uploading image to Cloudinary: $e');
      
      // More detailed error logging
      if (e.toString().contains('400')) {
        print('🔍 400 Error - This usually means:');
        print('   - Upload preset is not configured correctly');
        print('   - Cloudinary account settings issue');
        print('   - File format not supported');
      }
      
      return null;
    }
  }

  // Try multiple upload presets
  static Future<String?> _tryMultiplePresets(File imageFile) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (cloudName == null) return null;
    final presets = ['ffenzeso', 'ml_default', 'strakataturistika', 'unsigned'];
    
    for (final preset in presets) {
      try {
        print('🔄 Trying upload preset: $preset');
        
        final tempCloudinary = CloudinaryPublic(
          cloudName,
          preset,
          cache: false,
        );
        
        final response = await tempCloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageFile.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'strakataturistika',
          ),
        );
        
        print('✅ Upload successful with preset "$preset": ${response.secureUrl}');
        return response.secureUrl;
      } catch (e) {
        print('❌ Upload failed with preset "$preset": $e');
        continue;
      }
    }
    
    return null;
  }

  // Fallback upload method using API key/secret
  static Future<String?> _uploadWithApiKey(File imageFile) async {
    try {
      print('🔄 Trying API key upload method...');
      
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final apiKey = dotenv.env['CLOUDINARY_API_KEY'];
      final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];

      if (cloudName == null || apiKey == null || apiSecret == null) {
        print('❌ Cloudinary credentials missing in .env');
        return null;
      }
      
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      
      // Create the upload URL
      final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
      
      // Create form data with upload preset
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['upload_preset'] = 'ffenzeso' // Use your existing unsigned preset
        ..fields['folder'] = 'strakataturistika'
        ..fields['public_id'] = 'strakataturistika_${DateTime.now().millisecondsSinceEpoch}' // Add unique ID
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.jpg',
        ));
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final secureUrl = jsonResponse['secure_url'];
        print('✅ API key upload successful: $secureUrl');
        return secureUrl;
      } else {
        print('❌ API key upload failed: ${response.statusCode} - $responseBody');
        
        // Try without upload preset as last resort
        return await _uploadWithoutPreset(imageFile);
      }
    } catch (e) {
      print('❌ API key upload error: $e');
      return null;
    }
  }

  // Last resort: upload without preset (for testing)
  static Future<String?> _uploadWithoutPreset(File imageFile) async {
    try {
      print('🔄 Trying upload without preset...');
      
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final apiKey = dotenv.env['CLOUDINARY_API_KEY'];
      final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];
      
      if (cloudName == null || apiKey == null || apiSecret == null) {
         return null;
      }
      
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      
      // Create the upload URL
      final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
      
      // Create form data without upload preset
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString()
        ..fields['folder'] = 'strakataturistika'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.jpg',
        ));
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseBody);
        final secureUrl = jsonResponse['secure_url'];
        print('✅ Upload without preset successful: $secureUrl');
        return secureUrl;
      } else {
        print('❌ Upload without preset failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      print('❌ Upload without preset error: $e');
      return null;
    }
  }
  
  static Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      print('📤 Uploading image ${i + 1}/${imageFiles.length}');
      String? url = await uploadImage(imageFiles[i]);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    print('✅ Successfully uploaded ${uploadedUrls.length}/${imageFiles.length} images');
    return uploadedUrls;
  }
} 