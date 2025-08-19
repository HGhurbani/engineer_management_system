import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';

/// نظام كاش الصور الفوري للتقارير
class InstantImageCache {
  static const String _cacheVersion = '2.0';
  static const Duration _cacheExpiry = Duration(days: 30);
  static const int _maxCacheSize = 200 * 1024 * 1024; // 200MB
  static const int _maxConcurrentDownloads = 10;
  
  static Directory? _cacheDir;
  static SharedPreferences? _prefs;
  static final Map<String, Future<String?>> _downloadQueue = {};
  static final Map<String, String> _memoryCache = {};
  
  /// تهيئة نظام الكاش
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/instant_image_cache_$_cacheVersion');
      await _cacheDir!.create(recursive: true);
      
      // تنظيف الكاش القديم
      await _cleanupOldCache();
    }
  }
  
  /// الحصول على مجموعة صور بشكل فوري (مع كاش ذكي)
  static Future<Map<String, String>> getImagesInstantly({
    required List<String> imageUrls,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatusUpdate,
  }) async {
    final Map<String, String> results = {};
    final List<String> missingUrls = [];
    
    onStatusUpdate?.call('فحص الكاش المحلي...');
    
    // 1. فحص الكاش المحلي أولاً
    for (final url in imageUrls) {
      final cachedPath = await _getCachedImagePath(url);
      if (cachedPath != null) {
        results[url] = cachedPath;
      } else {
        missingUrls.add(url);
      }
    }
    
    onStatusUpdate?.call('تم العثور على ${results.length} صورة في الكاش، سيتم تحميل ${missingUrls.length} صورة');
    
    // 2. تحميل الصور المفقودة بشكل متوازي
    if (missingUrls.isNotEmpty) {
      final downloadedImages = await _downloadImagesBatch(
        missingUrls,
        onProgress: onProgress,
        onStatusUpdate: onStatusUpdate,
      );
      results.addAll(downloadedImages);
    }
    
    onStatusUpdate?.call('تم الانتهاء من معالجة جميع الصور');
    return results;
  }
  
  /// تحميل مجموعة صور بشكل متوازي
  static Future<Map<String, String>> _downloadImagesBatch(
    List<String> urls,
    {void Function(double progress)? onProgress,
    void Function(String status)? onStatusUpdate}
  ) async {
    final Map<String, String> results = {};
    final List<Future<void>> downloadTasks = [];
    int completed = 0;
    
    // تقسيم التحميل إلى دفعات
    for (int i = 0; i < urls.length; i += _maxConcurrentDownloads) {
      final batch = urls.skip(i).take(_maxConcurrentDownloads).toList();
      
      for (final url in batch) {
        final task = _downloadAndCacheImage(url).then((cachedPath) {
          if (cachedPath != null) {
            results[url] = cachedPath;
          }
          completed++;
          onProgress?.call(completed / urls.length);
        });
        
        downloadTasks.add(task);
      }
      
      // انتظار انتهاء الدفعة الحالية قبل البدء بالتالية
      await Future.wait(downloadTasks);
      downloadTasks.clear();
      
      // تأخير قصير لتجنب إرهاق الخادم
      if (i + _maxConcurrentDownloads < urls.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    return results;
  }
  
  /// تحميل وحفظ صورة واحدة
  static Future<String?> _downloadAndCacheImage(String url) async {
    // فحص إذا كان التحميل جاري بالفعل
    if (_downloadQueue.containsKey(url)) {
      return await _downloadQueue[url];
    }
    
    // إنشاء مهمة تحميل جديدة
    final downloadFuture = _performDownload(url);
    _downloadQueue[url] = downloadFuture;
    
    try {
      final result = await downloadFuture;
      return result;
    } finally {
      _downloadQueue.remove(url);
    }
  }
  
  /// تنفيذ التحميل الفعلي
  static Future<String?> _performDownload(String url) async {
    try {
      final cacheKey = _generateCacheKey(url);
      final fileName = '$cacheKey.jpg';
      final filePath = '${_cacheDir!.path}/$fileName';
      final file = File(filePath);
      
      // تحميل الصورة
      final client = http.Client();
      final response = await client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30)
      );
      client.close();
      
      if (response.statusCode != 200) {
        return null;
      }
      
      // ضغط الصورة حسب الحجم
      final compressedBytes = await _compressImageBytes(
        response.bodyBytes, 
        _getOptimalDimension(response.bodyBytes.length)
      );
      
      // حفظ الصورة المضغوطة
      await file.writeAsBytes(compressedBytes);
      
      // حفظ معلومات الكاش
      await _saveCacheInfo(url, cacheKey, compressedBytes.length);
      
      return filePath;
      
    } catch (e) {
      print('Error downloading image $url: $e');
      return null;
    }
  }
  
  /// ضغط الصورة بناءً على الحجم الأمثل
  static Future<Uint8List> _compressImageBytes(Uint8List bytes, int targetDimension) async {
    try {
      // إنشاء ملف مؤقت
      final tempDir = await Directory.systemTemp.createTemp('compress');
      final tempFile = File('${tempDir.path}/temp.jpg');
      await tempFile.writeAsBytes(bytes);
      
      // ضغط الصورة
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        tempFile.path,
        minWidth: targetDimension,
        minHeight: targetDimension,
        quality: _getOptimalQuality(bytes.length),
      );
      
      // تنظيف الملف المؤقت
      await tempDir.delete(recursive: true);
      
      return compressedBytes ?? bytes;
    } catch (e) {
      print('Error compressing image: $e');
      return bytes;
    }
  }
  
  /// الحصول على البعد الأمثل حسب حجم الصورة
  static int _getOptimalDimension(int fileSize) {
    if (fileSize > 2 * 1024 * 1024) return 800;  // أكبر من 2MB
    if (fileSize > 1 * 1024 * 1024) return 1000; // أكبر من 1MB
    if (fileSize > 500 * 1024) return 1200;      // أكبر من 500KB
    return 1500; // الحد الأقصى للصور الصغيرة
  }
  
  /// الحصول على الجودة المثلى حسب حجم الملف
  static int _getOptimalQuality(int fileSize) {
    if (fileSize > 3 * 1024 * 1024) return 60;  // أكبر من 3MB
    if (fileSize > 1 * 1024 * 1024) return 75;  // أكبر من 1MB
    if (fileSize > 500 * 1024) return 85;       // أكبر من 500KB
    return 90; // جودة عالية للصور الصغيرة
  }
  
  /// فحص وجود صورة في الكاش
  static Future<String?> _getCachedImagePath(String url) async {
    try {
      final cacheKey = _generateCacheKey(url);
      final filePath = '${_cacheDir!.path}/$cacheKey.jpg';
      final file = File(filePath);
      
      if (await file.exists()) {
        // فحص انتهاء صلاحية الكاش
        final cacheInfo = await _getCacheInfo(cacheKey);
        if (cacheInfo != null && !_isCacheExpired(cacheInfo['timestamp'])) {
          return filePath;
        } else {
          // حذف الملف المنتهي الصلاحية
          await file.delete();
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// إنشاء مفتاح كاش فريد
  static String _generateCacheKey(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }
  
  /// حفظ معلومات الكاش
  static Future<void> _saveCacheInfo(String url, String cacheKey, int fileSize) async {
    final cacheInfo = {
      'url': url,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'fileSize': fileSize,
    };
    
    await _prefs?.setString('cache_$cacheKey', jsonEncode(cacheInfo));
  }
  
  /// الحصول على معلومات الكاش
  static Future<Map<String, dynamic>?> _getCacheInfo(String cacheKey) async {
    final infoString = _prefs?.getString('cache_$cacheKey');
    if (infoString != null) {
      return jsonDecode(infoString);
    }
    return null;
  }
  
  /// فحص انتهاء صلاحية الكاش
  static bool _isCacheExpired(int timestamp) {
    final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheDate) > _cacheExpiry;
  }
  
  /// تنظيف الكاش القديم
  static Future<void> _cleanupOldCache() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;
      
      final files = _cacheDir!.listSync();
      int totalSize = 0;
      final List<FileSystemEntity> filesToDelete = [];
      
      // حساب الحجم الإجمالي وجمع الملفات المنتهية الصلاحية
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
          
          // فحص انتهاء الصلاحية
          final cacheKey = file.path.split('/').last.replaceAll('.jpg', '');
          final cacheInfo = await _getCacheInfo(cacheKey);
          
          if (cacheInfo != null && _isCacheExpired(cacheInfo['timestamp'])) {
            filesToDelete.add(file);
          }
        }
      }
      
      // حذف الملفات المنتهية الصلاحية
      for (final file in filesToDelete) {
        await file.delete();
        final cacheKey = file.path.split('/').last.replaceAll('.jpg', '');
        await _prefs?.remove('cache_$cacheKey');
      }
      
      // إذا كان الحجم الإجمالي أكبر من الحد المسموح، احذف أقدم الملفات
      if (totalSize > _maxCacheSize) {
        await _cleanupBySize();
      }
      
    } catch (e) {
      print('Error cleaning up cache: $e');
    }
  }
  
  /// تنظيف الكاش حسب الحجم
  static Future<void> _cleanupBySize() async {
    // تنفيذ منطق تنظيف إضافي إذا لزم الأمر
  }
  
  /// الحصول على إحصائيات الكاش
  static Future<Map<String, dynamic>> getCacheStats() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return {'totalFiles': 0, 'totalSize': 0};
    }
    
    final files = _cacheDir!.listSync();
    int totalFiles = 0;
    int totalSize = 0;
    
    for (final file in files) {
      if (file is File && file.path.endsWith('.jpg')) {
        totalFiles++;
        final stat = await file.stat();
        totalSize += stat.size;
      }
    }
    
    return {
      'totalFiles': totalFiles,
      'totalSize': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }
}
