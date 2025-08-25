import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// نظام إدارة التخزين المؤقت الذكي للتقارير الشاملة
/// يحمل البيانات الجديدة فقط ويحتفظ بالبيانات في الذاكرة لتسريع إنشاء التقارير
class SmartReportCacheManager {

  static const String _cacheDirName = 'smart_report_cache';
  static const String _dataCacheDirName = 'data_cache';
  static const String _imageCacheDirName = 'image_cache';
  static const String _reportCacheDirName = 'report_cache';
  
  static Directory? _cacheDir;
  static Directory? _dataCacheDir;
  static Directory? _imageCacheDir;
  static Directory? _reportCacheDir;
  static SharedPreferences? _prefs;
  
  // ذاكرة التطبيق لحفظ البيانات المؤقتة
  static final Map<String, CachedProjectData> _memoryCache = {};
  static final Map<String, DateTime> _lastUpdateTimes = {};
  static final Map<String, Set<String>> _cachedImageIds = {};
  
  /// تهيئة نظام التخزين المؤقت الذكي
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      if (kIsWeb) {
        print('Smart Report Cache initialized for web');
        return;
      }
      
      // إنشاء مجلدات التخزين المؤقت
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirName');
      _dataCacheDir = Directory('${_cacheDir!.path}/$_dataCacheDirName');
      _imageCacheDir = Directory('${_cacheDir!.path}/$_imageCacheDirName');
      _reportCacheDir = Directory('${_cacheDir!.path}/$_reportCacheDirName');
      
      await _cacheDir!.create(recursive: true);
      await _dataCacheDir!.create(recursive: true);
      await _imageCacheDir!.create(recursive: true);
      await _reportCacheDir!.create(recursive: true);
      
      // تنظيف البيانات القديمة
      await _cleanupOldCache();
      
      // تحميل البيانات المحفوظة إلى الذاكرة
      await _loadCachedDataToMemory();
      
