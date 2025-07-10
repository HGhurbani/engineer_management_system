import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:engineer_management_system/theme/app_constants.dart'; // تأكد من استيراد هذا

// قد تحتاج إلى تغيير اسم هذا الملف إلى شيء أكثر عمومية مثل `file_storage_service.dart`

class ReportStorage {
  // نقطة نهاية لرفع ملفات PDF (تحتاج لإنشائها على خادمك)
  static const String uploadReportUrl = '${AppConstants.baseUrl}/reports/upload_report.php';
  // نقطة نهاية لتنزيل ملفات PDF (تحتاج لإنشائها على خادمك)
  static const String downloadReportBaseUrl = '${AppConstants.baseUrl}/reports/'; // أو مسار API أكثر تحديداً

  // دالة لرفع تقرير PDF إلى خادمك الخاص
  static Future<String?> uploadReportPdf(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse(uploadReportUrl);
      var request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'report_file', // اسم الحقل الذي سيتوقعه الخادم لملف PDF
          bytes,
          filename: fileName,
          // contentType: MediaType('application', 'pdf'), // قد تحتاج لإضافة هذا إذا كان الخادم يتطلب نوع المحتوى
        ));

      var response = await request
          .send()
          .timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        // افترض أن الخادم يعيد مسار URL المباشر للملف المرفوع
        // قد تحتاج إلى تحليل JSON هنا إذا كان الخادم يعيد JSON
        return responseBody; // هذا هو رابط التنزيل الذي سيعيده الخادم
      } else {
        final errorBody = await response.stream.bytesToString();
        print('Error uploading PDF: ${response.statusCode}, $errorBody');
        return null;
      }
    } on TimeoutException catch (_) {
      print('PDF upload timed out');
      return null;
    } catch (e) {
      print('Exception during PDF upload: $e');
      return null;
    }
  }

  // دالة لإنشاء رابط تنزيل لتقرير PDF من خادمك الخاص
  // هذه الدالة ستعتمد على كيفية تنظيم ملفاتك على الخادم
  static String buildReportDownloadUrl(String fileName) {
    // افترض أن ملفات PDF يمكن الوصول إليها مباشرة عبر مسار URL
    // مثال: https://bhbgroup.me/reports/your_report_name.pdf
    return '$downloadReportBaseUrl$fileName';
  }

  // دالة لتنزيل تقرير PDF
  static Future<Uint8List?> downloadReportPdf(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Error downloading PDF: ${response.statusCode}');
        return null;
      }
    } on TimeoutException catch (_) {
      print('PDF download timed out');
      return null;
    } catch (e) {
      print('Exception during PDF download: $e');
      return null;
    }
  }
}

// Creates a random token for identifying generated reports
String generateReportToken({int length = 16}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random.secure();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

// Build a download URL that includes the token as a query parameter
String buildReportDownloadUrl(String fileName, String token) {
  final baseUrl = ReportStorage.buildReportDownloadUrl(fileName);
  return '$baseUrl?token=$token';
}

// Upload the PDF using [ReportStorage] ignoring the token on the client side
Future<String?> uploadReportPdf(
    Uint8List bytes, String fileName, String token) async {
  return await ReportStorage.uploadReportPdf(bytes, fileName);}