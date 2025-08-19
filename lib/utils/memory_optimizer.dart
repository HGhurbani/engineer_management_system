import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'concurrent_operations_manager.dart';
import 'advanced_image_cache_manager.dart';

/// معالج الصور المحسن للأداء العالي
class EnhancedImageProcessor {
  static const int _maxConcurrentDownloads = 5;
  static const int _maxConcurrentProcessing = 3;
  static const int _batchSize = 10;
  static const Duration _downloadTimeout = Duration(seconds: 30);
  
  // إعدادات ضغط الصور حسب العدد
  static const Map<int, Map<String, int>> _compressionSettings = {
    50: {'dimension': 800, 'quality': 85},    // أقل من 50 صورة
    100: {'dimension': 600, 'quality': 75},   // 50-100 صورة
    200: {'dimension': 400, 'quality': 65},   // 100-200 صورة
    500: {'dimension': 300, 'quality': 55},   // 200-500 صورة
    1000: {'dimension': 200, 'quality': 45},  // أكثر من 500 صورة
  };
  
  /// معالجة مجموعة من الصور بشكل متوازي مع استخدام الكاش
  static Future<Map<String, String>> processImagesBatch({
    required List<String> imageUrls,
    required Directory tempDir,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('جاري تحليل الصور...');
      
      // تحديد إعدادات الضغط حسب عدد الصور
      final settings = _getCompressionSettings(imageUrls.length);
      onStatusUpdate?.call('سيتم ضغط الصور إلى ${settings['dimension']}x${settings['dimension']} بجودة ${settings['quality']}%');
      
      // تقسيم الصور إلى دفعات
      final batches = _splitIntoBatches(imageUrls, _batchSize);
      final Map<String, String> processedImages = {};
      int completedBatches = 0;
      
      onStatusUpdate?.call('جاري معالجة ${batches.length} دفعة من الصور...');
      
      // معالجة كل دفعة بشكل متوازي
      for (final batch in batches) {
        final batchResults = await _processBatchWithCache(
          batch, 
          tempDir, 
          settings,
          onProgress: (progress) {
            final totalProgress = (completedBatches + progress) / batches.length;
            onProgress?.call(totalProgress);
          },
        );
        
        processedImages.addAll(batchResults);
        completedBatches++;
        
        // إعطاء فرصة لجامع القمامة
        if (kIsWeb) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      onStatusUpdate?.call('تم معالجة ${processedImages.length} صورة بنجاح');
      return processedImages;
      
    } catch (e) {
      onStatusUpdate?.call('خطأ في معالجة الصور: $e');
      rethrow;
    }
  }
  
  /// معالجة دفعة من الصور مع استخدام الكاش
  static Future<Map<String, String>> _processBatchWithCache(
    List<String> urls,
    Directory tempDir,
    Map<String, int> settings,
    {void Function(double progress)? onProgress}
  ) async {
    final Map<String, String> results = {};
    final futures = <Future<void>>[];
    
    // إنشاء عمليات متوازية لمعالجة الصور
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      final future = _processSingleImageWithCache(
        url, 
        tempDir, 
        settings,
        onProgress: (progress) {
          final batchProgress = (i + progress) / urls.length;
          onProgress?.call(batchProgress);
        },
      ).then((result) {
        if (result != null) {
          results[url] = result;
        }
      });
      
      futures.add(future);
      
      // التحكم في التزامن
      if (futures.length >= _maxConcurrentProcessing) {
        await Future.wait(futures);
        futures.clear();
      }
    }
    
    // انتظار اكتمال العمليات المتبقية
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    
    return results;
  }
  
  /// معالجة صورة واحدة مع استخدام الكاش
  static Future<String?> _processSingleImageWithCache(
    String url,
    Directory tempDir,
    Map<String, int> settings,
    {void Function(double progress)? onProgress}
  ) async {
    try {
      onProgress?.call(0.1);
      
      // محاولة الحصول من الكاش أولاً
      final cachedImage = await AdvancedImageCacheManager.getImage(
        url,
        maxDimension: settings['dimension'],
        quality: settings['quality'],
      );
      
      if (cachedImage != null) {
        onProgress?.call(0.8);
        
        // إنشاء ملف مؤقت من الصورة المخزنة في الكاش
        final fileName = '${DateTime.now().microsecondsSinceEpoch}_${url.hashCode}.jpg';
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        
        await file.writeAsBytes(cachedImage);
        onProgress?.call(1.0);
        
        return filePath;
      }
      
      // إذا لم تكن موجودة في الكاش، معالجتها بالطريقة التقليدية
      return await _processSingleImage(url, tempDir, settings, onProgress: onProgress);
      
    } catch (e) {
      print('Error processing image with cache $url: $e');
      return null;
    }
  }
  
