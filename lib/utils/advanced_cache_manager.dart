import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// مدير كاش متقدم للتعامل مع البيانات الكبيرة والعمل بدون إنترنت
class AdvancedCacheManager {
  static const String _cacheDirName = 'advanced_cache';
  static const String _reportsDirName = 'reports';
  static const String _imagesDirName = 'images';
  static const String _dataDirName = 'data';
  static const int _maxCacheSize = 500 * 1024 * 1024; // 500MB
  static const int _maxReportCacheSize = 100 * 1024 * 1024; // 100MB
  
  static Directory? _cacheDir;
  static Directory? _reportsDir;
  static Directory? _imagesDir;
  static Directory? _dataDir;
  static SharedPreferences? _prefs;
  
  /// تهيئة نظام الكاش
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      if (kIsWeb) {
        // للويب، استخدام IndexedDB أو localStorage
        print('Advanced cache initialized for web');
        return;
      }
      
      // للموبايل، إنشاء مجلدات الكاش
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirName');
      _reportsDir = Directory('${_cacheDir!.path}/$_reportsDirName');
      _imagesDir = Directory('${_cacheDir!.path}/$_imagesDirName');
      _dataDir = Directory('${_cacheDir!.path}/$_dataDirName');
      
      // إنشاء المجلدات إذا لم تكن موجودة
      await _cacheDir!.create(recursive: true);
      await _reportsDir!.create(recursive: true);
      await _imagesDir!.create(recursive: true);
      await _dataDir!.create(recursive: true);
      
      // تنظيف الكاش القديم
      await _cleanupOldCache();
      
