import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'advanced_cache_manager.dart';
import 'concurrent_operations_manager.dart';

/// مدير Snapshot التقارير للوصول السريع للبيانات
class ReportSnapshotManager {
  static const Duration _snapshotCacheExpiry = Duration(hours: 2);
  
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
      print('Building snapshot locally for project: $projectId');
      final phasesData = <Map<String, dynamic>>[];
      final testsData = <Map<String, dynamic>>[];
      final materialsData = <Map<String, dynamic>>[];
      final imagesData = <Map<String, dynamic>>[];
      
      // تجميع بيانات المراحل - تحسين الهيكل ليتوافق مع Cloud Function
      final phasesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('phases_status')
          .get();
      
      print('Found ${phasesSnapshot.docs.length} phases');
      
      for (final phaseDoc in phasesSnapshot.docs) {
        final phaseData = phaseDoc.data();
        final phaseId = phaseDoc.id;
        final phaseName = phaseData['name'] ?? phaseId;
        
        // تجميع الإدخالات لكل مرحلة - مع fallback للمجموعات البديلة
        var entriesSnapshot = await phaseDoc.reference.collection('entries').get();
        print('Found ${entriesSnapshot.docs.length} entries for phase $phaseId in phases_status');
        
        // إذا لم توجد إدخالات في phases_status، جرب phases
        if (entriesSnapshot.docs.isEmpty) {
          entriesSnapshot = await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('phases')
              .doc(phaseId)
              .collection('entries')
              .get();
          print('Found ${entriesSnapshot.docs.length} entries for phase $phaseId in phases (alternative)');
        }
        
        final phaseEntries = <Map<String, dynamic>>[];
        for (final entry in entriesSnapshot.docs) {
          final entryData = entry.data();
          if (entryData.isEmpty) {
            print('Skipping entry ${entry.id} - no data');
            continue;
          }

          // فحص وجود محتوى فعلي
          final hasNotes = entryData['notes'] != null && entryData['notes'].toString().trim().isNotEmpty;
          final hasImages = (entryData['imageUrls'] != null && (entryData['imageUrls'] as List).isNotEmpty) ||
                           (entryData['otherImages'] != null && (entryData['otherImages'] as List).isNotEmpty) ||
                           (entryData['otherImageUrls'] != null && (entryData['otherImageUrls'] as List).isNotEmpty) ||
                           (entryData['beforeImages'] != null && (entryData['beforeImages'] as List).isNotEmpty) ||
                           (entryData['beforeImageUrls'] != null && (entryData['beforeImageUrls'] as List).isNotEmpty) ||
                           (entryData['afterImages'] != null && (entryData['afterImages'] as List).isNotEmpty) ||
                           (entryData['afterImageUrls'] != null && (entryData['afterImageUrls'] as List).isNotEmpty);
          final hasStatus = entryData['status'] != null;

          final hasContent = hasNotes || hasImages || hasStatus;

          if (!hasContent) {
            print('Skipping empty entry ${entry.id}');
            continue;
          }

          print('Including entry ${entry.id} with content: notes=$hasNotes, images=$hasImages, status=$hasStatus');
          
          // إضافة معلومات المرحلة لكل إدخال
          final entryWithMeta = {
            'id': entry.id,
            ...entryData,
            'phaseId': phaseId,
            'phaseName': phaseName,
            'collectionType': 'main_phase',
          };
          phaseEntries.add(entryWithMeta);
          
          // تجميع الصور من الإدخال
          _extractImagesFromEntry(entryData, imagesData);
        }
        
        // إضافة المرحلة مع إدخالاتها
        phasesData.add({
          'id': phaseId,
          'name': phaseName,
          'entries': phaseEntries,
          'entryCount': phaseEntries.length,
        });
      }
      
      // تجميع بيانات المراحل الفرعية أيضاً
      final subphasesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('subphases_status')
          .get();
      
      print('Found ${subphasesSnapshot.docs.length} subphases');
      