  /// معالجة صورة واحدة
  static Future<String?> _processSingleImage(
    String url,
    Directory tempDir,
    Map<String, int> settings,
    {void Function(double progress)? onProgress}
  ) async {
    try {
      // إنشاء اسم ملف فريد
      final fileName = '${DateTime.now().microsecondsSinceEpoch}_${url.hashCode}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      
      // تحميل الصورة
      onProgress?.call(0.3);
      final imageBytes = await _downloadImage(url);
      if (imageBytes == null) return null;
      
      onProgress?.call(0.6);
      
      // ضغط الصورة
      final compressedBytes = await _compressImage(
        imageBytes, 
        settings['dimension']!, 
        settings['quality']!
      );
      
      onProgress?.call(0.9);
      
      // حفظ الصورة المضغوطة
      await file.writeAsBytes(compressedBytes);
      
      onProgress?.call(1.0);
      return filePath;
      
    } catch (e) {
      print('Error processing image $url: $e');
      return null;
    }
  }
  
  /// تحميل صورة من URL
  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final client = http.Client();
      final response = await client.get(Uri.parse(url)).timeout(_downloadTimeout);
      client.close();
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Error downloading image $url: $e');
      return null;
    }
  }
  
  /// ضغط الصورة
  static Future<Uint8List> _compressImage(
    Uint8List bytes, 
    int maxDimension, 
    int quality
  ) async {
    try {
      // فحص أبعاد الصورة الأصلية
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      
      // إذا كانت الصورة أصغر من الحد الأقصى، فقط اضغطها
      if (image.width <= maxDimension && image.height <= maxDimension) {
        return await FlutterImageCompress.compressWithList(
          bytes,
          quality: quality,
        );
      }
      
      // تغيير الحجم مع الضغط
      return await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: maxDimension,
        minWidth: maxDimension,
        quality: quality,
      );
      
    } catch (e) {
      print('Error compressing image: $e');
      return bytes; // إرجاع الصورة الأصلية في حالة الفشل
    }
  }
  
  /// تحديد إعدادات الضغط حسب عدد الصور
  static Map<String, int> _getCompressionSettings(int imageCount) {
    for (final entry in _compressionSettings.entries) {
      if (imageCount <= entry.key) {
        return entry.value;
      }
    }
    // الإعدادات الافتراضية للصور الكثيرة جداً
    return {'dimension': 150, 'quality': 40};
  }
  
  /// تقسيم القائمة إلى دفعات
  static List<List<String>> _splitIntoBatches(List<String> items, int batchSize) {
    final List<List<String>> batches = [];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }
  
  /// تنظيف الملفات المؤقتة
  static Future<void> cleanupTempFiles(Directory tempDir) async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }
  
  /// الحصول على إحصائيات المعالجة
  static Map<String, dynamic> getProcessingStats() {
    return {
      'maxConcurrentDownloads': _maxConcurrentDownloads,
      'maxConcurrentProcessing': _maxConcurrentProcessing,
      'batchSize': _batchSize,
      'compressionSettings': _compressionSettings,
    };
  }
}

/// مدير الذاكرة المحسن
class MemoryOptimizer {
  static bool _isLowMemoryMode = false;
  static bool _isMonitoring = false;
  
  /// بدء مراقبة الذاكرة
  static void startMemoryMonitoring() {
    _isMonitoring = true;
    _isLowMemoryMode = false;
  }
  
  /// إيقاف مراقبة الذاكرة
  static void stopMemoryMonitoring() {
    _isMonitoring = false;
  }
  
  /// تنظيف الذاكرة
  static void cleanupMemory() {
    // إعطاء فرصة لجامع القمامة
    if (kIsWeb) {
      // على الويب، نستخدم تأخير بسيط
      Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  /// الحصول على توصيات الذاكرة
  static Map<String, dynamic> getMemoryRecommendations(int imageCount) {
    if (imageCount >= 200) {
      _isLowMemoryMode = true;
      return {
        'dimension': 256,
        'quality': 60,
        'concurrency': 1,
      };
    } else if (imageCount >= 100) {
      _isLowMemoryMode = true;
      return {
        'dimension': 384,
        'quality': 70,
        'concurrency': 2,
      };
    } else if (imageCount >= 50) {
      return {
        'dimension': 512,
        'quality': 75,
        'concurrency': 3,
      };
    } else {
      return {
        'dimension': 1024,
        'quality': 85,
        'concurrency': 3,
      };
    }
  }
  
  /// فحص ما إذا كان النظام في وضع الذاكرة المنخفضة
  static bool get isLowMemoryMode => _isLowMemoryMode;
  
  /// فحص ما إذا كان النظام يراقب الذاكرة
  static bool get isMonitoring => _isMonitoring;
}
