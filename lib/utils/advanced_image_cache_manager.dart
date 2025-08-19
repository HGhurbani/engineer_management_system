import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// مدير كاش متقدم للصور مع دعم التخزين المؤقت الذكي
class AdvancedImageCacheManager {
  static const String _cacheDirName = 'advanced_image_cache';
  static const String _metadataDirName = 'metadata';
  static const int _maxCacheSize = 200 * 1024 * 1024; // 200MB
  static const int _maxImageAge = 30; // 30 يوم
  static const Duration _downloadTimeout = Duration(seconds: 30);
  
  static Directory? _cacheDir;
  static Directory? _metadataDir;
  static SharedPreferences? _prefs;
  static final Map<String, Uint8List> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50; // أقصى عدد صور في الذاكرة
  
  /// تهيئة نظام الكاش
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      if (kIsWeb) {
        print('Advanced image cache initialized for web');
        return;
      }
      
      // إنشاء مجلدات الكاش
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirName');
      _metadataDir = Directory('${_cacheDir!.path}/$_metadataDirName');
      
      await _cacheDir!.create(recursive: true);
      await _metadataDir!.create(recursive: true);
      
      // تنظيف الكاش القديم
      await _cleanupOldCache();
      
      print('Advanced image cache initialized successfully');
    } catch (e) {
      print('Error initializing advanced image cache: $e');
    }
  }
  
  /// الحصول على صورة من الكاش أو تحميلها
  static Future<Uint8List?> getImage(String imageUrl, {
    int? maxDimension,
    int? quality,
    bool forceRefresh = false,
  }) async {
    try {
      // التحقق من الكاش في الذاكرة أولاً
      if (_memoryCache.containsKey(imageUrl)) {
        print('Image found in memory cache: $imageUrl');
        return _memoryCache[imageUrl];
      }
      
      if (!forceRefresh) {
        // محاولة الحصول من الكاش المحلي
        final cachedImage = await _getCachedImage(imageUrl);
        if (cachedImage != null) {
          // إضافة للكاش في الذاكرة
          _addToMemoryCache(imageUrl, cachedImage);
          return cachedImage;
        }
      }
      
      // تحميل الصورة من الإنترنت
      print('Downloading image: $imageUrl');
      final downloadedImage = await _downloadAndCacheImage(
        imageUrl, 
        maxDimension: maxDimension, 
        quality: quality
      );
      
      if (downloadedImage != null) {
        // إضافة للكاش في الذاكرة
        _addToMemoryCache(imageUrl, downloadedImage);
      }
      
      return downloadedImage;
      
    } catch (e) {
      print('Error getting image $imageUrl: $e');
      return null;
    }
  }
  
  /// تحميل صورة وتخزينها في الكاش
  static Future<Uint8List?> _downloadAndCacheImage(
    String imageUrl, {
    int? maxDimension,
    int? quality,
  }) async {
    try {
      final client = http.Client();
      final response = await client.get(Uri.parse(imageUrl)).timeout(_downloadTimeout);
      client.close();
      
      if (response.statusCode != 200) {
        print('Failed to download image: ${response.statusCode}');
        return null;
      }
      
      var imageBytes = response.bodyBytes;
      
      // معالجة الصورة إذا تم تحديد الأبعاد أو الجودة
      if (maxDimension != null || quality != null) {
        imageBytes = await _processImage(
          imageBytes, 
          maxDimension: maxDimension, 
          quality: quality
        );
      }
      
      // حفظ الصورة في الكاش
      await _cacheImage(imageUrl, imageBytes);
      
      return imageBytes;
      
    } catch (e) {
      print('Error downloading and caching image: $e');
      return null;
    }
  }
  
  /// معالجة الصورة (تغيير الحجم والضغط)
  static Future<Uint8List> _processImage(
    Uint8List bytes, {
    int? maxDimension,
    int? quality,
  }) async {
    try {
      // فحص أبعاد الصورة
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      
      // تحديد إعدادات المعالجة
      final targetDimension = maxDimension ?? 800;
      final targetQuality = quality ?? 85;
      
      // إذا كانت الصورة أصغر من الحد الأقصى، فقط اضغطها
      if (image.width <= targetDimension && image.height <= targetDimension) {
        return await FlutterImageCompress.compressWithList(
          bytes,
          quality: targetQuality,
        );
      }
      
      // تغيير الحجم مع الضغط
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: targetDimension,
        minHeight: targetDimension,
        quality: targetQuality,
      );
      
    } catch (e) {
      print('Error processing image: $e');
      return bytes;
    }
  }
  
  /// حفظ صورة في الكاش
  static Future<void> _cacheImage(String imageUrl, Uint8List imageData) async {
    try {
      if (kIsWeb) {
        // للويب، حفظ في localStorage
        final imageKey = _generateImageKey(imageUrl);
        final metadata = {
          'url': imageUrl,
          'size': imageData.length,
          'timestamp': DateTime.now().toIso8601String(),
          'accessCount': 1,
        };
        
        await _prefs?.setString('img_$imageKey', base64Encode(imageData));
        await _prefs?.setString('img_meta_$imageKey', jsonEncode(metadata));
        
      } else {
        // للموبايل، حفظ في الملفات
        final imageKey = _generateImageKey(imageUrl);
        final fileName = '${imageKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imagePath = '${_cacheDir!.path}/$fileName';
        final metadataPath = '${_metadataDir!.path}/$fileName.meta';
        
        // حفظ الصورة
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageData);
        
        // حفظ البيانات الوصفية
        final metadataFile = File(metadataPath);
        final metadata = {
          'url': imageUrl,
          'fileName': fileName,
          'filePath': imagePath,
          'size': imageData.length,
          'timestamp': DateTime.now().toIso8601String(),
          'accessCount': 1,
        };
        
        await metadataFile.writeAsString(jsonEncode(metadata));
        
        // حفظ المفتاح في SharedPreferences
        await _prefs?.setString('img_key_$imageKey', imagePath);
      }
      
      // تنظيف الكاش إذا تجاوز الحد الأقصى
      await _cleanupIfNeeded();
      
    } catch (e) {
      print('Error caching image: $e');
    }
  }
  
  /// الحصول على صورة من الكاش المحلي
  static Future<Uint8List?> _getCachedImage(String imageUrl) async {
    try {
      final imageKey = _generateImageKey(imageUrl);
      
      if (kIsWeb) {
        // للويب، البحث في localStorage
        final cachedData = _prefs?.getString('img_$imageKey');
        if (cachedData != null) {
          final imageBytes = base64Decode(cachedData);
          await _updateAccessCount(imageKey);
          return imageBytes;
        }
        
      } else {
        // للموبايل، البحث في الملفات
        final filePath = _prefs?.getString('img_key_$imageKey');
        if (filePath != null) {
          final imageFile = File(filePath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            await _updateAccessCount(imageKey);
            return imageBytes;
          }
        }
      }
      
      return null;
      
    } catch (e) {
      print('Error retrieving cached image: $e');
      return null;
    }
  }
  
  /// إضافة صورة للكاش في الذاكرة
  static void _addToMemoryCache(String imageUrl, Uint8List imageData) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // إزالة أقدم صورة
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    
    _memoryCache[imageUrl] = imageData;
  }
  
  /// تحديث عدد مرات الوصول للصورة
  static Future<void> _updateAccessCount(String imageKey) async {
    try {
      if (kIsWeb) {
        final metadataKey = 'img_meta_$imageKey';
        final metadataStr = _prefs?.getString(metadataKey);
        if (metadataStr != null) {
          final metadata = jsonDecode(metadataStr);
          metadata['accessCount'] = (metadata['accessCount'] ?? 0) + 1;
          metadata['lastAccessed'] = DateTime.now().toIso8601String();
          await _prefs?.setString(metadataKey, jsonEncode(metadata));
        }
      } else {
        // للموبايل، تحديث البيانات الوصفية
        final filePath = _prefs?.getString('img_key_$imageKey');
        if (filePath != null) {
          final metadataPath = '${_metadataDir!.path}/${filePath.split('/').last}.meta';
          final metadataFile = File(metadataPath);
          if (await metadataFile.exists()) {
            final metadata = jsonDecode(await metadataFile.readAsString());
            metadata['accessCount'] = (metadata['accessCount'] ?? 0) + 1;
            metadata['lastAccessed'] = DateTime.now().toIso8601String();
            await metadataFile.writeAsString(jsonEncode(metadata));
          }
        }
      }
    } catch (e) {
      print('Error updating access count: $e');
    }
  }
  
  /// تنظيف الكاش إذا تجاوز الحد الأقصى
  static Future<void> _cleanupIfNeeded() async {
    try {
      if (kIsWeb) return; // للويب، لا نحتاج تنظيف
      
      final currentSize = await _getCurrentCacheSize();
      if (currentSize > _maxCacheSize) {
        await _removeLowPriorityImages();
      }
    } catch (e) {
      print('Error cleaning up cache: $e');
    }
  }
  
  /// الحصول على حجم الكاش الحالي
  static Future<int> _getCurrentCacheSize() async {
    try {
      int totalSize = 0;
      final files = _cacheDir!.listSync();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }
  
  /// إزالة الصور منخفضة الأولوية
  static Future<void> _removeLowPriorityImages() async {
    try {
      final files = _metadataDir!.listSync();
      final List<Map<String, dynamic>> imageInfo = [];
      
      // جمع معلومات الصور
      for (final file in files) {
        if (file is File && file.path.endsWith('.meta')) {
          final metadata = jsonDecode(await file.readAsString());
          imageInfo.add(metadata);
        }
      }
      
      // ترتيب الصور حسب الأولوية (الأقل وصولاً والأقدم)
      imageInfo.sort((a, b) {
        final aScore = (a['accessCount'] ?? 0) * 0.7 + 
                      (DateTime.now().difference(DateTime.parse(a['timestamp'])).inDays) * 0.3;
        final bScore = (b['accessCount'] ?? 0) * 0.7 + 
                      (DateTime.now().difference(DateTime.parse(b['timestamp'])).inDays) * 0.3;
        return aScore.compareTo(bScore);
      });
      
      // إزالة الصور حتى نصل للحجم المطلوب
      int removedSize = 0;
      final targetSize = _maxCacheSize * 0.8; // 80% من الحد الأقصى
      
      for (final info in imageInfo) {
        if (removedSize >= targetSize) break;
        
        try {
          final imageFile = File(info['filePath']);
          final metadataFile = File('${_metadataDir!.path}/${info['fileName']}.meta');
          
          if (await imageFile.exists()) {
            removedSize += await imageFile.length();
            await imageFile.delete();
          }
          
          if (await metadataFile.exists()) {
            await metadataFile.delete();
          }
          
          // إزالة المفتاح من SharedPreferences
          final imageKey = _generateImageKey(info['url']);
          await _prefs?.remove('img_key_$imageKey');
          
        } catch (e) {
          print('Error removing image: $e');
        }
      }
      
      print('Removed ${removedSize ~/ 1024}KB from cache');
      
    } catch (e) {
      print('Error removing low priority images: $e');
    }
  }
  
  /// تنظيف الكاش القديم
  static Future<void> _cleanupOldCache() async {
    try {
      if (kIsWeb) return;
      
      final files = _metadataDir!.listSync();
      final now = DateTime.now();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.meta')) {
          try {
            final metadata = jsonDecode(await file.readAsString());
            final timestamp = DateTime.parse(metadata['timestamp']);
            final age = now.difference(timestamp).inDays;
            
            if (age > _maxImageAge) {
              // إزالة الصورة القديمة
              final imageFile = File(metadata['filePath']);
              if (await imageFile.exists()) {
                await imageFile.delete();
              }
              await file.delete();
              
              // إزالة المفتاح من SharedPreferences
              final imageKey = _generateImageKey(metadata['url']);
              await _prefs?.remove('img_key_$imageKey');
            }
          } catch (e) {
            print('Error processing metadata file: $e');
          }
        }
      }
      
    } catch (e) {
      print('Error cleaning up old cache: $e');
    }
  }
  
  /// إنشاء مفتاح فريد للصورة
  static String _generateImageKey(String imageUrl) {
    final bytes = utf8.encode(imageUrl);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  /// مسح الكاش بالكامل
  static Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      
      if (kIsWeb) {
        // للويب، مسح localStorage
        final keys = _prefs?.getKeys() ?? {};
        for (final key in keys) {
          if (key.startsWith('img_')) {
            await _prefs?.remove(key);
          }
        }
      } else {
        // للموبايل، مسح الملفات
        if (_cacheDir != null && await _cacheDir!.exists()) {
          await _cacheDir!.delete(recursive: true);
          await _cacheDir!.create(recursive: true);
        }
        if (_metadataDir != null && await _metadataDir!.exists()) {
          await _metadataDir!.delete(recursive: true);
          await _metadataDir!.create(recursive: true);
        }
      }
      
      print('Image cache cleared successfully');
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }
  
  /// الحصول على إحصائيات الكاش
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      int totalImages = 0;
      int totalSize = 0;
      int memoryCacheSize = _memoryCache.length;
      
      if (kIsWeb) {
        // للويب، حساب من localStorage
        final keys = _prefs?.getKeys() ?? {};
        for (final key in keys) {
          if (key.startsWith('img_') && !key.startsWith('img_meta_')) {
            totalImages++;
            final imageData = _prefs?.getString(key);
            if (imageData != null) {
              totalSize += base64Decode(imageData).length;
            }
          }
        }
      } else {
        // للموبايل، حساب من الملفات
        if (_cacheDir != null && await _cacheDir!.exists()) {
          final files = _cacheDir!.listSync();
          for (final file in files) {
            if (file is File && file.path.endsWith('.jpg')) {
              totalImages++;
              totalSize += await file.length();
            }
          }
        }
      }
      
      return {
        'totalImages': totalImages,
        'memoryCacheSize': memoryCacheSize,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'maxCacheSizeMB': (_maxCacheSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error getting cache stats: $e');
      return {};
    }
  }
  
  /// فحص ما إذا كانت الصورة موجودة في الكاش
  static Future<bool> isImageCached(String imageUrl) async {
    try {
      if (_memoryCache.containsKey(imageUrl)) return true;
      
      final imageKey = _generateImageKey(imageUrl);
      
      if (kIsWeb) {
        return _prefs?.containsKey('img_$imageKey') ?? false;
      } else {
        final filePath = _prefs?.getString('img_key_$imageKey');
        if (filePath != null) {
          return await File(filePath).exists();
        }
        return false;
      }
    } catch (e) {
      print('Error checking if image is cached: $e');
      return false;
    }
  }
}
