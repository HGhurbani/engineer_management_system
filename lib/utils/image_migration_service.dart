import 'package:cloud_firestore/cloud_firestore.dart';
import 'hybrid_image_service.dart';

class ImageMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// ترحيل جميع صور مشروع معين من Firebase إلى الاستضافة الخاصة
  static Future<Map<String, dynamic>> migrateProjectImages(String projectId) async {
    int totalImages = 0;
    int migratedImages = 0;
    int failedImages = 0;
    List<String> failedUrls = [];
    
    try {
      // جلب جميع إدخالات المشروع
      final projectEntriesSnapshot = await _firestore
          .collection('project_entries')
          .where('project_id', isEqualTo: projectId)
          .get();
      
      for (final doc in projectEntriesSnapshot.docs) {
        final data = doc.data();
        bool docUpdated = false;
        Map<String, dynamic> updatedData = {};
        
        // ترحيل الصور في كل فئة
        final categories = ['before_images', 'after_images', 'other_images'];
        
        for (final category in categories) {
          if (data.containsKey(category) && data[category] is List) {
            final imageUrls = List<String>.from(data[category] ?? []);
            final migratedUrls = <String>[];
            
            for (final url in imageUrls) {
              totalImages++;
              
              if (HybridImageService.isFirebaseUrl(url)) {
                // ترحيل الصورة
                final newUrl = await HybridImageService.migrateFirebaseImageToCustomHosting(
                  url,
                  projectId,
                  category.replaceAll('_images', ''),
                );
                
                if (newUrl != null) {
                  migratedUrls.add(newUrl);
                  migratedImages++;
                  print('Migrated image: $url -> $newUrl');
                } else {
                  migratedUrls.add(url); // الاحتفاظ بالرابط القديم
                  failedImages++;
                  failedUrls.add(url);
                  print('Failed to migrate image: $url');
                }
              } else {
                // الصورة بالفعل في الاستضافة الخاصة
                migratedUrls.add(url);
              }
            }
            
            if (migratedUrls.isNotEmpty) {
              updatedData[category] = migratedUrls;
              docUpdated = true;
            }
          }
        }
        
        // تحديث الوثيقة إذا تم ترحيل أي صور
        if (docUpdated) {
          await doc.reference.update(updatedData);
          print('Updated document ${doc.id} with migrated URLs');
        }
      }
      
      return {
        'success': true,
        'total_images': totalImages,
        'migrated_images': migratedImages,
        'failed_images': failedImages,
        'failed_urls': failedUrls,
        'message': 'تم ترحيل $migratedImages من أصل $totalImages صورة بنجاح',
      };
      
    } catch (e) {
      print('Error migrating project images: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'حدث خطأ أثناء ترحيل الصور: $e',
      };
    }
  }
  
  /// ترحيل جميع الصور في قاعدة البيانات
  static Future<Map<String, dynamic>> migrateAllImages() async {
    int totalProjects = 0;
    int successfulProjects = 0;
    int totalImages = 0;
    int totalMigratedImages = 0;
    List<String> failedProjects = [];
    
    try {
      // جلب جميع المشاريع
      final projectsSnapshot = await _firestore.collection('projects').get();
      totalProjects = projectsSnapshot.docs.length;
      
      for (final projectDoc in projectsSnapshot.docs) {
        final projectId = projectDoc.id;
        print('Migrating images for project: $projectId');
        
        final result = await migrateProjectImages(projectId);
        
        if (result['success'] == true) {
          successfulProjects++;
          totalImages += (result['total_images'] as int? ?? 0);
          totalMigratedImages += (result['migrated_images'] as int? ?? 0);
        } else {
          failedProjects.add(projectId);
          print('Failed to migrate project $projectId: ${result['error']}');
        }
        
        // تأخير قصير لتجنب إرهاق الخادم
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      return {
        'success': true,
        'total_projects': totalProjects,
        'successful_projects': successfulProjects,
        'failed_projects': failedProjects.length,
        'failed_project_ids': failedProjects,
        'total_images': totalImages,
        'migrated_images': totalMigratedImages,
        'message': 'تم ترحيل $totalMigratedImages صورة من $successfulProjects مشروع بنجاح',
      };
      
    } catch (e) {
      print('Error migrating all images: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'حدث خطأ أثناء ترحيل جميع الصور: $e',
      };
    }
  }
  
  /// فحص حالة الصور في مشروع معين
  static Future<Map<String, dynamic>> analyzeProjectImages(String projectId) async {
    int firebaseImages = 0;
    int customHostingImages = 0;
    int unknownImages = 0;
    List<String> firebaseUrls = [];
    List<String> customHostingUrls = [];
    List<String> unknownUrls = [];
    
    try {
      final projectEntriesSnapshot = await _firestore
          .collection('project_entries')
          .where('project_id', isEqualTo: projectId)
          .get();
      
      for (final doc in projectEntriesSnapshot.docs) {
        final data = doc.data();
        final categories = ['before_images', 'after_images', 'other_images'];
        
        for (final category in categories) {
          if (data.containsKey(category) && data[category] is List) {
            final imageUrls = List<String>.from(data[category] ?? []);
            
            for (final url in imageUrls) {
              final sourceType = HybridImageService.getImageSourceType(url);
              
              switch (sourceType) {
                case ImageSourceType.firebase:
                  firebaseImages++;
                  firebaseUrls.add(url);
                  break;
                case ImageSourceType.customHosting:
                  customHostingImages++;
                  customHostingUrls.add(url);
                  break;
                case ImageSourceType.unknown:
                  unknownImages++;
                  unknownUrls.add(url);
                  break;
              }
            }
          }
        }
      }
      
      return {
        'project_id': projectId,
        'firebase_images': firebaseImages,
        'custom_hosting_images': customHostingImages,
        'unknown_images': unknownImages,
        'firebase_urls': firebaseUrls,
        'custom_hosting_urls': customHostingUrls,
        'unknown_urls': unknownUrls,
        'total_images': firebaseImages + customHostingImages + unknownImages,
        'needs_migration': firebaseImages > 0,
      };
      
    } catch (e) {
      print('Error analyzing project images: $e');
      return {
        'error': e.toString(),
        'project_id': projectId,
      };
    }
  }
  
  /// فحص حالة جميع الصور في قاعدة البيانات
  static Future<Map<String, dynamic>> analyzeAllImages() async {
    int totalFirebaseImages = 0;
    int totalCustomHostingImages = 0;
    int totalUnknownImages = 0;
    int projectsNeedingMigration = 0;
    Map<String, Map<String, dynamic>> projectAnalysis = {};
    
    try {
      final projectsSnapshot = await _firestore.collection('projects').get();
      
      for (final projectDoc in projectsSnapshot.docs) {
        final projectId = projectDoc.id;
        final analysis = await analyzeProjectImages(projectId);
        
        if (!analysis.containsKey('error')) {
          projectAnalysis[projectId] = analysis;
          totalFirebaseImages += (analysis['firebase_images'] as int? ?? 0);
          totalCustomHostingImages += (analysis['custom_hosting_images'] as int? ?? 0);
          totalUnknownImages += (analysis['unknown_images'] as int? ?? 0);
          
          if (analysis['needs_migration'] == true) {
            projectsNeedingMigration++;
          }
        }
      }
      
      return {
        'total_firebase_images': totalFirebaseImages,
        'total_custom_hosting_images': totalCustomHostingImages,
        'total_unknown_images': totalUnknownImages,
        'total_images': totalFirebaseImages + totalCustomHostingImages + totalUnknownImages,
        'projects_needing_migration': projectsNeedingMigration,
        'total_projects': projectsSnapshot.docs.length,
        'project_analysis': projectAnalysis,
        'migration_needed': totalFirebaseImages > 0,
      };
      
    } catch (e) {
      print('Error analyzing all images: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}
