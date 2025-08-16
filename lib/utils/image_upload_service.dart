
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

class ImageUploadService {
  static const String baseUrl = 'https://bhbgroup.me';
  static const String uploadEndpoint = '$baseUrl/api/upload_image.php';
  
  // إضافة حدود للصور
  static const int _maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int _maxImageDimension = 1920;
  static const int _webMaxImageDimension = 1200;
  static const int _compressionQuality = 80;
  
  /// رفع صورة واحدة إلى الخادم
  static Future<String?> uploadSingleImage(File imageFile) async {
    try {
      // معالجة الصورة قبل الرفع
      final processedFile = await _processImageForUpload(imageFile);
      if (processedFile == null) {
        print('Failed to process image for upload');
        return null;
      }
      
      final bytes = await processedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse(uploadEndpoint),
        body: {
          'image': base64Image,
          'filename': processedFile.path.split('/').last,
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return responseData['url'];
        }
      }
      
      print('Upload failed with status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error uploading single image: $e');
      return null;
    }
  }
  
  /// رفع عدة صور إلى الخادم
  static Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    final List<String> uploadedUrls = [];
    
    try {
      // معالجة الصور في مجموعات لتجنب استهلاك الذاكرة
      const int batchSize = 3;
      
      for (int i = 0; i < imageFiles.length; i += batchSize) {
        final end = (i + batchSize < imageFiles.length) ? i + batchSize : imageFiles.length;
        final batch = imageFiles.sublist(i, end);
        
        // معالجة المجموعة
        final batchUrls = await _processBatch(batch);
        uploadedUrls.addAll(batchUrls);
        
        // تنظيف الذاكرة بين المجموعات
        if (kIsWeb) {
          // إجبار جمع القمامة في الويب
          print('Batch processed, cleaning memory...');
        }
      }
      
      return uploadedUrls;
    } catch (e) {
      print('Error uploading multiple images: $e');
      return uploadedUrls; // إرجاع ما تم رفعه بنجاح
    }
  }
  
  /// معالجة مجموعة من الصور
  static Future<List<String>> _processBatch(List<File> imageFiles) async {
    final List<String> urls = [];
    
    for (final imageFile in imageFiles) {
      try {
        final url = await uploadSingleImage(imageFile);
        if (url != null) {
          urls.add(url);
        }
      } catch (e) {
        print('Error processing image in batch: $e');
        // الاستمرار مع الصور الأخرى
      }
    }
    
    return urls;
  }
  
  /// معالجة الصورة للرفع
  static Future<File?> _processImageForUpload(File imageFile) async {
    try {
      // فحص حجم الملف
      final fileSize = await imageFile.length();
      
      if (fileSize > _maxImageSize) {
        print('Image too large, compressing...');
        return await _compressImage(imageFile);
      }
      
      // فحص أبعاد الصورة
      final dimensions = await _getImageDimensions(imageFile);
      if (dimensions.width > _getMaxDimension() || dimensions.height > _getMaxDimension()) {
        print('Image dimensions too large, resizing...');
        return await _resizeImage(imageFile);
      }
      
      return imageFile;
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }
  
  /// ضغط الصورة
  static Future<File?> _compressImage(File imageFile) async {
    try {
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        '${imageFile.path}_compressed.jpg',
        quality: _compressionQuality,
        minWidth: _getMaxDimension(),
        minHeight: _getMaxDimension(),
      );
      
      if (compressedFile != null) {
        return File(compressedFile.path);
      }
      
      return null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }
  
  /// تغيير حجم الصورة
  static Future<File?> _resizeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      final maxDimension = _getMaxDimension();
      final resizedImage = img.copyResize(
        image,
        width: image.width > image.height ? maxDimension : null,
        height: image.height > image.width ? maxDimension : null,
      );
      
      final resizedBytes = img.encodeJpg(resizedImage, quality: _compressionQuality);
      final tempFile = File('${imageFile.path}_resized.jpg');
      await tempFile.writeAsBytes(resizedBytes);
      
      return tempFile;
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }
  
  /// الحصول على أبعاد الصورة
  static Future<img.Image> _getImageDimensions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Could not decode image');
    }
    
    return image;
  }
  
  /// الحصول على الحد الأقصى للأبعاد
  static int _getMaxDimension() {
    return kIsWeb ? _webMaxImageDimension : _maxImageDimension;
  }
  
  /// ضغط الصورة للحصول على أداء أفضل
  static Future<File?> compressImageForPerformance(File imageFile) async {
    try {
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        '${imageFile.path}_performance.jpg',
        quality: 70, // جودة منخفضة للأداء
        minWidth: 800,
        minHeight: 800,
      );
      
      if (compressedFile != null) {
        return File(compressedFile.path);
      }
      
      return null;
    } catch (e) {
      print('Error compressing image for performance: $e');
      return null;
    }
  }
  
  /// تنظيف الملفات المؤقتة
  static Future<void> cleanupTempFiles(List<File> tempFiles) async {
    for (final file in tempFiles) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting temp file: $e');
      }
    }
  }
}