      print('Smart Report Cache initialized successfully');
    } catch (e) {
      print('Error initializing Smart Report Cache: $e');
    }
  }
  
  /// الحصول على بيانات المشروع للتقرير الشامل مع التحميل التدريجي
  static Future<ComprehensiveReportData> getComprehensiveReportData({
    required String projectId,
    required DateTime startDate,
    required DateTime endDate,
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
    bool forceRefresh = false,
  }) async {
    try {
      onStatusUpdate?.call('جاري فحص البيانات المحفوظة...');
      onProgress?.call(0.1);
      
      final cacheKey = _generateCacheKey(projectId, startDate, endDate);
      
      // فحص الذاكرة أولاً
      if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
        final cachedData = _memoryCache[cacheKey]!;
        final lastUpdate = _lastUpdateTimes[cacheKey];
        
        // إذا كانت البيانات حديثة (أقل من 5 دقائق)
        if (lastUpdate != null && 
            DateTime.now().difference(lastUpdate).inMinutes < 5) {
          onStatusUpdate?.call('تم العثور على البيانات في الذاكرة');
          onProgress?.call(1.0);
          return ComprehensiveReportData.fromCachedData(cachedData);
        }
      }
      
      // فحص التخزين المؤقت المحلي
      onStatusUpdate?.call('جاري فحص التخزين المؤقت المحلي...');
      onProgress?.call(0.2);
      
      CachedProjectData? cachedProjectData;
      if (!forceRefresh) {
        cachedProjectData = await _loadCachedProjectData(cacheKey);
      }
      
      // الحصول على آخر تحديث من Firestore
      onStatusUpdate?.call('جاري فحص التحديثات الجديدة...');
      onProgress?.call(0.3);
      
      final latestUpdateTime = await _getLatestUpdateTime(projectId, startDate, endDate);
      
      // تحديد ما إذا كنا نحتاج لتحميل بيانات جديدة
      bool needsUpdate = cachedProjectData == null || 
                        forceRefresh ||
                        (cachedProjectData.lastUpdateTime.isBefore(latestUpdateTime));
      
      if (!needsUpdate) {
        // استخدام البيانات المحفوظة
        onStatusUpdate?.call('استخدام البيانات المحفوظة');
        _memoryCache[cacheKey] = cachedProjectData;
        _lastUpdateTimes[cacheKey] = DateTime.now();
        onProgress?.call(1.0);
        return ComprehensiveReportData.fromCachedData(cachedProjectData);
      }
      
      // تحميل البيانات الجديدة فقط
      onStatusUpdate?.call('جاري تحميل البيانات الجديدة...');
      onProgress?.call(0.4);
      
      final newData = await _loadIncrementalData(
        projectId: projectId,
        startDate: startDate,
        endDate: endDate,
        existingData: cachedProjectData,
        onStatusUpdate: onStatusUpdate,
        onProgress: (p) => onProgress?.call(0.4 + (p * 0.5)),
      );
      
      // دمج البيانات القديمة مع الجديدة
      onStatusUpdate?.call('جاري دمج البيانات...');
      onProgress?.call(0.9);
      
      final mergedData = _mergeProjectData(cachedProjectData, newData);
      
      // حفظ البيانات المدمجة
      await _saveCachedProjectData(cacheKey, mergedData);
      _memoryCache[cacheKey] = mergedData;
      _lastUpdateTimes[cacheKey] = DateTime.now();
      
      onStatusUpdate?.call('تم تحميل البيانات بنجاح');
      onProgress?.call(1.0);
      
      return ComprehensiveReportData.fromCachedData(mergedData);
      
    } catch (e) {
      print('Error getting comprehensive report data: $e');
      throw e;
    }
  }
  
  /// تحميل البيانات الجديدة فقط (التحميل التدريجي)
  static Future<CachedProjectData> _loadIncrementalData({
    required String projectId,
    required DateTime startDate,
    required DateTime endDate,
    CachedProjectData? existingData,
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  }) async {
    final firestore = FirebaseFirestore.instance;
    
    // تحديد نقطة البداية للتحميل
    DateTime? lastUpdateTime = existingData?.lastUpdateTime;
    
    onStatusUpdate?.call('جاري تحميل بيانات المشروع...');
    onProgress?.call(0.1);
    
    // تحميل بيانات المشروع الأساسية
    final projectDoc = await firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.exists ? projectDoc.data()! : <String, dynamic>{};
    
    onStatusUpdate?.call('جاري تحميل المراحل الجديدة...');
    onProgress?.call(0.2);
    
    // تحميل المراحل الجديدة فقط
    Query phasesQuery = firestore
        .collection('projects')
        .doc(projectId)
        .collection('phases')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    
    if (lastUpdateTime != null) {
      phasesQuery = phasesQuery.where('lastModified', isGreaterThan: Timestamp.fromDate(lastUpdateTime));
    }
    
    final phasesSnapshot = await phasesQuery.get();
    final newPhases = <String, Map<String, dynamic>>{};
    
    for (final doc in phasesSnapshot.docs) {
      newPhases[doc.id] = doc.data() as Map<String, dynamic>;
    }
    
    onStatusUpdate?.call('جاري تحميل الصور الجديدة...');
    onProgress?.call(0.5);
    
    // تحميل الصور الجديدة
    final newImageIds = <String>{};
    final newImages = <String, CachedImageData>{};
    
    for (final phaseData in newPhases.values) {
      final images = phaseData['images'] as List<dynamic>? ?? [];
      for (final imageUrl in images) {
        if (imageUrl is String) {
          final imageId = _generateImageId(imageUrl);
          if (existingData == null || !existingData.imageIds.contains(imageId)) {
            newImageIds.add(imageId);
            // تحميل وحفظ الصورة
            final imageData = await _downloadAndCacheImage(imageUrl, imageId);
            if (imageData != null) {
              newImages[imageId] = imageData;
            }
          }
        }
      }
    }
    
    onStatusUpdate?.call('جاري تحميل طلبات المواد الجديدة...');
    onProgress?.call(0.7);
    
    // تحميل طلبات المواد الجديدة
    Query materialsQuery = firestore
        .collection('projects')
        .doc(projectId)
        .collection('material_requests')
        .where('requestDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('requestDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    
    if (lastUpdateTime != null) {
      materialsQuery = materialsQuery.where('lastModified', isGreaterThan: Timestamp.fromDate(lastUpdateTime));
    }
    
    final materialsSnapshot = await materialsQuery.get();
    final newMaterialRequests = <String, Map<String, dynamic>>{};
    
    for (final doc in materialsSnapshot.docs) {
      newMaterialRequests[doc.id] = doc.data() as Map<String, dynamic>;
    }
    
    onStatusUpdate?.call('جاري تحميل سجلات الاجتماعات الجديدة...');
    onProgress?.call(0.9);
    
    // تحميل سجلات الاجتماعات الجديدة
    Query meetingsQuery = firestore
        .collection('projects')
        .doc(projectId)
        .collection('meeting_logs')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    
    if (lastUpdateTime != null) {
      meetingsQuery = meetingsQuery.where('lastModified', isGreaterThan: Timestamp.fromDate(lastUpdateTime));
    }
    
    final meetingsSnapshot = await meetingsQuery.get();
    final newMeetingLogs = <String, Map<String, dynamic>>{};
    
    for (final doc in meetingsSnapshot.docs) {
      newMeetingLogs[doc.id] = doc.data() as Map<String, dynamic>;
    }
    
    onProgress?.call(1.0);
    
    return CachedProjectData(
      projectId: projectId,
      projectData: projectData,
      phases: newPhases,
      materialRequests: newMaterialRequests,
      meetingLogs: newMeetingLogs,
      images: newImages,
      imageIds: newImageIds,
      lastUpdateTime: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
    );
  }
  
  /// دمج البيانات القديمة مع الجديدة
  static CachedProjectData _mergeProjectData(
    CachedProjectData? existingData,
    CachedProjectData newData,
  ) {
    if (existingData == null) {
      return newData;
    }
    
    // دمج المراحل
    final mergedPhases = Map<String, Map<String, dynamic>>.from(existingData.phases);
    mergedPhases.addAll(newData.phases);
    
    // دمج طلبات المواد
    final mergedMaterialRequests = Map<String, Map<String, dynamic>>.from(existingData.materialRequests);
    mergedMaterialRequests.addAll(newData.materialRequests);
    
    // دمج سجلات الاجتماعات
    final mergedMeetingLogs = Map<String, Map<String, dynamic>>.from(existingData.meetingLogs);
    mergedMeetingLogs.addAll(newData.meetingLogs);
    
    // دمج الصور
    final mergedImages = Map<String, CachedImageData>.from(existingData.images);
    mergedImages.addAll(newData.images);
    
    // دمج معرفات الصور
    final mergedImageIds = Set<String>.from(existingData.imageIds);
    mergedImageIds.addAll(newData.imageIds);
    
    return CachedProjectData(
      projectId: newData.projectId,
      projectData: newData.projectData.isNotEmpty ? newData.projectData : existingData.projectData,
      phases: mergedPhases,
      materialRequests: mergedMaterialRequests,
      meetingLogs: mergedMeetingLogs,
      images: mergedImages,
      imageIds: mergedImageIds,
      lastUpdateTime: newData.lastUpdateTime,
      startDate: newData.startDate,
      endDate: newData.endDate,
    );
  }
  
  /// الحصول على وقت آخر تحديث من Firestore
  static Future<DateTime> _getLatestUpdateTime(
    String projectId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // البحث عن آخر تحديث في المراحل
      final phasesQuery = await firestore
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('lastModified', descending: true)
          .limit(1)
          .get();
      
      DateTime latestTime = startDate;
      
      if (phasesQuery.docs.isNotEmpty) {
        final lastModified = phasesQuery.docs.first.data()['lastModified'] as Timestamp?;
        if (lastModified != null) {
          latestTime = lastModified.toDate();
        }
      }
      
      // فحص طلبات المواد
      final materialsQuery = await firestore
          .collection('projects')
          .doc(projectId)
          .collection('material_requests')
          .orderBy('lastModified', descending: true)
          .limit(1)
          .get();
      
      if (materialsQuery.docs.isNotEmpty) {
        final lastModified = materialsQuery.docs.first.data()['lastModified'] as Timestamp?;
        if (lastModified != null && lastModified.toDate().isAfter(latestTime)) {
          latestTime = lastModified.toDate();
        }
      }
      
      return latestTime;
    } catch (e) {
      print('Error getting latest update time: $e');
      return DateTime.now();
    }
  }
  
  /// تنزيل وحفظ الصورة
  static Future<CachedImageData?> _downloadAndCacheImage(String imageUrl, String imageId) async {
    try {
      if (kIsWeb) {
        // للويب، حفظ الرابط فقط
        return CachedImageData(
          imageId: imageId,
          imageUrl: imageUrl,
          localPath: null,
          cachedAt: DateTime.now(),
        );
      }
      
      // للموبايل، تنزيل وحفظ الصورة محلياً
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      final bytes = await response.expand((chunk) => chunk).toList();
      
      final imagePath = '${_imageCacheDir!.path}/$imageId.jpg';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(bytes);
      
      return CachedImageData(
        imageId: imageId,
        imageUrl: imageUrl,
        localPath: imagePath,
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error downloading and caching image: $e');
      return null;
    }
  }
  
  /// حفظ بيانات المشروع المؤقتة
  static Future<void> _saveCachedProjectData(String cacheKey, CachedProjectData data) async {
    try {
      if (kIsWeb) {
        // للويب، حفظ في localStorage
        final jsonData = data.toJson();
        await _prefs?.setString('project_cache_$cacheKey', jsonEncode(jsonData));
        return;
      }
      
      // للموبايل، حفظ في ملف
      final cacheFile = File('${_dataCacheDir!.path}/$cacheKey.json');
      final jsonData = data.toJson();
      await cacheFile.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('Error saving cached project data: $e');
    }
  }
  
  /// تحميل بيانات المشروع المؤقتة
  static Future<CachedProjectData?> _loadCachedProjectData(String cacheKey) async {
    try {
      String? jsonString;
      
      if (kIsWeb) {
        // للويب، تحميل من localStorage
        jsonString = _prefs?.getString('project_cache_$cacheKey');
      } else {
        // للموبايل، تحميل من ملف
        final cacheFile = File('${_dataCacheDir!.path}/$cacheKey.json');
        if (await cacheFile.exists()) {
          jsonString = await cacheFile.readAsString();
        }
      }
      
      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        return CachedProjectData.fromJson(jsonData);
      }
      
      return null;
    } catch (e) {
      print('Error loading cached project data: $e');
      return null;
    }
  }
  
  /// تحميل البيانات المحفوظة إلى الذاكرة
  static Future<void> _loadCachedDataToMemory() async {
    try {
      if (kIsWeb) {
        // للويب، تحميل من localStorage
        final keys = _prefs?.getKeys().where((key) => key.startsWith('project_cache_')) ?? [];
        for (final key in keys) {
          final cacheKey = key.replaceFirst('project_cache_', '');
          final cachedData = await _loadCachedProjectData(cacheKey);
          if (cachedData != null) {
            _memoryCache[cacheKey] = cachedData;
            _lastUpdateTimes[cacheKey] = cachedData.lastUpdateTime;
          }
        }
      } else {
        // للموبايل، تحميل من الملفات
        if (_dataCacheDir != null && await _dataCacheDir!.exists()) {
          final files = _dataCacheDir!.listSync().where((file) => file.path.endsWith('.json'));
          for (final file in files) {
            final fileName = file.path.split('/').last;
            final cacheKey = fileName.replaceFirst('.json', '');
            final cachedData = await _loadCachedProjectData(cacheKey);
            if (cachedData != null) {
              _memoryCache[cacheKey] = cachedData;
              _lastUpdateTimes[cacheKey] = cachedData.lastUpdateTime;
            }
          }
        }
      }
      
      print('Loaded ${_memoryCache.length} cached projects to memory');
    } catch (e) {
      print('Error loading cached data to memory: $e');
    }
  }
  
  /// تنظيف البيانات القديمة
  static Future<void> _cleanupOldCache() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      // تنظيف الذاكرة
      _memoryCache.removeWhere((key, data) => data.lastUpdateTime.isBefore(cutoffDate));
      _lastUpdateTimes.removeWhere((key, time) => time.isBefore(cutoffDate));
      
      if (!kIsWeb && _dataCacheDir != null && await _dataCacheDir!.exists()) {
        // تنظيف الملفات القديمة
        final files = _dataCacheDir!.listSync();
        for (final file in files) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
          }
        }
      }
      
      print('Cache cleanup completed');
    } catch (e) {
      print('Error during cache cleanup: $e');
    }
  }
  
  /// إنشاء مفتاح التخزين المؤقت
  static String _generateCacheKey(String projectId, DateTime startDate, DateTime endDate) {
    final keyString = '${projectId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
    final bytes = utf8.encode(keyString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// إنشاء معرف الصورة
  static String _generateImageId(String imageUrl) {
    final bytes = utf8.encode(imageUrl);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// مسح الذاكرة المؤقتة
  static Future<void> clearCache() async {
    _memoryCache.clear();
    _lastUpdateTimes.clear();
    _cachedImageIds.clear();
    
    if (!kIsWeb) {
      if (_dataCacheDir != null && await _dataCacheDir!.exists()) {
        await _dataCacheDir!.delete(recursive: true);
        await _dataCacheDir!.create(recursive: true);
      }
      
      if (_imageCacheDir != null && await _imageCacheDir!.exists()) {
        await _imageCacheDir!.delete(recursive: true);
        await _imageCacheDir!.create(recursive: true);
      }
    }
    
    print('Cache cleared successfully');
  }
  
  /// الحصول على حجم التخزين المؤقت
  static Future<int> getCacheSize() async {
    int totalSize = 0;
    
    try {
      if (!kIsWeb && _cacheDir != null && await _cacheDir!.exists()) {
        final files = _cacheDir!.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            totalSize += stat.size;
          }
        }
      }
    } catch (e) {
      print('Error calculating cache size: $e');
    }
    
    return totalSize;
  }
}

