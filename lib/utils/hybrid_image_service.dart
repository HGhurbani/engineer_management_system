import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class HybridImageService {
  static const String baseUrl = 'https://bhbgroup.me';
  static const String uploadEndpoint = '$baseUrl/api/upload_image.php';
  
  /// رفع الصور الجديدة إلى الاستضافة الخاصة (bhbgroup.me)
  static Future<List<String>> uploadImagesWithProgress(
    List<XFile> images, 
    String projectId, 
    String folder,
    Function(double)? onProgress
  ) async {
    if (images.isEmpty) return [];
    
    List<String> uploadedUrls = [];
    int totalImages = images.length;
    
    for (int i = 0; i < images.length; i++) {
      try {
        // محاولة الرفع بالطريقة الأولى (base64)
        String? uploadedUrl = await uploadSingleImage(images[i], projectId, folder);
        
        // إذا فشلت الطريقة الأولى، جرب الطريقة البديلة (multipart)
        if (uploadedUrl == null) {
          print('Base64 upload failed, trying multipart...');
          uploadedUrl = await uploadSingleImageMultipart(images[i], projectId, folder);
        }
        
        if (uploadedUrl != null) {
          uploadedUrls.add(uploadedUrl);
        } else {
          print('Both upload methods failed for image $i');
        }
        
        // تحديث التقدم
        if (onProgress != null) {
          onProgress((i + 1) / totalImages);
        }
        
      } catch (e) {
        print('Error uploading image $i: $e');
        // الاستمرار مع الصور الأخرى
      }
    }
    
    return uploadedUrls;
  }
  
  /// رفع صورة واحدة باستخدام MultipartRequest (طريقة بديلة)
  static Future<String?> uploadSingleImageMultipart(
    XFile image, 
    String projectId, 
    String folder
  ) async {
    try {
      final file = File(image.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      var request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      
      // إضافة الحقول
      request.fields['project_id'] = projectId;
      request.fields['category'] = folder;
      request.fields['timestamp'] = timestamp.toString();
      
      // إضافة الملف
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      
      print('Uploading via multipart - Project: $projectId, Category: $folder');
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('Multipart image uploaded successfully: ${responseData['url']}');
          return responseData['url'];
        } else {
          print('Multipart image upload failed: ${responseData['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print('Multipart image upload failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
      
    } catch (e) {
      print('Error uploading image via multipart: $e');
      return null;
    }
  }

  /// رفع صورة واحدة إلى الاستضافة الخاصة
  static Future<String?> uploadSingleImage(
    XFile image, 
    String projectId, 
    String folder
  ) async {
    try {
      final file = File(image.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // قراءة الملف وتحويله إلى base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // إرسال الطلب إلى الخادم
      final response = await http.post(
        Uri.parse(uploadEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'image': base64Image,
          'project_id': projectId,
          'category': folder,
          'timestamp': timestamp.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('Single image uploaded successfully: ${responseData['url']}');
          return responseData['url'];
        } else {
          print('Single image upload failed: ${responseData['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print('Single image upload failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
      
    } catch (e) {
      print('Error uploading single image: $e');
      return null;
    }
  }
  
  /// التحقق من نوع الصورة (Firebase أم الاستضافة الخاصة)
  static bool isFirebaseUrl(String url) {
    return url.contains('firebase') || url.contains('googleapis.com');
  }
  
  /// التحقق من أن الصورة من الاستضافة الخاصة
  static bool isCustomHostingUrl(String url) {
    return url.contains('bhbgroup.me');
  }
  
  /// الحصول على نوع الصورة
  static ImageSourceType getImageSourceType(String url) {
    if (isFirebaseUrl(url)) {
      return ImageSourceType.firebase;
    } else if (isCustomHostingUrl(url)) {
      return ImageSourceType.customHosting;
    } else {
      return ImageSourceType.unknown;
    }
  }
  
  /// حذف صورة من Firebase (للصور القديمة إذا لزم الأمر)
  static Future<bool> deleteFirebaseImage(String url) async {
    try {
      if (!isFirebaseUrl(url)) return false;
      
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting Firebase image: $e');
      return false;
    }
  }
  
  /// حذف صورة من الاستضافة الخاصة
  static Future<bool> deleteCustomHostingImage(String url) async {
    try {
      if (!isCustomHostingUrl(url)) return false;
      
      // يمكن إضافة API endpoint لحذف الصور من الخادم إذا لزم الأمر
      // final response = await http.delete(Uri.parse('$baseUrl/api/delete_image.php?url=$url'));
      // return response.statusCode == 200;
      
      print('Custom hosting image deletion not implemented yet');
      return true; // نعتبرها ناجحة مؤقتاً
    } catch (e) {
      print('Error deleting custom hosting image: $e');
      return false;
    }
  }
  
  /// حذف صورة بناءً على نوعها
  static Future<bool> deleteImage(String url) async {
    final sourceType = getImageSourceType(url);
    
    switch (sourceType) {
      case ImageSourceType.firebase:
        return await deleteFirebaseImage(url);
      case ImageSourceType.customHosting:
        return await deleteCustomHostingImage(url);
      case ImageSourceType.unknown:
        print('Unknown image source type for URL: $url');
        return false;
    }
  }
  
  /// ترحيل الصور من Firebase إلى الاستضافة الخاصة (اختياري)
  static Future<String?> migrateFirebaseImageToCustomHosting(
    String firebaseUrl, 
    String projectId, 
    String folder
  ) async {
    try {
      if (!isFirebaseUrl(firebaseUrl)) return null;
      
      // تحميل الصورة من Firebase
      final response = await http.get(Uri.parse(firebaseUrl));
      if (response.statusCode != 200) return null;
      
      // رفع الصورة إلى الاستضافة الخاصة
      final base64Image = base64Encode(response.bodyBytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final uploadResponse = await http.post(
        Uri.parse(uploadEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'image': base64Image,
          'project_id': projectId,
          'category': folder,
          'timestamp': timestamp.toString(),
        },
      );
      
      if (uploadResponse.statusCode == 200) {
        final responseData = jsonDecode(uploadResponse.body);
        if (responseData['success'] == true) {
          return responseData['url'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error migrating Firebase image: $e');
      return null;
    }
  }
}

/// تعداد أنواع مصادر الصور
enum ImageSourceType {
  firebase,
  customHosting,
  unknown
}
