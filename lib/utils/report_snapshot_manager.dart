import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'advanced_cache_manager.dart';
import 'concurrent_operations_manager.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// مدير Snapshot التقارير للوصول السريع للبيانات
class ReportSnapshotManager {
  static const Duration _snapshotCacheExpiry = Duration(hours: 2);
  static const Duration _snapshotGenerationTimeout = Duration(minutes: 5);
  
  /// الحصول على Snapshot من الكاش أو Firestore
  static Future<Map<String, dynamic>?> getReportSnapshot({
    required String projectId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    void Function(String status)? onStatusUpdate,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onStatusUpdate?.call('جاري البحث عن Snapshot...');
      
      // إنشاء مفتاح الكاش
      final cacheKey = _generateCacheKey(projectId, startDate, endDate);
      
      // فحص الكاش أولاً - هذا هو الأسرع
      if (!forceRefresh) {
        final cachedSnapshot = await AdvancedCacheManager.getCachedData(cacheKey);
        if (cachedSnapshot != null) {
          onStatusUpdate?.call('تم العثور على Snapshot في الكاش');
          onProgress?.call(1.0);
          return cachedSnapshot;
        }
      }
      
      // فحص سريع لوجود البيانات قبل البحث في Firestore
      final hasData = await _quickDataCheck(projectId, startDate, endDate);
      
      if (!hasData) {
        // لا توجد بيانات - إنشاء snapshot فارغ فوراً
        onStatusUpdate?.call('لا توجد بيانات، إنشاء تقرير فارغ...');
        onProgress?.call(0.5);
        
        final emptySnapshot = _createEmptySnapshot(startDate, endDate);
        
        // حفظ في الكاش
        await _cacheSnapshot(cacheKey, emptySnapshot);
        onStatusUpdate?.call('تم إنشاء تقرير فارغ بنجاح');
        onProgress?.call(1.0);
        
        return emptySnapshot;
      }
      
      // البحث في Firestore فقط إذا كانت هناك بيانات
      onStatusUpdate?.call('جاري البحث في قاعدة البيانات...');
      final snapshot = await _getSnapshotFromFirestore(projectId, startDate, endDate);
      
      if (snapshot != null) {
        await _cacheSnapshot(cacheKey, snapshot);
        onStatusUpdate?.call('تم العثور على Snapshot في قاعدة البيانات');
        onProgress?.call(1.0);
        return snapshot;
      }
      
      // إنشاء Snapshot جديد فقط إذا كانت هناك بيانات
      onStatusUpdate?.call('جاري إنشاء Snapshot جديد...');
      final newSnapshot = await _generateSnapshot(projectId, startDate, endDate, onStatusUpdate, onProgress);
      
      if (newSnapshot != null) {
        await _cacheSnapshot(cacheKey, newSnapshot);
        onStatusUpdate?.call('تم إنشاء Snapshot جديد بنجاح');
        onProgress?.call(1.0);
        return newSnapshot;
      }
      
      return null;
      
    } catch (e) {
      onStatusUpdate?.call('خطأ في الحصول على Snapshot: $e');
      print('Error getting report snapshot: $e');
      return null;
    }
  }
  
