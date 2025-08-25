import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// مدير الفهرسة الذكية لتحسين الاستعلامات
class SmartIndexingManager {
  static const Map<String, List<String>> _requiredIndexes = {
    'phases_status': [
      'projectId,lastUpdatedAt',
      'projectId,phaseId,lastUpdatedAt',
      'projectId,status,lastUpdatedAt',
    ],
    'tests_status': [
      'projectId,lastUpdatedAt',
      'projectId,testType,lastUpdatedAt',
      'projectId,status,lastUpdatedAt',
    ],
    'partRequests': [
      'projectId,requestedAt',
      'projectId,status,requestedAt',
      'projectId,priority,requestedAt',
    ],
    'images': [
      'projectId,uploadedAt',
      'projectId,phaseId,uploadedAt',
      'projectId,entryId,uploadedAt',
    ],
  };
  
  /// إنشاء الفهارس المطلوبة
  static Future<void> createRequiredIndexes() async {
    try {
      for (final collection in _requiredIndexes.keys) {
        for (final indexFields in _requiredIndexes[collection]!) {
          await _createCompositeIndex(collection, indexFields);
        }
      }
      print('Required indexes created successfully');
    } catch (e) {
      print('Error creating indexes: $e');
    }
  }
  
  /// إنشاء فهرس مركب
  static Future<void> _createCompositeIndex(
    String collection,
    String indexFields,
  ) async {
    try {
      final fields = indexFields.split(',');
      final indexConfig = <String, String>{};
      
      for (final field in fields) {
        indexConfig[field.trim()] = 'ASCENDING';
      }
      
      // إنشاء الفهرس في Firestore
      await FirebaseFirestore.instance
          .collection('_indexes')
          .doc('${collection}_${indexFields.replaceAll(',', '_')}')
          .set({
        'collection': collection,
        'fields': indexConfig,
        'createdAt': Timestamp.now(),
      });
      
    } catch (e) {
      print('Error creating index for $collection: $e');
    }
  }
  
  /// فحص وجود الفهارس
  static Future<bool> checkIndexesExist() async {
    try {
      for (final collection in _requiredIndexes.keys) {
        for (final indexFields in _requiredIndexes[collection]!) {
          final indexId = '${collection}_${indexFields.replaceAll(',', '_')}';
          final indexDoc = await FirebaseFirestore.instance
              .collection('_indexes')
              .doc(indexId)
              .get();
          
          if (!indexDoc.exists) {
            print('Missing index: $indexId');
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('Error checking indexes: $e');
      return false;
    }
  }
}
