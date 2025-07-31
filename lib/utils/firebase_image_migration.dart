
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'image_upload_service.dart';

class FirebaseImageMigration {
  /// نقل جميع الصور من Firebase Storage إلى الخادم الجديد
  static Future<void> migrateAllImages({
    void Function(String status)? onStatusUpdate,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onStatusUpdate?.call('بدء عملية النقل...');
      
      // الحصول على جميع المشاريع
      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .get();
      
      int totalProjects = projectsSnapshot.docs.length;
      int completedProjects = 0;
      
      for (final projectDoc in projectsSnapshot.docs) {
        final projectId = projectDoc.id;
        onStatusUpdate?.call('نقل صور المشروع: $projectId');
        
        // نقل صور المراحل
        await _migratePhaseImages(projectId);
        
        // نقل صور المراحل الفرعية
        await _migrateSubPhaseImages(projectId);
        
        // نقل صور الاختبارات
        await _migrateTestImages(projectId);
        
        completedProjects++;
        onProgress?.call(completedProjects / totalProjects);
      }
      
      onStatusUpdate?.call('تم الانتهاء من نقل جميع الصور');
      
    } catch (e) {
      onStatusUpdate?.call('خطأ في عملية النقل: $e');
    }
  }
  
  static Future<void> _migratePhaseImages(String projectId) async {
    final phasesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('phases_status')
        .get();
    
    for (final phaseDoc in phasesSnapshot.docs) {
      final entriesSnapshot = await phaseDoc.reference
          .collection('entries')
          .get();
      
      for (final entryDoc in entriesSnapshot.docs) {
        final data = entryDoc.data();
        bool needsUpdate = false;
        Map<String, dynamic> updates = {};
        
        // نقل imageUrls
        if (data['imageUrls'] != null) {
          final newUrls = await _migrateImageList(
            data['imageUrls'] as List,
            projectId,
            'phases',
          );
          if (newUrls.isNotEmpty) {
            updates['imageUrls'] = newUrls;
            needsUpdate = true;
          }
        }
        
        // نقل beforeImageUrls
        if (data['beforeImageUrls'] != null) {
          final newUrls = await _migrateImageList(
            data['beforeImageUrls'] as List,
            projectId,
            'phases',
          );
          if (newUrls.isNotEmpty) {
            updates['beforeImageUrls'] = newUrls;
            needsUpdate = true;
          }
        }
        
        // نقل afterImageUrls
        if (data['afterImageUrls'] != null) {
          final newUrls = await _migrateImageList(
            data['afterImageUrls'] as List,
            projectId,
            'phases',
          );
          if (newUrls.isNotEmpty) {
            updates['afterImageUrls'] = newUrls;
            needsUpdate = true;
          }
        }
        
        if (needsUpdate) {
          await entryDoc.reference.update(updates);
        }
      }
    }
  }
  
  static Future<void> _migrateSubPhaseImages(String projectId) async {
    final subPhasesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('subphases_status')
        .get();
    
    for (final subPhaseDoc in subPhasesSnapshot.docs) {
      final entriesSnapshot = await subPhaseDoc.reference
          .collection('entries')
          .get();
      
      for (final entryDoc in entriesSnapshot.docs) {
        final data = entryDoc.data();
        bool needsUpdate = false;
        Map<String, dynamic> updates = {};
        
        // نقل جميع أنواع الصور كما في المراحل الرئيسية
        final imageFields = ['imageUrls', 'beforeImageUrls', 'afterImageUrls'];
        
        for (final field in imageFields) {
          if (data[field] != null) {
            final newUrls = await _migrateImageList(
              data[field] as List,
              projectId,
              'subphases',
            );
            if (newUrls.isNotEmpty) {
              updates[field] = newUrls;
              needsUpdate = true;
            }
          }
        }
        
        if (needsUpdate) {
          await entryDoc.reference.update(updates);
        }
      }
    }
  }
  
  static Future<void> _migrateTestImages(String projectId) async {
    final testsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('tests_status')
        .get();
    
    for (final testDoc in testsSnapshot.docs) {
      final data = testDoc.data();
      
      if (data['imageUrl'] != null) {
        final newUrl = await _migrateFirebaseImage(
          data['imageUrl'] as String,
          projectId,
          'tests',
        );
        
        if (newUrl != null) {
          await testDoc.reference.update({'imageUrl': newUrl});
        }
      }
    }
  }
  
  static Future<List<String>> _migrateImageList(
    List imageUrls,
    String projectId,
    String category,
  ) async {
    final List<String> newUrls = [];
    
    for (final url in imageUrls) {
      final newUrl = await _migrateFirebaseImage(
        url.toString(),
        projectId,
        category,
      );
      if (newUrl != null) {
        newUrls.add(newUrl);
      }
    }
    
    return newUrls;
  }
  
  static Future<String?> _migrateFirebaseImage(
    String firebaseUrl,
    String projectId,
    String category,
  ) async {
    try {
      // التحقق من أن الرابط من Firebase
      if (!firebaseUrl.contains('firebase') && !firebaseUrl.contains('googleapis')) {
        return firebaseUrl; // الرابط ليس من Firebase
      }
      
      // تحميل الصورة من Firebase
      final response = await http.get(Uri.parse(firebaseUrl));
      if (response.statusCode != 200) {
        print('فشل في تحميل الصورة من Firebase: $firebaseUrl');
        return null;
      }
      
      // إنشاء اسم ملف فريد
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_migrated.jpg';
      
      // رفع الصورة إلى الخادم الجديد
      final newUrl = await ImageUploadService.uploadImage(
        imageBytes: response.bodyBytes,
        fileName: fileName,
        projectId: projectId,
        category: category,
      );
      
      return newUrl;
      
    } catch (e) {
      print('خطأ في نقل الصورة $firebaseUrl: $e');
      return null;
    }
  }
}