  /// البحث عن Snapshot في Firestore
  static Future<Map<String, dynamic>?> _getSnapshotFromFirestore(
    String projectId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      if (startDate != null && endDate != null) {
        // البحث عن Snapshot محدد بفترة زمنية
        final timeRangeId = '${projectId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
        final doc = await FirebaseFirestore.instance
            .collection('report_snapshots')
            .doc(timeRangeId)
            .get();
        
        if (doc.exists) {
          return doc.data();
        }
      }
      
      // البحث عن Snapshot شامل
      final doc = await FirebaseFirestore.instance
          .collection('report_snapshots')
          .doc(projectId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final lastUpdated = data['reportMetadata']?['generatedAt'] as Timestamp?;
        
        // فحص إذا كان Snapshot حديث (أقل من ساعتين)
        if (lastUpdated != null) {
          final snapshotAge = DateTime.now().difference(lastUpdated.toDate());
          if (snapshotAge < _snapshotCacheExpiry) {
            return data;
          }
        }
      }
      
      return null;
      
    } catch (e) {
      print('Error getting snapshot from Firestore: $e');
      return null;
    }
  }
  
  /// إنشاء Snapshot جديد محلياً
  static Future<Map<String, dynamic>?> _generateSnapshot(
    String projectId,
    DateTime? startDate,
    DateTime? endDate,
    void Function(String status)? onStatusUpdate,
    void Function(double progress)? onProgress,
  ) async {
    try {
      onStatusUpdate?.call('جاري تجميع البيانات محلياً...');
      onProgress?.call(0.3);
      
      // استخدام العمليات المتوازية لتجميع البيانات
      final snapshot = await ConcurrentOperationsManager.executeOperation(
        operationId: 'snapshot_$projectId',
        operation: () => _buildSnapshotLocally(projectId, startDate, endDate),
        priority: 2, // أولوية عالية للتقارير
      );
      
      if (snapshot != null) {
        onStatusUpdate?.call('تم تجميع البيانات بنجاح');
        onProgress?.call(0.8);
        
        // حفظ Snapshot في Firestore بشكل متوازي
        await ConcurrentOperationsManager.executeOperation(
          operationId: 'save_snapshot_$projectId',
          operation: () => _saveSnapshotToFirestore(projectId, startDate, endDate, snapshot),
          priority: 1,
        );
        
        return snapshot;
      }
      
      return null;
      
    } catch (e) {
      print('Error generating snapshot: $e');
      return null;
    }
  }
  
  /// بناء Snapshot محلياً
  static Future<Map<String, dynamic>?> _buildSnapshotLocally(
    String projectId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      final phasesData = <Map<String, dynamic>>[];
      final testsData = <Map<String, dynamic>>[];
      final materialsData = <Map<String, dynamic>>[];
      final imagesData = <Map<String, dynamic>>[];
      
      // تجميع بيانات المراحل
      final phasesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('phases_status')
          .get();
      
      for (final phaseDoc in phasesSnapshot.docs) {
        final entriesSnapshot = await phaseDoc.reference.collection('entries').get();
        for (final entry in entriesSnapshot.docs) {
          final data = entry.data();
          if (_isInDateRange(data['timestamp'], startDate, endDate)) {
            phasesData.add(data);
          }
        }
      }
      
      // تجميع بيانات الاختبارات
      final testsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('tests_status')
          .get();
      
      for (final testDoc in testsSnapshot.docs) {
        final data = testDoc.data();
        if (_isInDateRange(data['lastUpdatedAt'], startDate, endDate)) {
          testsData.add(data);
        }
      }
      
      // تجميع بيانات طلبات المواد
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('partRequests')
          .where('projectId', isEqualTo: projectId)
          .get();
      
      for (final materialDoc in materialsSnapshot.docs) {
        final data = materialDoc.data();
        if (_isInDateRange(data['requestedAt'], startDate, endDate)) {
          materialsData.add(data);
        }
      }
      
      return {
        'phasesData': phasesData,
        'testsData': testsData,
        'materialsData': materialsData,
        'imagesData': imagesData,
        'reportMetadata': {
          'generatedAt': Timestamp.now(),
          'isFullReport': startDate == null && endDate == null,
          'totalDataSize': phasesData.length + testsData.length + materialsData.length,
        },
      };
      
    } catch (e) {
      print('Error building snapshot locally: $e');
      return null;
    }
  }
  
  /// فحص إذا كان التاريخ في النطاق المحدد
  static bool _isInDateRange(dynamic timestamp, DateTime? startDate, DateTime? endDate) {
    if (timestamp == null || startDate == null || endDate == null) return true;
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return date.isAfter(startDate) && date.isBefore(endDate);
    }
    return true;
  }
  
  /// حفظ Snapshot في Firestore
  static Future<void> _saveSnapshotToFirestore(
    String projectId,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic> snapshot,
  ) async {
    try {
      String docId;
      if (startDate != null && endDate != null) {
        docId = '${projectId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
      } else {
        docId = projectId;
      }
      
      await FirebaseFirestore.instance
          .collection('report_snapshots')
          .doc(docId)
          .set(snapshot);
          
    } catch (e) {
      print('Error saving snapshot to Firestore: $e');
    }
  }
  
  /// حفظ Snapshot في الكاش
  static Future<void> _cacheSnapshot(String cacheKey, Map<String, dynamic> snapshot) async {
    try {
      await AdvancedCacheManager.cacheData(
        key: cacheKey,
        data: snapshot,
        expiry: _snapshotCacheExpiry,
        priority: 2, // أولوية عالية للتقارير
      );
    } catch (e) {
      print('Error caching snapshot: $e');
    }
  }
  
  /// إنشاء مفتاح كاش فريد
  static String _generateCacheKey(String projectId, DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null) {
      return 'snapshot_${projectId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
    }
    return 'snapshot_${projectId}_full';
  }
  
  /// تنظيف Snapshots القديمة
  static Future<void> cleanupOldSnapshots() async {
    try {
      // حذف Snapshots الأقدم من 7 أيام
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshots = await FirebaseFirestore.instance
          .collection('report_snapshots')
          .where('reportMetadata.generatedAt', isLessThan: Timestamp.fromDate(weekAgo))
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Cleaned up ${snapshots.docs.length} old snapshots');
      
    } catch (e) {
      print('Error cleaning up old snapshots: $e');
    }
  }
  
  /// الحصول على إحصائيات Snapshots
  static Future<Map<String, dynamic>> getSnapshotStats() async {
    try {
      final snapshots = await FirebaseFirestore.instance
          .collection('report_snapshots')
          .get();
      
      int totalSize = 0;
      int fullSnapshots = 0;
      int timeRangeSnapshots = 0;
      
      for (final doc in snapshots.docs) {
        final data = doc.data();
        final dataSize = data['reportMetadata']?['totalDataSize'];
        if (dataSize != null) {
          totalSize += (dataSize is int) ? dataSize : int.tryParse(dataSize.toString()) ?? 0;
        }
        
        if (data['reportMetadata']?['isFullReport'] == true) {
          fullSnapshots++;
        } else {
          timeRangeSnapshots++;
        }
      }
      
      return {
        'totalSnapshots': snapshots.docs.length,
        'fullSnapshots': fullSnapshots,
        'timeRangeSnapshots': timeRangeSnapshots,
        'totalDataSize': totalSize,
        'averageDataSize': snapshots.docs.isNotEmpty ? totalSize / snapshots.docs.length : 0,
      };
      
    } catch (e) {
      print('Error getting snapshot stats: $e');
      return {};
    }
  }