/// فئة بيانات المشروع المؤقتة
class CachedProjectData {
  final String projectId;
  final Map<String, dynamic> projectData;
  final Map<String, Map<String, dynamic>> phases;
  final Map<String, Map<String, dynamic>> materialRequests;
  final Map<String, Map<String, dynamic>> meetingLogs;
  final Map<String, CachedImageData> images;
  final Set<String> imageIds;
  final DateTime lastUpdateTime;
  final DateTime startDate;
  final DateTime endDate;
  
  CachedProjectData({
    required this.projectId,
    required this.projectData,
    required this.phases,
    required this.materialRequests,
    required this.meetingLogs,
    required this.images,
    required this.imageIds,
    required this.lastUpdateTime,
    required this.startDate,
    required this.endDate,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'projectData': projectData,
      'phases': phases,
      'materialRequests': materialRequests,
      'meetingLogs': meetingLogs,
      'images': images.map((key, value) => MapEntry(key, value.toJson())),
      'imageIds': imageIds.toList(),
      'lastUpdateTime': lastUpdateTime.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }
  
  factory CachedProjectData.fromJson(Map<String, dynamic> json) {
    final imagesMap = <String, CachedImageData>{};
    if (json['images'] != null) {
      final imagesJson = json['images'] as Map<String, dynamic>;
      for (final entry in imagesJson.entries) {
        imagesMap[entry.key] = CachedImageData.fromJson(entry.value);
      }
    }
    
    return CachedProjectData(
      projectId: json['projectId'] ?? '',
      projectData: Map<String, dynamic>.from(json['projectData'] ?? {}),
      phases: Map<String, Map<String, dynamic>>.from(
        json['phases']?.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))) ?? {},
      ),
      materialRequests: Map<String, Map<String, dynamic>>.from(
        json['materialRequests']?.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))) ?? {},
      ),
      meetingLogs: Map<String, Map<String, dynamic>>.from(
        json['meetingLogs']?.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))) ?? {},
      ),
      images: imagesMap,
      imageIds: Set<String>.from(json['imageIds'] ?? []),
      lastUpdateTime: DateTime.parse(json['lastUpdateTime']),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
    );
  }
}