      for (final subphaseDoc in subphasesSnapshot.docs) {
        final subphaseData = subphaseDoc.data();
        final subphaseId = subphaseDoc.id;
        final subphaseName = subphaseData['name'] ?? subphaseId;
        
        var entriesSnapshot = await subphaseDoc.reference.collection('entries').get();
        print('Found ${entriesSnapshot.docs.length} entries for subphase $subphaseId in subphases_status');
        
        // إذا لم توجد إدخالات في subphases_status، جرب subphases
        if (entriesSnapshot.docs.isEmpty) {
          entriesSnapshot = await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('subphases')
              .doc(subphaseId)
              .collection('entries')
              .get();
          print('Found ${entriesSnapshot.docs.length} entries for subphase $subphaseId in subphases (alternative)');
        }
        
        final subphaseEntries = <Map<String, dynamic>>[];
        for (final entry in entriesSnapshot.docs) {
          final entryData = entry.data();
          if (entryData.isEmpty) {
            print('Skipping subphase entry ${entry.id} - no data');
            continue;
          }

          // فحص وجود محتوى فعلي
          final hasNotes = entryData['notes'] != null && entryData['notes'].toString().trim().isNotEmpty;
          final hasImages = (entryData['imageUrls'] != null && (entryData['imageUrls'] as List).isNotEmpty) ||
                           (entryData['otherImages'] != null && (entryData['otherImages'] as List).isNotEmpty) ||
                           (entryData['beforeImages'] != null && (entryData['beforeImages'] as List).isNotEmpty) ||
                           (entryData['afterImages'] != null && (entryData['afterImages'] as List).isNotEmpty);
          final hasStatus = entryData['status'] != null;

          final hasContent = hasNotes || hasImages || hasStatus;

          if (!hasContent) {
            print('Skipping empty subphase entry ${entry.id}');
            continue;
          }

          print('Including subphase entry ${entry.id} with content: notes=$hasNotes, images=$hasImages, status=$hasStatus');
          final entryWithMeta = {
            'id': entry.id,
            ...entryData,
            'subphaseId': subphaseId,
            'subphaseName': subphaseName,
            'collectionType': 'sub_phase',
          };
          subphaseEntries.add(entryWithMeta);
          
          // تجميع الصور من الإدخال
          _extractImagesFromEntry(entryData, imagesData);
        }
        
        // إضافة المرحلة الفرعية مع إدخالاتها
        phasesData.add({
          'id': subphaseId,
          'name': subphaseName,
          'entries': subphaseEntries,
          'entryCount': subphaseEntries.length,
          'isSubphase': true,
        });
      }
      
      // تجميع بيانات الاختبارات
      final testsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('tests_status')
          .get();
      
      print('Found ${testsSnapshot.docs.length} tests');
      
      for (final testDoc in testsSnapshot.docs) {
        final data = testDoc.data();
        if (_isInDateRange(data['lastUpdatedAt'], startDate, endDate)) {
          testsData.add({
            'id': testDoc.id,
            ...data,
            'collectionType': 'test',
          });
        }
      }
      
      // تجميع بيانات طلبات المواد
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('partRequests')
          .where('projectId', isEqualTo: projectId)
          .get();
      
      print('Found ${materialsSnapshot.docs.length} material requests');
      
      for (final materialDoc in materialsSnapshot.docs) {
        final data = materialDoc.data();
        if (_isInDateRange(data['requestedAt'], startDate, endDate)) {
          materialsData.add({
            'id': materialDoc.id,
            ...data,
            'collectionType': 'material_request',
          });
        }
      }
      
      final totalEntries = phasesData.fold<int>(0, (sum, phase) => sum + (phase['entryCount'] as int? ?? 0));
      
      print('Snapshot built - Phases: ${phasesData.length}, Entries: $totalEntries, Tests: ${testsData.length}, Materials: ${materialsData.length}, Images: ${imagesData.length}');
      
      return {
        'version': 2,
        'projectId': projectId,
        'phasesData': phasesData,
        'testsData': testsData,
        'materialsData': materialsData,
        'imagesData': imagesData,
        'summaryStats': {
          'totalEntries': totalEntries,
          'totalImages': imagesData.length,
          'totalTests': testsData.length,
          'totalRequests': materialsData.length,
          'lastUpdated': Timestamp.now(),
        },
        'reportMetadata': {
          'generatedAt': Timestamp.now(),
          'startDate': startDate,
          'endDate': endDate,
          'isFullReport': startDate == null && endDate == null,
          'totalDataSize': totalEntries + testsData.length + materialsData.length,
          'imageCount': imagesData.length,
          'entryCount': totalEntries,
          'testCount': testsData.length,
          'requestCount': materialsData.length,
        },
      };
      
    } catch (e) {
      print('Error building snapshot locally: $e');
      return null;
    }
  }

  /// استخراج الصور من إدخال معين
  static void _extractImagesFromEntry(Map<String, dynamic> entryData, List<Map<String, dynamic>> imagesData) {
    try {
      // دعم أشكال مختلفة من حقول الصور
      final imageFields = ['imageUrls', 'otherImages', 'otherImageUrls', 'beforeImageUrls', 'beforeImages', 'afterImageUrls', 'afterImages'];
      
      for (final field in imageFields) {
        final urls = entryData[field] as List?;
        if (urls != null) {
          for (final url in urls) {
            if (url != null && url.toString().isNotEmpty) {
              imagesData.add({
                'url': url.toString(),
                'field': field,
                'entryId': entryData['id'],
                'timestamp': entryData['timestamp'],
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error extracting images from entry: $e');
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
    },
  };
}



}
