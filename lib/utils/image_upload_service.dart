
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;

class ImageUploadService {
  static const String baseUrl = 'https://bhbgroup.me';
  static const String uploadEndpoint = '$baseUrl/api/upload_image.php';
  
  /// رفع صورة واحدة إلى الخادم
  static Future<String?> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
    String? projectId,
    String? category, // 'materials', 'phases', 'tests'
  }) async {
    try {
      // ضغط الصورة لتحسين الأداء
      final compressedBytes = await _compressImage(imageBytes);
      
      final uri = Uri.parse(uploadEndpoint);
      var request = http.MultipartRequest('POST', uri);
      
      // إضافة الصورة
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        compressedBytes,
        filename: fileName,
      ));
      
      // إضافة بيانات إضافية
      if (projectId != null) request.fields['project_id'] = projectId;
      if (category != null) request.fields['category'] = category;
      request.fields['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
      
      final response = await request.send().timeout(const Duration(minutes: 2));
      
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        
        if (data['success'] == true) {
          return data['url'] as String?;
        } else {
          print('خطأ في رفع الصورة: ${data['message']}');
          return null;
        }
      } else {
        print('خطأ HTTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }
  
  /// رفع عدة صور بشكل متوازي
  static Future<List<String>> uploadMultipleImages({
    required List<Uint8List> imagesList,
    required List<String> fileNames,
    String? projectId,
    String? category,
    void Function(double progress)? onProgress,
  }) async {
    final List<String> uploadedUrls = [];
    
    if (imagesList.length != fileNames.length) {
      throw ArgumentError('عدد الصور يجب أن يساوي عدد أسماء الملفات');
    }
    
    // رفع الصور بشكل متوازي (6 صور في كل مرة)
    const int batchSize = 6;
    int completed = 0;
    
    for (int i = 0; i < imagesList.length; i += batchSize) {
      final batch = <Future<String?>>[];
      final endIndex = (i + batchSize < imagesList.length) ? i + batchSize : imagesList.length;
      
      for (int j = i; j < endIndex; j++) {
        batch.add(uploadImage(
          imageBytes: imagesList[j],
          fileName: fileNames[j],
          projectId: projectId,
          category: category,
        ));
      }
      
      final results = await Future.wait(batch);
      
      for (final result in results) {
        if (result != null) {
          uploadedUrls.add(result);
        }
        completed++;
        onProgress?.call(completed / imagesList.length);
      }
    }
    
    return uploadedUrls;
  }
  
  /// ضغط الصورة للحصول على أداء أفضل
  static Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      
      // تحديد الحد الأقصى للأبعاد
      const int maxDimension = 1920;
      
      img.Image resizedImage = image;
      
      if (image.width > maxDimension || image.height > maxDimension) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxDimension : null,
          height: image.height >= image.width ? maxDimension : null,
        );
      }
      
      // ضغط بجودة عالية
      return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));
    } catch (e) {
      print('خطأ في ضغط الصورة: $e');
      return bytes;
    }
  }
  
  /// حذف صورة من الخادم
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/api/delete_image.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('خطأ في حذف الصورة: $e');
      return false;
    }
  }
  
  /// تحسين رابط الصورة للعرض
  static String optimizeImageUrl(String originalUrl, {int? width, int? height, int? quality}) {
    final uri = Uri.parse(originalUrl);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    
    if (width != null) queryParams['w'] = width.toString();
    if (height != null) queryParams['h'] = height.toString();
    if (quality != null) queryParams['q'] = quality.toString();
    
    return uri.replace(queryParameters: queryParams.isEmpty ? null : queryParams).toString();
  }
}