/// فئة بيانات الصورة المؤقتة
class CachedImageData {
  final String imageId;
  final String imageUrl;
  final String? localPath;
  final DateTime cachedAt;
  
  CachedImageData({
    required this.imageId,
    required this.imageUrl,
    this.localPath,
    required this.cachedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'imageId': imageId,
      'imageUrl': imageUrl,
      'localPath': localPath,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }
  
  factory CachedImageData.fromJson(Map<String, dynamic> json) {
    return CachedImageData(
      imageId: json['imageId'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      localPath: json['localPath'],
      cachedAt: DateTime.parse(json['cachedAt']),
    );
  }
}

/// فئة بيانات التقرير الشامل
class ComprehensiveReportData {
  final String projectId;
  final Map<String, dynamic> projectData;
  final Map<String, Map<String, dynamic>> phases;
  final Map<String, Map<String, dynamic>> materialRequests;
  final Map<String, Map<String, dynamic>> meetingLogs;
  final Map<String, CachedImageData> images;
  final DateTime generatedAt;
  
  ComprehensiveReportData({
    required this.projectId,
    required this.projectData,
    required this.phases,
    required this.materialRequests,
    required this.meetingLogs,
    required this.images,
    required this.generatedAt,
  });
  
  factory ComprehensiveReportData.fromCachedData(CachedProjectData cachedData) {
    return ComprehensiveReportData(
      projectId: cachedData.projectId,
      projectData: cachedData.projectData,
      phases: cachedData.phases,
      materialRequests: cachedData.materialRequests,
      meetingLogs: cachedData.meetingLogs,
      images: cachedData.images,
      generatedAt: DateTime.now(),
    );
  }
}