      print('Advanced cache initialized successfully');
    } catch (e) {
      print('Error initializing advanced cache: $e');
    }
  }
  
  /// حفظ تقرير في الكاش
  static Future<String> cacheReport({
    required String reportId,
    required Uint8List reportData,
    required Map<String, dynamic> metadata,
    int priority = 1,
  }) async {
    try {
      final fileName = '${reportId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${_reportsDir!.path}/$fileName';
      
      // حفظ التقرير
      final file = File(filePath);
      await file.writeAsBytes(reportData);
      
      // حفظ البيانات الوصفية
      final metadataFile = File('${filePath}.meta');
      await metadataFile.writeAsString(jsonEncode({
        ...metadata,
        'fileName': fileName,
        'filePath': filePath,
        'size': reportData.length,
        'priority': priority,
        'timestamp': DateTime.now().toIso8601String(),
        'accessCount': 0,
      }));
      
      // تحديث إحصائيات الكاش
      await _updateCacheStats();
      
      print('Report cached successfully: $fileName');
      return filePath;
    } catch (e) {
      print('Error caching report: $e');
      rethrow;
    }
  }
  
  /// استرجاع تقرير من الكاش
  static Future<Map<String, dynamic>?> getCachedReport(String reportId) async {
    try {
      if (kIsWeb) {
        // للويب، البحث في localStorage
        final cachedData = _prefs?.getString('report_$reportId');
        if (cachedData != null) {
          final data = jsonDecode(cachedData);
          await _updateAccessCount(reportId);
          return data;
        }
        return null;
      }
      
      // للموبايل، البحث في الملفات
      final files = _reportsDir!.listSync();
      for (final file in files) {
        if (file.path.contains(reportId) && file.path.endsWith('.meta')) {
          final metadataFile = File(file.path);
          final metadata = jsonDecode(await metadataFile.readAsString());
          
          // التحقق من وجود ملف التقرير
          final reportFile = File(metadata['filePath']);
          if (await reportFile.exists()) {
            final reportData = await reportFile.readAsBytes();
            
            // تحديث عدد مرات الوصول
            await _updateAccessCount(reportId);
            
            return {
              ...metadata,
              'data': reportData,
            };
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error retrieving cached report: $e');
      return null;
    }
  }
  
  /// حفظ بيانات في الكاش
  static Future<String> cacheData({
    required String key,
    required Map<String, dynamic> data,
    Duration? expiry,
    int priority = 1,
  }) async {
    try {
      final cacheKey = _generateCacheKey(key);
      final fileName = '${cacheKey}_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = '${_dataDir!.path}/$fileName';
      
      // حفظ البيانات
      final file = File(filePath);
      final cacheData = {
        'key': key,
        'data': data,
        'expiry': expiry?.inMilliseconds,
        'priority': priority,
        'timestamp': DateTime.now().toIso8601String(),
        'accessCount': 0,
      };
      
      await file.writeAsString(jsonEncode(cacheData));
      
      // حفظ المفتاح في SharedPreferences للبحث السريع
      await _prefs?.setString('cache_key_$key', filePath);
      
      print('Data cached successfully: $key');
      return filePath;
    } catch (e) {
      print('Error caching data: $e');
      rethrow;
    }
  }
  
  /// استرجاع بيانات من الكاش
  static Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      if (kIsWeb) {
        // للويب، البحث في localStorage
        final cachedData = _prefs?.getString('data_$key');
        if (cachedData != null) {
          final data = jsonDecode(cachedData);
          if (_isDataExpired(data)) {
            await _removeCachedData(key);
            return null;
          }
          await _updateDataAccessCount(key);
          return data['data'];
        }
        return null;
      }
      
      // للموبايل، البحث في الملفات
      final filePath = _prefs?.getString('cache_key_$key');
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final cacheData = jsonDecode(await file.readAsString());
          
          // التحقق من انتهاء الصلاحية
          if (_isDataExpired(cacheData)) {
            await _removeCachedData(key);
            return null;
          }
          
          await _updateDataAccessCount(key);
          return cacheData['data'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error retrieving cached data: $e');
      return null;
    }
  }
  
  /// حفظ صورة في الكاش
  static Future<String> cacheImage({
    required String imageUrl,
    required Uint8List imageData,
    int priority = 1,
  }) async {
    try {
      final imageKey = _generateCacheKey(imageUrl);
      final fileName = '${imageKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${_imagesDir!.path}/$fileName';
      
      // حفظ الصورة
      final file = File(filePath);
      await file.writeAsBytes(imageData);
      
      // حفظ البيانات الوصفية
      final metadataFile = File('${filePath}.meta');
      await metadataFile.writeAsString(jsonEncode({
        'url': imageUrl,
        'fileName': fileName,
        'filePath': filePath,
        'size': imageData.length,
        'priority': priority,
        'timestamp': DateTime.now().toIso8601String(),
        'accessCount': 0,
      }));
      
      // حفظ المفتاح في SharedPreferences
      await _prefs?.setString('image_key_$imageKey', filePath);
      
      print('Image cached successfully: $imageKey');
      return filePath;
    } catch (e) {
      print('Error caching image: $e');
      rethrow;
    }
  }
  
  /// استرجاع صورة من الكاش
  static Future<Uint8List?> getCachedImage(String imageUrl) async {
    try {
      final imageKey = _generateCacheKey(imageUrl);
      final filePath = _prefs?.getString('image_key_$imageKey');
      
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final imageData = await file.readAsBytes();
          await _updateImageAccessCount(imageKey);
          return imageData;
        }
      }
      
      return null;
    } catch (e) {
      print('Error retrieving cached image: $e');
      return null;
    }
  }
  
  /// فحص حالة الاتصال بالإنترنت
  static Future<bool> isOnline() async {
    try {
      if (kIsWeb) {
        // للويب، محاولة الوصول لموقع معروف
        return true; // افتراض أن الويب متصل
      }
      
      // للموبايل، فحص الاتصال
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// العمل في وضع عدم الاتصال
  static Future<Map<String, dynamic>> workOffline(String operation) async {
    try {
      final isConnected = await isOnline();
      
      if (!isConnected) {
        // محاولة العمل من الكاش
        final cachedResult = await getCachedData('offline_$operation');
        if (cachedResult != null) {
          return {
            'success': true,
            'data': cachedResult,
            'source': 'cache',
            'offline': true,
          };
        }
        
        return {
          'success': false,
          'error': 'No internet connection and no cached data available',
          'offline': true,
        };
      }
      
      return {
        'success': true,
        'online': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'offline': true,
      };
    }
  }
  
  /// تنظيف الكاش القديم
  static Future<void> _cleanupOldCache() async {
    try {
      if (kIsWeb) return;
      
      final currentSize = await _getCurrentCacheSize();
      if (currentSize > _maxCacheSize) {
        // حذف العناصر الأقل أولوية والأقدم
        await _removeLowPriorityItems();
      }
    } catch (e) {
      print('Error cleaning up cache: $e');
    }
  }
  
  /// الحصول على حجم الكاش الحالي
  static Future<int> _getCurrentCacheSize() async {
    try {
      int totalSize = 0;
      
      // حساب حجم التقارير
      final reportFiles = _reportsDir!.listSync();
      for (final file in reportFiles) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      // حساب حجم الصور
      final imageFiles = _imagesDir!.listSync();
      for (final file in imageFiles) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      // حساب حجم البيانات
      final dataFiles = _dataDir!.listSync();
      for (final file in dataFiles) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
  
  /// إزالة العناصر منخفضة الأولوية
  static Future<void> _removeLowPriorityItems() async {
    try {
      // جمع جميع العناصر مع أولوياتها
      final items = <Map<String, dynamic>>[];
      
      // التقارير
      final reportFiles = _reportsDir!.listSync();
      for (final file in reportFiles) {
        if (file.path.endsWith('.meta')) {
          final metadata = jsonDecode(await File(file.path).readAsString());
          items.add(metadata);
        }
      }
      
      // الصور
      final imageFiles = _imagesDir!.listSync();
      for (final file in imageFiles) {
        if (file.path.endsWith('.meta')) {
          final metadata = jsonDecode(await File(file.path).readAsString());
          items.add(metadata);
        }
      }
      
      // البيانات
      final dataFiles = _dataDir!.listSync();
      for (final file in dataFiles) {
        if (file.path.endsWith('.meta')) {
          final metadata = jsonDecode(await File(file.path).readAsString());
          items.add(metadata);
        }
      }
      
      // ترتيب حسب الأولوية والوقت
      items.sort((a, b) {
        final priorityDiff = (a['priority'] ?? 0).compareTo(b['priority'] ?? 0);
        if (priorityDiff != 0) return priorityDiff;
        
        final timeA = DateTime.parse(a['timestamp']);
        final timeB = DateTime.parse(b['timestamp']);
        return timeA.compareTo(timeB);
      });
      
      // حذف العناصر الأقل أولوية حتى نصل للحجم المطلوب
      int currentSize = await _getCurrentCacheSize();
      for (final item in items) {
        if (currentSize <= _maxCacheSize) break;
        
        try {
          final file = File(item['filePath']);
          if (await file.exists()) {
            final fileSize = await file.length();
            await file.delete();
            
            final metaFile = File('${item['filePath']}.meta');
            if (await metaFile.exists()) {
              await metaFile.delete();
            }
            
            currentSize -= fileSize;
            print('Removed low priority item: ${item['fileName']}');
          }
        } catch (e) {
          print('Error removing item: $e');
        }
      }
    } catch (e) {
      print('Error removing low priority items: $e');
    }
  }
  
  /// تحديث إحصائيات الكاش
  static Future<void> _updateCacheStats() async {
    try {
      final currentSize = await _getCurrentCacheSize();
      final reportCount = _reportsDir!.listSync().where((f) => f.path.endsWith('.pdf')).length;
      final imageCount = _imagesDir!.listSync().where((f) => f.path.endsWith('.jpg')).length;
      final dataCount = _dataDir!.listSync().where((f) => f.path.endsWith('.json')).length;
      
      await _prefs?.setInt('cache_size', currentSize);
      await _prefs?.setInt('cache_reports', reportCount);
      await _prefs?.setInt('cache_images', imageCount);
      await _prefs?.setInt('cache_data', dataCount);
    } catch (e) {
      print('Error updating cache stats: $e');
    }
  }
  
  /// تحديث عدد مرات الوصول للتقرير
  static Future<void> _updateAccessCount(String reportId) async {
    try {
      // تحديث في SharedPreferences للويب
      final currentCount = _prefs?.getInt('report_access_$reportId') ?? 0;
      await _prefs?.setInt('report_access_$reportId', currentCount + 1);
      
      // تحديث في ملف البيانات للموبايل
      if (!kIsWeb) {
        // البحث عن ملف البيانات وتحديثه
        final files = _reportsDir!.listSync();
        for (final file in files) {
          if (file.path.contains(reportId) && file.path.endsWith('.meta')) {
            final metadataFile = File(file.path);
            final metadata = jsonDecode(await metadataFile.readAsString());
            metadata['accessCount'] = (metadata['accessCount'] ?? 0) + 1;
            await metadataFile.writeAsString(jsonEncode(metadata));
            break;
          }
        }
      }
    } catch (e) {
      print('Error updating report access count: $e');
    }
  }
  
  /// تحديث عدد مرات الوصول للبيانات
  static Future<void> _updateDataAccessCount(String key) async {
    try {
      final currentCount = _prefs?.getInt('data_access_$key') ?? 0;
      await _prefs?.setInt('data_access_$key', currentCount + 1);
    } catch (e) {
      print('Error updating data access count: $e');
    }
  }
  
  /// تحديث عدد مرات الوصول للصورة
  static Future<void> _updateImageAccessCount(String imageKey) async {
    try {
      final currentCount = _prefs?.getInt('image_access_$imageKey') ?? 0;
      await _prefs?.setInt('image_access_$imageKey', currentCount + 1);
    } catch (e) {
      print('Error updating image access count: $e');
    }
  }
  
  /// إزالة بيانات من الكاش
  static Future<void> _removeCachedData(String key) async {
    try {
      await _prefs?.remove('data_$key');
      await _prefs?.remove('cache_key_$key');
    } catch (e) {
      print('Error removing cached data: $e');
    }
  }
  
  /// فحص انتهاء صلاحية البيانات
  static bool _isDataExpired(Map<String, dynamic> data) {
    try {
      final expiry = data['expiry'];
      if (expiry == null) return false;
      
      final timestamp = DateTime.parse(data['timestamp']);
      final expiryTime = timestamp.add(Duration(milliseconds: expiry));
      
      return DateTime.now().isAfter(expiryTime);
    } catch (e) {
      return false;
    }
  }
  
  /// إنشاء مفتاح كاش فريد
  static String _generateCacheKey(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
  
  /// الحصول على إحصائيات الكاش
  static Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _prefs?.getInt('cache_size') ?? 0,
      'reportCount': _prefs?.getInt('cache_reports') ?? 0,
      'imageCount': _prefs?.getInt('cache_images') ?? 0,
      'dataCount': _prefs?.getInt('cache_data') ?? 0,
      'maxCacheSize': _maxCacheSize,
      'maxReportCacheSize': _maxReportCacheSize,
    };
  }
  
  /// تنظيف الكاش بالكامل
  static Future<void> clearCache() async {
    try {
      if (kIsWeb) {
        await _prefs?.clear();
        return;
      }
      
      // حذف جميع الملفات
      await _reportsDir?.delete(recursive: true);
      await _imagesDir?.delete(recursive: true);
      await _dataDir?.delete(recursive: true);
      
      // إعادة إنشاء المجلدات
      await _reportsDir?.create(recursive: true);
      await _imagesDir?.create(recursive: true);
      await _dataDir?.create(recursive: true);
      
      // مسح SharedPreferences
      await _prefs?.clear();
      
      print('Cache cleared successfully');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}