/// فحص سريع لوجود البيانات (بدون Firebase)
static Future<bool> _quickDataCheck(String projectId, DateTime? startDate, DateTime? endDate) async {
  try {
    // فحص محلي سريع - البحث في الكاش أولاً
    final cacheKey = _generateCacheKey(projectId, startDate, endDate);
    final cachedData = await AdvancedCacheManager.getCachedData(cacheKey);
    
    if (cachedData != null) {
      // إذا كان هناك بيانات في الكاش، فهناك بيانات
      return true;
    }
    
    // فحص سريع واحد فقط في Firebase
    final quickCheck = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('phases_status')
        .limit(1)
        .get();
    
    return quickCheck.docs.isNotEmpty;
    
  } catch (e) {
    print('Error in quick data check: $e');
    return false;
  }
}

/// إنشاء snapshot فارغ (بدون عمليات Firebase)
static Map<String, dynamic> _createEmptySnapshot(DateTime? startDate, DateTime? endDate) {
  return {
    'phasesData': [],
    'testsData': [],
    'materialsData': [],
    'imagesData': [],
    'reportMetadata': {
      'generatedAt': Timestamp.now(),
      'isFullReport': startDate == null && endDate == null,
      'totalDataSize': 0,
      'isEmpty': true,
      'generatedAt': DateTime.now().toIso8601String(), // تحويل إلى string لتجنب مشكلة Timestamp
    },
  };
}

}
