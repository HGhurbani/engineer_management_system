import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../firebase_options.dart';
import 'pdf_styles.dart';
import 'pdf_image_cache.dart';
import 'report_storage.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'report_snapshot_manager.dart';
import 'memory_optimizer.dart';
import 'advanced_image_cache_manager.dart';

  class PdfReportResult {
    final Uint8List bytes;
    final String? downloadUrl;
    PdfReportResult({required this.bytes, this.downloadUrl});
  }


  class PdfReportGenerator {

    static pw.Font? _arabicFont;
    // Limit the dimensions of embedded images so large photos do not cause
    // out-of-memory errors when generating huge reports. Lowering the limit
    // further reduces peak memory usage when many images are embedded.
    // Lowering the dimension reduces the memory consumed when many
    // pictures are included in a single report. Using 1024 keeps better
    // clarity for large photos while still bounding memory usage.
      static const int _maxImageDimension = 1024;
  static const int _jpgQuality = 85;
  // More aggressive settings for devices with limited memory.
  static const int _lowMemImageDimension = 256;
  static const int _veryLowMemImageDimension = 128;
  // Extremely small dimension used when the report contains hundreds of photos
  // to guarantee that memory usage stays low even on devices with very limited
  // resources.
  static const int _extremeLowMemImageDimension = 64;
  static const int _lowMemJpgQuality = 60;
  
  // Web-specific settings for better memory management
  static const int _webMaxImageDimension = 800;
  static const int _webLowMemImageDimension = 200;
  static const int _webVeryLowMemImageDimension = 100;
  static const int _webExtremeLowMemImageDimension = 50;
  static const int _webJpgQuality = 70;
  static const int _webLowMemJpgQuality = 50;
  
  // إضافة إدارة ذكية للذاكرة
  static const int _memoryThreshold = 100 * 1024 * 1024; // 100MB
  static const int _lowMemoryThreshold = 50 * 1024 * 1024; // 50MB
  
  // Automatically enable low-memory mode when the report contains
  // a large number of photos. This prevents out-of-memory failures on
  // devices with limited resources by downscaling images and reducing
  // concurrency from the start instead of retrying after a crash.
  // Trigger low-memory mode earlier so images are aggressively downscaled before
  // memory pressure leads to a crash.
  static const int _autoLowMemoryThreshold = 80; // photos
  // When the number of images becomes extremely large we show small
  // thumbnails in the PDF to keep memory usage low while still allowing
  // the user to preview the full quality image via a link.
  static const int _thumbnailCountThreshold = 200; // photos
  // When images become extremely numerous we switch to tiny thumbnails to keep
  // the PDF generation stable.
  static const int _extremeThumbnailCountThreshold = 400; // photos
  static const int _thumbnailDimension = 150;
  static const int _extremeThumbnailDimension = 100;
  // Skip downloading images that exceed this size in bytes to avoid
  // exhausting memory on devices with limited resources.
  // Made public so other libraries can reference this limit.
  static const int maxImageFileSize = 5 * 1024 * 1024; // 5 MB

  /// Determines the target image dimension based on the number of images in
  /// the report. More photos means we aggressively downscale to keep memory
  /// and file size low.
  static int _adaptiveDimension(int count) {
    if (count >= 200) return 256;
    if (count >= 100) return 384;
    if (count >= 50) return 512;
    return _maxImageDimension;
  }

  /// More aggressive scaling when memory is very limited.
  static int _adaptiveLowMemoryDimension(int count) {
    if (count >= _extremeThumbnailCountThreshold) return _extremeLowMemImageDimension;
    if (count >= 200) return _veryLowMemImageDimension;
    if (count >= 100) return 192;
    if (count >= 50) return _lowMemImageDimension;
    return _lowMemImageDimension;
  }

  /// Web-specific adaptive dimensions for better memory management
  static int _adaptiveWebDimension(int count) {
    if (count >= _extremeThumbnailCountThreshold) return _webExtremeLowMemImageDimension;
    if (count >= _thumbnailCountThreshold) return _webVeryLowMemImageDimension;
    if (count >= 100) return _webLowMemImageDimension;
    if (count >= 50) return _webMaxImageDimension;
    return _webMaxImageDimension;
  }

  /// Web-specific low memory dimensions
  static int _adaptiveWebLowMemoryDimension(int count) {
    if (count >= _extremeThumbnailCountThreshold) return _webExtremeLowMemImageDimension;
    if (count >= 200) return _webVeryLowMemImageDimension;
    if (count >= 100) return _webLowMemImageDimension;
    if (count >= 50) return _webLowMemImageDimension;
    return _webLowMemImageDimension;
  }

    /// استخدام أبعاد عالية الجودة بشكل دائم
  static int _adaptiveHighQualityDimension(int count) {
    if (count >= _extremeThumbnailCountThreshold) return _veryLowMemImageDimension;
    if (count >= 200) return 256;
    if (count >= 100) return 384;
    if (count >= 50) return 512;
    return _maxImageDimension;
  }


  static Future<void> _loadArabicFont({Uint8List? fontBytes}) async {
    if (_arabicFont != null) return;
    try {
      final ByteData data = fontBytes != null
          ? ByteData.view(fontBytes.buffer)
          : await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
      _arabicFont = pw.Font.ttf(data);
    } catch (e) {
      print('Error loading Arabic font: $e');
    }
  }

    static Future<Uint8List> _resizeImageEfficiently(Uint8List bytes,
        {int? maxDimension, int? quality}) async {
      // استخدام الأبعاد والجودة الافتراضية إذا لم يتم توفيرها
      final dim = maxDimension ?? (kIsWeb ? _webMaxImageDimension : _maxImageDimension);
      final q = quality ?? (kIsWeb ? _webJpgQuality : _jpgQuality);

      // التحقق من صلاحية الصورة قبل المعالجة لتجنب الأخطاء
      final image = img.decodeImage(bytes);
      if (image == null) return bytes; // إذا كانت البيانات غير صالحة، أعدها كما هي

      // إذا كانت الصورة أصلاً صغيرة، فقط قم بضغطها بالجودة المطلوبة
      if (image.width <= dim && image.height <= dim) {
        return FlutterImageCompress.compressWithList(
          bytes,
          quality: q,
        );
      }

      // تغيير الحجم مع الحفاظ على نسبة الأبعاد
      // المكتبة تتعامل مع minWidth و minHeight بذكاء لتغيير الحجم
      return FlutterImageCompress.compressWithList(
        bytes,
        minHeight: dim,
        minWidth: dim,
        quality: q,
      );
    }

    @visibleForTesting
    static Future<Uint8List> resizeImageForTest(Uint8List bytes,
        {int? maxDimension, int? quality}) =>
        _resizeImageEfficiently(bytes,
            maxDimension: maxDimension, quality: quality);




    // (هذه الدالة المعدلة تستبدل الدالة القديمة _fetchImagesForUrls بالكامل)
// إنها تستخدم البث المباشر للملفات لتوفير الذاكرة بشكل جذري

    static Future<Map<String, String>> _fetchImagesForUrls(
        List<String> urls, {
          void Function(double progress)? onProgress,
          // 💡 خفض التزامن إلى 1 هو الخيار الأكثر أمانًا للأجهزة الضعيفة
          int concurrency = 1,
          int? maxDimension,
          int? quality,
          Directory? tempDir,
        }) async {
      tempDir ??= await Directory.systemTemp.createTemp('pdf_imgs_stream');
      final Map<String, String> fetched = {};
      final uniqueUrls = urls.toSet().toList();
      int completed = 0;
      final client = http.Client();

      // Web-specific optimizations
      final isWeb = kIsWeb;
      final webConcurrency = isWeb ? 1 : concurrency; // Force sequential processing on web
      final webDelay = isWeb ? 100 : 50; // Longer delays between batches on web

      Future<void> handleUrl(String url) async {
        if (fetched.containsKey(url) || url.isEmpty) return;

        // اسم ملف فريد لتجنب أي تضارب
        final filePath = '${tempDir!.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
        final file = File(filePath);

        try {
          // 1. بث استجابة الشبكة مباشرة إلى ملف دون تحميلها في الذاكرة
          final request = http.Request('GET', Uri.parse(url));
          final response = await client.send(request);

          if (response.statusCode == 200) {
            // فتح "مجرى كتابة" إلى الملف
            final sink = file.openWrite();
            // كتابة كل جزء من البيانات يأتي من الشبكة إلى الملف مباشرة
            await response.stream.pipe(sink);
            // إغلاق المجرى يضمن حفظ كل البيانات
            await sink.close();

            // 2. الآن بعد أن أصبحت الصورة على القرص، نقوم بضغطها وتغيير حجمها منه
            // هذا يستهلك ذاكرة قليلة جدًا مقارنة بالمعالجة من Uint8List
            final actualMaxDimension = maxDimension ?? (isWeb ? _webMaxImageDimension : _maxImageDimension);
            final actualQuality = quality ?? (isWeb ? _webJpgQuality : _jpgQuality);
            
            final resizedBytes = await FlutterImageCompress.compressWithFile(
              file.path,
              minHeight: actualMaxDimension,
              minWidth: actualMaxDimension,
              quality: actualQuality,
            );

            // إذا نجحت عملية الضغط، قم بالكتابة فوق الملف الأصلي بالنسخة المضغوطة
            if (resizedBytes != null) {
              await file.writeAsBytes(resizedBytes, flush: true);
              fetched[url] = file.path;
            } else {
              // إذا فشل الضغط لسبب ما، استخدم الملف الأصلي (نادر الحدوث)
              fetched[url] = file.path;
            }

          } else {
            print('Error fetching image (status code ${response.statusCode}) from URL $url');
          }
        } catch (e) {
          print('Error streaming or processing image from URL $url: $e');
          // تأكد من حذف الملف إذا فشلت العملية
          if (await file.exists()) {
            await file.delete();
          }
        }

        // تحديث شريط التقدم
        completed++;
        onProgress?.call(completed / uniqueUrls.length);
      }

      // معالجة الصور بشكل متسلسل أو بدفعات صغيرة
      for (int i = 0; i < uniqueUrls.length; i += webConcurrency) {
        final batch = uniqueUrls.skip(i).take(webConcurrency).toList();
        await Future.wait(batch.map(handleUrl));
        // إعطاء فرصة لجامع القمامة للعمل بين الدفعات
        await Future.delayed(Duration(milliseconds: webDelay));
      }

      client.close();
      return fetched;
    }

  static Future<PdfReportResult> generate({

      required String projectId,

      required Map<String, dynamic>? projectData,

      required List<Map<String, dynamic>> phases,

      required List<Map<String, dynamic>> testsStructure,

      String? generatedBy,
      String? generatedByRole,

      DateTime? start,

      DateTime? end,
      void Function(double progress)? onProgress,
      void Function(String status)? onStatusUpdate,
      bool lowMemory = false,
      Uint8List? arabicFontBytes,

    }) async {

      // بدء مراقبة الذاكرة
      MemoryOptimizer.startMemoryMonitoring();
      
      try {

      int imgQuality = lowMemory ? _lowMemJpgQuality : _jpgQuality;
      int fetchConcurrency = lowMemory ? 1 : 3;

      DateTime now = DateTime.now();

      final bool isFullReport = start == null && end == null;

      bool useRange = !isFullReport;

      if (useRange) {

        start ??= DateTime(now.year, now.month, now.day);

        end ??= start.add(const Duration(days: 1));

      }


      final List<Map<String, dynamic>> dayEntries = [];

      final List<Map<String, dynamic>> dayTests = [];

      final List<Map<String, dynamic>> dayRequests = [];

      final Set<String> imageUrls = {};


      try {

        int totalDataTasks = 2; // tests and requests
        for (var p in phases) {
          totalDataTasks++; // phase
          totalDataTasks += (p['subPhases'] as List).length;
        }
        int completedTasks = 0;
        void update() {
          completedTasks++;
          onProgress?.call((completedTasks / totalDataTasks) * 0.6);
        }

        for (var phase in phases) {
          final phaseId = phase['id'];
          final phaseName = phase['name'];
          Query<Map<String, dynamic>> q = FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('phases_status')
              .doc(phaseId)
              .collection('entries');
          if (useRange) {
            q = q
                .where('timestamp', isGreaterThanOrEqualTo: start)
                .where('timestamp', isLessThan: end);
          }
          final snap = await q.orderBy('timestamp').get();
          for (var doc in snap.docs) {
            final data = doc.data();
            // دعم الهياكل القديمة والجديدة للصور
            final imgs = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                        (data['otherImages'] as List?)?.map((e) => e.toString()).toList() ?? 
                        (data['otherImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final beforeImgs = (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                              (data['beforeImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final afterImgs = (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                             (data['afterImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
            imageUrls.addAll(imgs);
            imageUrls.addAll(beforeImgs);
            imageUrls.addAll(afterImgs);
            dayEntries.add({
              ...data,
              'phaseName': phaseName,
              'subPhaseName': null,
            });
          }
          update();

          for (var sub in phase['subPhases']) {
            final subId = sub['id'];
            final subName = sub['name'];
            Query<Map<String, dynamic>> qSub = FirebaseFirestore.instance
                .collection('projects')
                .doc(projectId)
                .collection('subphases_status')
                .doc(subId)
                .collection('entries');
            if (useRange) {
              qSub = qSub
                  .where('timestamp', isGreaterThanOrEqualTo: start)
                  .where('timestamp', isLessThan: end);
            }
            final subSnap = await qSub.orderBy('timestamp').get();
            for (var doc in subSnap.docs) {
              final data = doc.data();
              // دعم الهياكل القديمة والجديدة للصور
              final imgs = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                          (data['otherImages'] as List?)?.map((e) => e.toString()).toList() ?? 
                          (data['otherImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final beforeImgs = (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                                (data['beforeImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final afterImgs = (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                               (data['afterImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
              imageUrls.addAll(imgs);
              imageUrls.addAll(beforeImgs);
              imageUrls.addAll(afterImgs);
              dayEntries.add({
                ...data,
                'phaseName': phaseName,
                'subPhaseName': subName,
              });
            }
            update();
          }
        }

        final Map<String, Map<String, String>> testInfo = {};
        for (var section in testsStructure) {
          final sectionName = section['section_name'] as String;
          for (var t in section['tests'] as List) {
            testInfo[(t as Map)['id']] = {
              'name': t['name'] as String,
              'section': sectionName,
            };
          }
        }

        Query<Map<String, dynamic>> qTests = FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('tests_status');
        if (useRange) {
          qTests = qTests
              .where('lastUpdatedAt', isGreaterThanOrEqualTo: start)
              .where('lastUpdatedAt', isLessThan: end);
        }
        final testsSnap = await qTests.get();
        for (var doc in testsSnap.docs) {
          final data = doc.data();
          final info = testInfo[doc.id];
          final imgUrl = data['imageUrl'] as String?;
          if (imgUrl != null) imageUrls.add(imgUrl);
          dayTests.add({
            ...data,
            'testId': doc.id,
            'testName': info?['name'] ?? doc.id,
            'sectionName': info?['section'] ?? '',
          });
        }
        update();

        Query<Map<String, dynamic>> qReq = FirebaseFirestore.instance
            .collection('partRequests')
            .where('projectId', isEqualTo: projectId);
        if (useRange) {
          qReq = qReq
              .where('requestedAt', isGreaterThanOrEqualTo: start)
              .where('requestedAt', isLessThan: end);
        }
        final reqSnap = await qReq.get();
        for (var doc in reqSnap.docs) {
          dayRequests.add(doc.data());
        }
        update();

      } catch (e) {

        print('Error preparing daily report details: $e');

      }


      // Web-specific memory management
      final isWeb = kIsWeb;
      if (isWeb) {
        // More aggressive low-memory mode for web
        if (imageUrls.length > 30) {
          lowMemory = true;
          imgQuality = _webLowMemJpgQuality;
          fetchConcurrency = 1;
        }
      } else {
        // Enable low-memory mode automatically when the number of
        // collected images exceeds the configured threshold.
        if (!lowMemory && imageUrls.length > _autoLowMemoryThreshold) {
          lowMemory = true;
          imgQuality = _lowMemJpgQuality;
          fetchConcurrency = 1;
        }
      }

      // في حال كان عدد الصور كبيراً جداً، يتم توليد التقرير على الخادم
      if (imageUrls.length > 100) {
        try {
          onStatusUpdate?.call('جاري إنشاء التقرير على الخادم...');
          final callable = FirebaseFunctions.instance.httpsCallable('generatePdfReport');
          final result = await callable.call({
            'images': imageUrls.toList(),
          });
          final url = (result.data is Map && result.data['url'] != null)
              ? result.data['url']
              : result.data.toString();
          return PdfReportResult(bytes: Uint8List(0), downloadUrl: url);
        } catch (e) {
          print('Remote PDF generation failed: $e');
        }
      }

      final bool thumbnailMode =
          imageUrls.length >= _thumbnailCountThreshold;
      final bool extremeThumbnailMode =
          imageUrls.length >= _extremeThumbnailCountThreshold;

      await _loadArabicFont(fontBytes: arabicFontBytes);

      if (_arabicFont == null) {

        throw Exception('Arabic font not available');

      }

      // Determine image size based on photo count, memory mode and whether
      // thumbnails should be used.
      final int imgDim = extremeThumbnailMode
          ? (isWeb ? _webExtremeLowMemImageDimension : _extremeLowMemImageDimension)
          : thumbnailMode
              ? _thumbnailDimension
              : lowMemory
                  ? (isWeb ? _adaptiveWebLowMemoryDimension(imageUrls.length) : _adaptiveLowMemoryDimension(imageUrls.length))
                  : (isWeb ? _adaptiveWebDimension(imageUrls.length) : _adaptiveHighQualityDimension(imageUrls.length));
      final double gridSize = extremeThumbnailMode
          ? _extremeThumbnailDimension.toDouble()
          : thumbnailMode
              ? _thumbnailDimension.toDouble()
              : 80.0;
      final double singleSize = extremeThumbnailMode
          ? _extremeThumbnailDimension.toDouble()
          : thumbnailMode
              ? _thumbnailDimension.toDouble()
              : 120.0;

      // استخدام المعالج المحسن للصور مع الكاش
      onStatusUpdate?.call('جاري معالجة الصور...');
      final tempDir = await Directory.systemTemp.createTemp('report_imgs');
      
      // تحديد إعدادات الذاكرة
      final memoryRecommendations = MemoryOptimizer.getMemoryRecommendations(imageUrls.length);
      
      // استخدام الكاش المتقدم للصور
      final fetchedImages = await EnhancedImageProcessor.processImagesBatch(
        imageUrls: imageUrls.toList(),
        tempDir: tempDir,
        onProgress: (p) => onProgress?.call(0.6 + p * 0.3),
        onStatusUpdate: onStatusUpdate,
      );
      
      onProgress?.call(0.9);

      pw.Font? emojiFont;

      try {

        emojiFont = await pw.Font.ttf(await rootBundle.load('assets/fonts/NotoColorEmoji.ttf'));

      } catch (e) {

        try {

          emojiFont = await PdfGoogleFonts.notoColorEmoji();

        } catch (e) {

          print('Error loading emoji font: $e');

        }

      }


      final List<pw.Font> commonFontFallback = [];

      if (emojiFont != null) commonFontFallback.add(emojiFont);


      // Enable aggressive compression to keep the final document size small.
      final pdf = pw.Document(
        compress: true,
        version: PdfVersion.pdf_1_5,
      );

      final fileName =

          'daily_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';

      final token = generateReportToken();

      final qrLink = buildReportDownloadUrl(fileName, token);


      final projectDataMap = projectData;

      final String projectName = projectDataMap?['name'] ?? 'مشروع غير مسمى';

      final String clientName = projectDataMap?['clientName'] ?? 'غير معروف';
      final String projectType = projectDataMap?['projectType'] ?? 'غير محدد';
      final List<dynamic> assignedEngineersRaw =
          projectDataMap?['assignedEngineers'] as List<dynamic>? ?? [];
      String engineerNames = 'لا يوجد';
      if (assignedEngineersRaw.isNotEmpty) {
        engineerNames = assignedEngineersRaw
            .map((e) => e['name'] ?? 'مهندس')
            .join('، ');
      }
      String clientPhone = '';
      final String? clientUid = projectDataMap?['clientId'] as String?;
      if (clientUid != null && clientUid.isNotEmpty) {
        try {
          final clientDoc =
              await FirebaseFirestore.instance.collection('users').doc(clientUid).get();
          if (clientDoc.exists) {
            clientPhone = (clientDoc.data() as Map<String, dynamic>?)?['phone'] ?? '';
          }
        } catch (e) {
          // ignore
        }
      }

      String employeeNames = 'لا يوجد';
      try {
        final empSnap = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('employeeAssignments')
            .get();
        final names = empSnap.docs
            .map((d) => (d.data()['employeeName'] ?? '') as String)
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        if (names.isNotEmpty) {
          employeeNames = names.join('، ');
        }
      } catch (e) {
        // ignore
      }


      final ByteData logoByteData = await rootBundle.load('assets/images/app_logo.png');

      final Uint8List logoBytes = logoByteData.buffer.asUint8List();

      final pw.MemoryImage appLogo = pw.MemoryImage(logoBytes);


      final pw.TextStyle headerStyle = pw.TextStyle(

          font: _arabicFont,

          fontWeight: pw.FontWeight.bold,

          fontSize: 18,

          fontFallback: commonFontFallback);

      final pw.TextStyle regularStyle = pw.TextStyle(

          font: _arabicFont, fontSize: 16, fontFallback: commonFontFallback);

      final pw.TextStyle smallGrey = pw.TextStyle(

          font: _arabicFont,

          fontSize: 12,

          color: PdfColors.grey600,

          fontFallback: commonFontFallback);


      final String headerText = isFullReport

          ? 'التقرير الشامل'

          : useRange

          ? 'التقرير التراكمي'

          : 'التقرير اليومي';


      pdf.addPage(

        pw.MultiPage(
          maxPages: 10000,
          pageTheme: pw.PageTheme(

            pageFormat: PdfPageFormat.a4,

            textDirection: pw.TextDirection.rtl,

            theme: pw.ThemeData.withFont(
              base: _arabicFont,
              bold: _arabicFont,
              italic: _arabicFont,
              boldItalic: _arabicFont,
              fontFallback: commonFontFallback,
            ),

            margin: PdfStyles.pageMargins,

          ),

          header: (context) => PdfStyles.buildHeader(

            font: _arabicFont!,

            logo: appLogo,

            headerText: headerText,

            now: now,

            projectName: projectName,

            clientName: clientName,

          ),

          build: (context) {
            // القائمة النهائية التي تحتوي على كل عناصر التقرير
            return [
              // --- (الجزء الأول) تفاصيل المشروع ---
              _buildProjectDetailsTable(
                {
                  'أسماء الموظفين': employeeNames,
                  'اسم المشروع': projectName,
                  'المهندسون المسؤولون': engineerNames,
                  'هاتف العميل': clientPhone.isNotEmpty ? clientPhone : 'غير معروف',
                },
                headerStyle,
                regularStyle,
                PdfColors.blueGrey800,
                PdfColors.grey400,
              ),
              pw.SizedBox(height: 30),

              // --- (الجزء الثاني) قسم الملاحظات والتحديثات ---
              // يتم بناؤه باستخدام ListView.builder للحفاظ على الذاكرة
              _buildSectionHeader('الملاحظات والتحديثات', headerStyle, PdfColors.blueGrey800),
              pw.SizedBox(height: 15),
              dayEntries.isEmpty
                  ? _buildEmptyState('لا توجد ملاحظات مسجلة في هذه الفترة', regularStyle, PdfColors.grey100)
                  : pw.ListView.builder(
                itemCount: dayEntries.length,
                itemBuilder: (context, index) {
                  final entry = dayEntries[index];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 15),
                    child: _buildEntryCard(
                        entry,
                        index + 1,
                        headerStyle,
                        regularStyle,
                        regularStyle,
                        smallGrey,
                        PdfColors.grey400,
                        PdfColors.grey100,
                        images: fetchedImages,
                        imageSize: gridSize),
                  );
                },
              ),

              // --- (الجزء الثالث) قسم الاختبارات والفحوصات ---
              // يتم بناؤه أيضًا باستخدام ListView.builder
              pw.SizedBox(height: 20),
              _buildSectionHeader('الاختبارات والفحوصات', headerStyle, PdfColors.blueGrey800),
              pw.SizedBox(height: 15),
              dayTests.isEmpty
                  ? _buildEmptyState('لا توجد اختبارات محدثة في هذه الفترة', regularStyle, PdfColors.grey100)
                  : pw.ListView.builder(
                itemCount: dayTests.length,
                itemBuilder: (context, index) {
                  final test = dayTests[index];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 15),
                    child: _buildTestCard(
                        test,
                        index + 1,
                        headerStyle,
                        regularStyle,
                        regularStyle,
                        smallGrey,
                        PdfColors.grey400,
                        PdfColors.grey100,
                        images: fetchedImages,
                        imageSize: singleSize),
                  );
                },
              ),

              // --- (الجزء الرابع) باقي الأقسام ---
              pw.SizedBox(height: 20),
              _buildSectionHeader('طلبات المواد والمعدات', headerStyle, PdfColors.blueGrey800),
              pw.SizedBox(height: 15),
              dayRequests.isEmpty
                  ? _buildEmptyState('لا توجد طلبات مواد في هذه الفترة', regularStyle, PdfColors.grey100)
                  : _buildRequestsTable(dayRequests, regularStyle, regularStyle,
                  PdfColors.grey400, PdfColors.grey100),
              pw.SizedBox(height: 20),
              _buildImportantNotice(regularStyle),
            ];
          },

          footer: (context) => PdfStyles.buildFooter(

              context,

              font: _arabicFont!,

              fontFallback: commonFontFallback,

              qrData: qrLink,
              generatedByText:
              '${generatedByRole ?? 'المهندس'}: ${generatedBy ?? 'غير محدد'}'),

        ),

      );
      PdfImageCache.clearPrecache();
      // تنظيف الملفات المؤقتة
      await EnhancedImageProcessor.cleanupTempFiles(tempDir);

      final pdfBytes = await pdf.save();
      onProgress?.call(1.0);
      final url = await uploadReportPdf(pdfBytes, fileName, token);



      print('تم إنشاء التقرير بنجاح: ${pdfBytes.length} bytes');
      return PdfReportResult(bytes: pdfBytes, downloadUrl: url);
      } finally {
        // إيقاف مراقبة الذاكرة
        MemoryOptimizer.stopMemoryMonitoring();
        // تنظيف الذاكرة
        MemoryOptimizer.cleanupMemory();
        PdfImageCache.clear();
        PdfImageCache.clearPrecache();
      }

    }

  static Future<PdfReportResult> generateWithIsolate({
      required String projectId,
      required Map<String, dynamic>? projectData,
      required List<Map<String, dynamic>> phases,
      required List<Map<String, dynamic>> testsStructure,
      String? generatedBy,
      String? generatedByRole,
      DateTime? start,
      DateTime? end,
      void Function(double progress)? onProgress,
      bool lowMemory = false,

    }) async {
      // Previous versions attempted to offload PDF creation to a background
      // isolate when `lowMemory` was true. However, the PDF generation logic
      // relies on Flutter plugins such as Firebase which can only be accessed
      // from the root isolate. Spawning an isolate would therefore trigger
      // "UI actions are only available on root isolate" errors when the report
      // contained a large number of images and lowMemory mode activated.

      // Instead we run everything on the main isolate while still enabling the
      // low-memory image handling paths. This keeps plugin calls on the correct
      // isolate and avoids crashes when many photos are included.
      return PdfReportGenerator.generate(
        projectId: projectId,
        projectData: projectData,
        phases: phases,
        testsStructure: testsStructure,
        generatedBy: generatedBy,
        generatedByRole: generatedByRole,
        start: start,
        end: end,
        onProgress: onProgress,
        lowMemory: lowMemory,

      );
    }

  static Future<PdfReportResult> _generateIsolate(
        Map<String, dynamic> args) async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      return PdfReportGenerator.generate(
        projectId: args['projectId'] as String,
        projectData:
            args['projectData'] as Map<String, dynamic>?,
        phases: List<Map<String, dynamic>>.from(args['phases'] as List),
        testsStructure:
            List<Map<String, dynamic>>.from(args['testsStructure'] as List),
        generatedBy: args['generatedBy'] as String?,
        generatedByRole: args['generatedByRole'] as String?,
        start: args['start'] as DateTime?,
        end: args['end'] as DateTime?,
        lowMemory: true,
        arabicFontBytes: args['fontData'] as Uint8List?,

      );
    }

    static pw.Widget _buildProjectDetailsTable(
        Map<String, String> details,
        pw.TextStyle headerStyle,
        pw.TextStyle valueStyle,
        PdfColor headerColor,
        PdfColor borderColor) {
      if (details.isEmpty) {
        return pw.SizedBox.shrink();
      }

      final headers = details.keys.toList();
      final values = details.values.toList();
      return pw.Table(
        border: pw.TableBorder.all(color: borderColor),
        columnWidths: {
          for (int i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth()
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerColor),
            children: [
              for (final h in headers)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    h,
                    style: headerStyle.copyWith(color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
            ],
          ),
          pw.TableRow(
            children: [
              for (final v in values)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    v,
                    style: valueStyle,
                    textAlign: pw.TextAlign.center,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
            ],
          ),
        ],
      );
    }




    static pw.Widget _buildSummaryItem(

        String label, String value, pw.TextStyle regularStyle, PdfColor primaryColor) {

      return pw.Column(

        children: [

          pw.Container(

            width: 40,

            height: 40,

            decoration: pw.BoxDecoration(

              color: primaryColor,

              borderRadius: pw.BorderRadius.circular(20),

            ),

            child: pw.Center(

              child: pw.Text(

                value,

                style: pw.TextStyle(

                  font: _arabicFont,

                  color: PdfColors.white,

                  fontWeight: pw.FontWeight.bold,

                  fontSize: 18,

                ),

              ),

            ),

          ),

          pw.SizedBox(height: 8),

          pw.Text(label, style: regularStyle),

        ],

      );

    }


    static pw.Widget _buildSectionHeader(

        String title, pw.TextStyle headerStyle, PdfColor primaryColor) {

      return pw.Container(

        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),

        decoration: pw.BoxDecoration(

          color: primaryColor,

          borderRadius: pw.BorderRadius.circular(5),

        ),

        child: pw.Text(

          title,

          style: pw.TextStyle(

            font: _arabicFont,

            color: PdfColors.white,

            fontWeight: pw.FontWeight.bold,

            fontSize: 18,

          ),

        ),

      );

    }


    static pw.Widget _buildEmptyState(

        String message, pw.TextStyle regularStyle, PdfColor lightGrey) {

      return pw.Container(

        padding: const pw.EdgeInsets.all(20),

        decoration: pw.BoxDecoration(

          color: lightGrey,

          borderRadius: pw.BorderRadius.circular(8),

        ),

        child: pw.Center(

          child: pw.Text(message, style: regularStyle),

        ),

      );

    }


    static pw.Widget _buildEntryCard(
        Map<String, dynamic> entry,
        int index,
        pw.TextStyle subHeaderStyle,
        pw.TextStyle regularStyle,
        pw.TextStyle labelStyle,
        pw.TextStyle metaStyle,
        PdfColor borderColor,
        PdfColor lightGrey,
        {Map<String, String>? images,
        double imageSize = 80}) {
      final note = entry['note'] ?? '';
      final engineer = entry['employeeName'] ?? entry['engineerName'] ?? 'مهندس';
      final ts = (entry['timestamp'] as Timestamp?)?.toDate();
      final dateStr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'ar').format(ts) : '';
      final phaseName = entry['phaseName'] ?? '';
      final subName = entry['subPhaseName'];
      final imageUrls = (entry['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final beforeUrls = (entry['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final afterUrls = (entry['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: borderColor, width: 1.5),
          borderRadius: pw.BorderRadius.circular(12),
          boxShadow: [
            pw.BoxShadow(
              color: PdfColors.grey300,
              blurRadius: 4,
            ),
          ],
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Header Section
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 15),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: borderColor,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      'رقم الإدخال #$index',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      subName != null ? '$phaseName > $subName' : phaseName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                      textAlign: pw.TextAlign.right,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15),

            // Information Section
            pw.Container(
              width: double.infinity,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          engineer,
                          style: regularStyle,
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          'المهندس المسؤول:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          dateStr,
                          style: regularStyle,
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(color: lightGrey),
                        child: pw.Text(
                          'تاريخ التسجيل:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  if (note.toString().isNotEmpty)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightGrey),
                      children: [
                        pw.Container(                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            note.toString(),
                            style: regularStyle,
                            textAlign: pw.TextAlign.right,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'الملاحظات:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.right,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Images Section
            if (imageUrls.isNotEmpty || beforeUrls.isNotEmpty || afterUrls.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Text(
                  'الصور المرفقة:',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
              pw.SizedBox(height: 10),

              if (beforeUrls.isNotEmpty) ...[
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'صور قبل:',
                    style: labelStyle,
                    textAlign: pw.TextAlign.right,
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
                pw.SizedBox(height: 5),
                _buildImagesGrid(beforeUrls, borderColor,
                    images: images, size: imageSize),
                pw.SizedBox(height: 10),
              ],
              if (afterUrls.isNotEmpty) ...[
                pw.Text('صور بعد:',  style: labelStyle,
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,),
                pw.SizedBox(height: 5),
                _buildImagesGrid(afterUrls, borderColor,
                    images: images, size: imageSize),
                pw.SizedBox(height: 10),
              ],
              if (imageUrls.isNotEmpty) ...[
                pw.Text('صور إضافية:',  style: labelStyle,
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,),
                pw.SizedBox(height: 5),
                _buildImagesGrid(imageUrls, borderColor,
                    images: images, size: imageSize),
              ],
            ],
          ],
        ),
      );
    }

    static pw.Widget _buildImagesGrid(
        List<String> urls,
        PdfColor borderColor, {
          Map<String, String>? images,
          double size = 80,
        }) {
      if (urls.isEmpty) return pw.SizedBox();

      return pw.Container(
        width: double.infinity,
        alignment: pw.Alignment.topRight,
          child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.GridView(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            // GridView in the pdf package requires either a bounded height
            // or a fixed childAspectRatio. Without this, generating a report
            // fails with an assertion because the grid's dimensions can't be
            // calculated when both the height constraints and aspect ratio are
            // infinite. We approximate each grid tile as a square image with a
            // small caption underneath, so we set an aspect ratio slightly
            // smaller than 1 to leave room for the caption. This keeps the
            // layout stable and prevents the runtime error.
            childAspectRatio: size / (size + 20),
            children: List.generate(urls.length, (index) {
              final url = urls[index];
              return pw.Builder(builder: (context) {
                final path = images?[url];
                if (path == null) return pw.SizedBox();
                final bytes = File(path).readAsBytesSync();
                final memImg = pw.MemoryImage(bytes);
                PdfImageCache.precache.remove(url);
                return pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: size,
                      height: size,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Image(memImg, fit: pw.BoxFit.cover),
                    ),
                    pw.SizedBox(height: 4),
                    pw.UrlLink(
                      destination: url,
                      child: pw.Text(
                        'معاينة',
                        style: pw.TextStyle(
                          font: _arabicFont,
                          fontSize: 10,
                          color: PdfColors.blue,
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                );
              });
            }),
          ),
        ),
      );
    }



    static List<pw.Widget> _buildImageLinkWidgets(
        List<String> urls,
        Map<String, String> images, {
        double size = 80,
        }) {
      return urls.map((url) {
        final path = images[url];
        if (path == null) return pw.SizedBox();
        final img = pw.MemoryImage(File(path).readAsBytesSync());
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Image(img, width: size, height: size),
            pw.SizedBox(height: 4),
            pw.UrlLink(
              destination: url,
              child: pw.Text(
                'معاينة',
                style: pw.TextStyle(
                  font: _arabicFont,
                  fontSize: 10,
                  color: PdfColors.blue,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      }).toList();
    }



    static pw.Widget _buildTestCard(
        Map<String, dynamic> test,
        int index,
        pw.TextStyle subHeaderStyle,
        pw.TextStyle regularStyle,
        pw.TextStyle labelStyle,
        pw.TextStyle metaStyle,
        PdfColor borderColor,
        PdfColor lightGrey,
        {Map<String, String>? images,
        double imageSize = 120}) {
      final note = test['note'] ?? '';
      final engineer = test['engineerName'] ?? 'مهندس';
      final ts = (test['lastUpdatedAt'] as Timestamp?)?.toDate();
      final dateStr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'ar').format(ts) : '';
      final section = test['sectionName'] ?? '';
      final name = test['testName'] ?? '';
      final imgUrl = test['imageUrl'];

      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 20),
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: borderColor, width: 1.5),
          borderRadius: pw.BorderRadius.circular(12),
          boxShadow: [
            pw.BoxShadow(
              color: PdfColors.grey300,
              blurRadius: 4,
            ),
          ],
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Header Section
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 15),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: borderColor,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      'رقم الاختبار #$index',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '$section - $name',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                      textAlign: pw.TextAlign.right,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 15),

            // Information Section
            pw.Container(
              width: double.infinity,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          engineer,
                          style: regularStyle,
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          'المهندس المسؤول:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(
                          dateStr,
                          style: regularStyle,
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(color: lightGrey),
                        child: pw.Text(
                          'آخر تحديث:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  if (note.toString().isNotEmpty)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightGrey),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            note.toString(),
                            style: regularStyle,
                            textAlign: pw.TextAlign.right,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'الأعمال المستلمة:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.right,
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Image Section
            if (imgUrl != null) ...[
              pw.SizedBox(height: 20),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                ),
                child: pw.Text(
                  'الصورة المرفقة:',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
              pw.SizedBox(height: 10),
              if (images?[imgUrl] != null)
                pw.Image(
                  pw.MemoryImage(File(images![imgUrl]!).readAsBytesSync()),
                  width: imageSize,
                  height: imageSize,
                ),
            ],
          ],
        ),
      );
    }


    static pw.Widget _buildRequestsTable(

        List<Map<String, dynamic>> requests,

        pw.TextStyle regularStyle,

        pw.TextStyle labelStyle,

        PdfColor borderColor,

        PdfColor lightGrey) {

      // إنشاء قائمة منفصلة لكل مادة في كل طلب
      final List<Map<String, dynamic>> expandedRequests = [];

      for (final pr in requests) {
        final List<dynamic>? items = pr['items'];
        final status = pr['status'] ?? '';
        final eng = pr['engineerName'] ?? '';
        final ts = (pr['requestedAt'] as Timestamp?)?.toDate();
        final dateStr = ts != null ? DateFormat('dd/MM/yy', 'ar').format(ts) : '';

        if (items != null && items.isNotEmpty) {
          // إذا كان الطلب يحتوي على مواد متعددة، أنشئ صف منفصل لكل مادة
          for (final item in items) {
            expandedRequests.add({
              'dateStr': dateStr,
              'engineerName': eng,
              'status': status,
              'quantity': item['quantity']?.toString() ?? '1',
              'materialName': item['name'] ?? '',
            });
          }
        } else {
          // إذا كان الطلب يحتوي على مادة واحدة فقط
          expandedRequests.add({
            'dateStr': dateStr,
            'engineerName': eng,
            'status': status,
            'quantity': pr['quantity']?.toString() ?? '1',
            'materialName': pr['partName'] ?? '',
          });
        }
      }

      return pw.Table(

        border: pw.TableBorder.all(color: borderColor),

        children: [

          pw.TableRow(

            decoration: pw.BoxDecoration(color: lightGrey),

            children: [

              pw.Padding(

                padding: const pw.EdgeInsets.all(8),

                child: pw.Text('التاريخ',

                    style: labelStyle, textAlign: pw.TextAlign.center),

              ),

              pw.Padding(

                padding: const pw.EdgeInsets.all(8),

                child: pw.Text('المهندس',

                    style: labelStyle, textAlign: pw.TextAlign.center),

              ),

              pw.Padding(

                padding: const pw.EdgeInsets.all(8),

                child: pw.Text('الحالة',

                    style: labelStyle, textAlign: pw.TextAlign.center),

              ),

              pw.Padding(

                padding: const pw.EdgeInsets.all(8),

                child: pw.Text('الكمية',

                    style: labelStyle, textAlign: pw.TextAlign.center),

              ),

              pw.Padding(

                padding: const pw.EdgeInsets.all(8),

                child: pw.Text('اسم المادة',

                    style: labelStyle, textAlign: pw.TextAlign.center),

              ),

            ],

          ),

          ...expandedRequests.map((pr) {

            return pw.TableRow(

              children: [

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(pr['dateStr'],

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(pr['engineerName'],

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(pr['status'],

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(pr['quantity'],

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(pr['materialName'],

                      style: regularStyle, textAlign: pw.TextAlign.right),

                ),

              ],

            );

          }).toList(),

        ],

      );

    }


    static pw.Widget _buildImportantNotice(pw.TextStyle regularStyle) {

      return pw.Container(

        padding: const pw.EdgeInsets.all(15),

        decoration: pw.BoxDecoration(

          color: PdfColor.fromHex('#FFF3E0'),

          border: pw.Border.all(color: PdfColor.fromHex('#FF9800'), width: 2),

          borderRadius: pw.BorderRadius.circular(8),

        ),

        child: pw.Row(

          children: [

            pw.Expanded(

              child: pw.Text(

                'ملاحظة هامة: في حال مضى 24 ساعة يعتبر هذا التقرير مكتمل وغير قابل للتعديل.',

                style: pw.TextStyle(

                  font: _arabicFont,

                  color: PdfColor.fromHex('#E65100'),

                  fontWeight: pw.FontWeight.bold,

                  fontSize: 14,

                ),

                textDirection: pw.TextDirection.rtl,

                textAlign: pw.TextAlign.right,

              ),

            ),

            pw.SizedBox(width: 10),

            pw.Container(

              width: 30,

              height: 30,

              decoration: pw.BoxDecoration(

                color: PdfColor.fromHex('#FF9800'),

                borderRadius: pw.BorderRadius.circular(15),

              ),

              child: pw.Center(

                child: pw.Text(

                  '!',

                  style: pw.TextStyle(

                    font: _arabicFont,

                    color: PdfColors.white,

                    fontWeight: pw.FontWeight.bold,

                    fontSize: 18,

                  ),

                ),

              ),

            ),

          ],

        ),

      );

    }

    // Generates a simplified PDF report that lists phase entries and tests in
    // simple tables without headers or footers.
  static Future<Uint8List> generateSimpleTables({
      required String projectId,
      required List<Map<String, dynamic>> phases,
      required List<Map<String, dynamic>> testsStructure,
      DateTime? start,
      DateTime? end,
      void Function(double progress)? onProgress,
      bool lowMemory = false,
      Uint8List? arabicFontBytes,
    }) async {
      PdfImageCache.clear();
      PdfImageCache.clearPrecache();
      onProgress?.call(0.0);
      try {
      int imgQuality = lowMemory ? _lowMemJpgQuality : _jpgQuality;
      int fetchConcurrency = lowMemory ? 1 : 3;
      DateTime now = DateTime.now();
      bool useRange = start != null || end != null;
      if (useRange) {
        start ??= DateTime(now.year, now.month, now.day);
        end ??= start.add(const Duration(days: 1));
      }

      final List<Map<String, dynamic>> dayEntries = [];
      final List<Map<String, dynamic>> dayTests = [];
      // Collect all image URLs so we can fetch them in a single batch
      final Set<String> imageUrls = {};

      try {
        List<Future<void>> fetchTasks = [];
        for (var phase in phases) {
          final phaseId = phase['id'];
          final phaseName = phase['name'];
          fetchTasks.add(() async {
            Query<Map<String, dynamic>> q = FirebaseFirestore.instance
                .collection('projects')
                .doc(projectId)
                .collection('phases_status')
                .doc(phaseId)
                .collection('entries');
            if (useRange) {
              q = q
                  .where('timestamp', isGreaterThanOrEqualTo: start)
                  .where('timestamp', isLessThan: end);
            }
            final snap = await q.orderBy('timestamp').get();
            for (var doc in snap.docs) {
              final data = doc.data();
              // دعم الهياكل القديمة والجديدة للصور
              final imgs = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                          (data['otherImages'] as List?)?.map((e) => e.toString()).toList() ?? 
                          (data['otherImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final beforeImgs = (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                                (data['beforeImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final afterImgs = (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                               (data['afterImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
              imageUrls.addAll(imgs);
              imageUrls.addAll(beforeImgs);
              imageUrls.addAll(afterImgs);
              dayEntries.add({
                ...data,
                'phaseName': phaseName,
                'subPhaseName': null,
              });
            }
          }());

          for (var sub in phase['subPhases']) {
            final subId = sub['id'];
            final subName = sub['name'];
            fetchTasks.add(() async {
              Query<Map<String, dynamic>> qSub = FirebaseFirestore.instance
                  .collection('projects')
                  .doc(projectId)
                  .collection('subphases_status')
                  .doc(subId)
                  .collection('entries');
              if (useRange) {
                qSub = qSub
                    .where('timestamp', isGreaterThanOrEqualTo: start)
                    .where('timestamp', isLessThan: end);
              }
              final subSnap = await qSub.orderBy('timestamp').get();
              for (var doc in subSnap.docs) {
                final data = doc.data();
                // دعم الهياكل القديمة والجديدة للصور
                final imgs = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                            (data['otherImages'] as List?)?.map((e) => e.toString()).toList() ?? 
                            (data['otherImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final beforeImgs = (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                                  (data['beforeImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final afterImgs = (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? 
                                 (data['afterImages'] as List?)?.map((e) => e.toString()).toList() ?? [];
                imageUrls.addAll(imgs);
                imageUrls.addAll(beforeImgs);
                imageUrls.addAll(afterImgs);
                dayEntries.add({
                  ...data,
                  'phaseName': phaseName,
                  'subPhaseName': subName,
                });
              }
            }());
          }
        }

        final Map<String, Map<String, String>> testInfo = {};
        for (var section in testsStructure) {
          final sectionName = section['section_name'] as String;
          for (var t in section['tests'] as List) {
            testInfo[(t as Map)['id']] = {
              'name': t['name'] as String,
              'section': sectionName,
            };
          }
        }

        fetchTasks.add(() async {
          Query<Map<String, dynamic>> qTests = FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('tests_status');
          if (useRange) {
            qTests = qTests
                .where('lastUpdatedAt', isGreaterThanOrEqualTo: start)
                .where('lastUpdatedAt', isLessThan: end);
          }
          final testsSnap = await qTests.get();
          for (var doc in testsSnap.docs) {
            final data = doc.data();
            final info = testInfo[doc.id];
            final imgUrl = data['imageUrl'] as String?;
            if (imgUrl != null) imageUrls.add(imgUrl);
            dayTests.add({
              ...data,
              'testId': doc.id,
              'testName': info?['name'] ?? doc.id,
              'sectionName': info?['section'] ?? '',
            });
          }
        }());

        await Future.wait(fetchTasks);

        // Automatically switch to low-memory mode if too many photos were
        // collected to avoid running out of memory during generation.
        if (!lowMemory && imageUrls.length > _autoLowMemoryThreshold) {
          lowMemory = true;
          imgQuality = _lowMemJpgQuality;
          fetchConcurrency = 1;
        }

      } catch (e) {
        print('Error preparing simple report details: $e');
      }

      final bool thumbnailMode =
          imageUrls.length >= _thumbnailCountThreshold;
      final bool extremeThumbnailMode =
          imageUrls.length >= _extremeThumbnailCountThreshold;

      // Determine image size based on photo count and memory mode
      final int imgDim = extremeThumbnailMode
          ? _extremeLowMemImageDimension
          : thumbnailMode
              ? _thumbnailDimension
              : lowMemory
                  ? _adaptiveLowMemoryDimension(imageUrls.length)
                  : _adaptiveHighQualityDimension(imageUrls.length);

      final double gridSize = extremeThumbnailMode
          ? _extremeThumbnailDimension.toDouble()
          : thumbnailMode
              ? _thumbnailDimension.toDouble()
              : 80.0;

      final tempDir = await Directory.systemTemp.createTemp('simple_report_imgs');
      final fetchedImages = await _fetchImagesForUrls(
        imageUrls.toList(),
        onProgress: (p) => onProgress?.call(0.6 + p * 0.3),
        concurrency: fetchConcurrency,
        maxDimension: imgDim,
        quality: imgQuality,
        tempDir: tempDir,
      );

      onProgress?.call(0.9);

      await _loadArabicFont(fontBytes: arabicFontBytes);
      if (_arabicFont == null) {
        throw Exception('Arabic font not available');
      }

      // Use maximum compression for the simplified report as well.
      final pdf = pw.Document(
        compress: true,
        version: PdfVersion.pdf_1_5,
      );
      final fileName =
          'simple_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final token = generateReportToken();

      final pw.TextStyle headerStyle = pw.TextStyle(
        font: _arabicFont,
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
      );
      final pw.TextStyle cellStyle = pw.TextStyle(
        font: _arabicFont,
        fontSize: 14,
      );

      pdf.addPage(
        pw.MultiPage(
          maxPages: 10000,
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(
              base: _arabicFont,
              bold: _arabicFont,
              italic: _arabicFont,
              boldItalic: _arabicFont,
            ),
            // Provide some spacing on the sides since there is no header or footer
            margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          ),
          build: (context) => [
            pw.Text('الملاحظات والتحديثات', style: headerStyle),
            pw.SizedBox(height: 10),
            dayEntries.isEmpty
                ? pw.Text('لا توجد بيانات', style: cellStyle)
                : _buildSimpleEntriesTable(
                    dayEntries,
                    headerStyle,
                    cellStyle,
                    PdfColors.grey300,
                    PdfColors.grey400,
                    fetchedImages,
                    imageSize: gridSize,
                  ),
            pw.SizedBox(height: 20),
            pw.Text('الاختبارات والفحوصات', style: headerStyle),
            pw.SizedBox(height: 10),
            dayTests.isEmpty
                ? pw.Text('لا توجد بيانات', style: cellStyle)
                : _buildSimpleTestsTable(
                    dayTests,
                    headerStyle,
                    cellStyle,
                    PdfColors.grey300,
                    PdfColors.grey400,
                    fetchedImages,
                    imageSize: gridSize,
                  ),
          ],
        ),
      );
      // Clear the cache after rendering the page.
      PdfImageCache.clearPrecache();
      PdfImageCache.clear();

      final bytes = await pdf.save();
      onProgress?.call(1.0);
      await uploadReportPdf(bytes, fileName, token);
      await tempDir.delete(recursive: true);
      return bytes;
      } finally {
        PdfImageCache.clear();
        PdfImageCache.clearPrecache();
      }
    }

    static pw.Widget _buildSimpleEntriesTable(
      List<Map<String, dynamic>> entries,
      pw.TextStyle headerStyle,
      pw.TextStyle cellStyle,
      PdfColor headerColor,
      PdfColor borderColor,
      Map<String, String> images,
      {double imageSize = 80}) {
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final entry in entries) {
        final phaseName = entry['phaseName'] ?? '';
        final sub = entry['subPhaseName'];
        final key = sub != null ? '$phaseName > $sub' : phaseName;
        grouped.putIfAbsent(key, () => []).add(entry);
      }

      final List<pw.Widget> widgets = [];
      grouped.forEach((phase, items) {
        widgets.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(6),
            color: headerColor,
            child: pw.Text(
              phase,
              style: headerStyle.copyWith(color: PdfColors.white),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        );

        for (final item in items) {
          final note = item['note']?.toString() ?? '';
          final imgs =
              (item['imageUrls'] as List?)?.map((it) => it.toString()).toList() ?? [];
          final imgWidgets =
              _buildImageLinkWidgets(imgs, images, size: imageSize);

          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: const {0: pw.FlexColumnWidth()},
              children: [
                pw.TableRow(children: [
                  pw.Container(
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('ملاحظات',
                        style: headerStyle.copyWith(color: PdfColors.white),
                        textDirection: pw.TextDirection.rtl),
                  ),
                ]),
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      note.isEmpty ? '-' : note,
                      style: cellStyle,
                      textAlign: pw.TextAlign.center,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ]),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 5));

          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: const {0: pw.FlexColumnWidth()},
              children: [
                pw.TableRow(children: [
                  pw.Container(
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('الصور',
                        style: headerStyle.copyWith(color: PdfColors.white),
                        textDirection: pw.TextDirection.rtl),
                  ),
                ]),
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: imgWidgets.isEmpty
                        ? pw.Text('-',
                            style: cellStyle,
                            textAlign: pw.TextAlign.center)
                        : pw.Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            alignment: pw.WrapAlignment.center,
                            children: imgWidgets,
                          ),
                  ),
                ]),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 10));
        }
      });

      return pw.Column(children: widgets);
    }
  static pw.Widget _buildSimpleTestsTable(
      List<Map<String, dynamic>> tests,
      pw.TextStyle headerStyle,
      pw.TextStyle cellStyle,
      PdfColor headerColor,
      PdfColor borderColor,
      Map<String, String> images,
      {double imageSize = 80}) {
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final t in tests) {
        final name = '${t['sectionName'] ?? ''} - ${t['testName'] ?? ''}';
        grouped.putIfAbsent(name, () => []).add(t);
      }

      final List<pw.Widget> widgets = [];
      grouped.forEach((test, items) {
        widgets.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(6),
            color: headerColor,
            child: pw.Text(
              test,
              style: headerStyle.copyWith(color: PdfColors.white),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        );

        for (final item in items) {
          final note = item['note']?.toString() ?? '';
          final url = item['imageUrl'] as String?;
          final imgWidgets = url != null
              ? _buildImageLinkWidgets([url], images, size: imageSize)
              : <pw.Widget>[];

          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: const {0: pw.FlexColumnWidth()},
              children: [
                pw.TableRow(children: [
                  pw.Container(
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('ملاحظات',
                        style: headerStyle.copyWith(color: PdfColors.white),
                        textDirection: pw.TextDirection.rtl),
                  ),
                ]),
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      note.isEmpty ? '-' : note,
                      style: cellStyle,
                      textAlign: pw.TextAlign.center,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ]),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 5));

          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: borderColor),
              columnWidths: const {0: pw.FlexColumnWidth()},
              children: [
                pw.TableRow(children: [
                  pw.Container(
                    color: headerColor,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('الصور',
                        style: headerStyle.copyWith(color: PdfColors.white),
                        textDirection: pw.TextDirection.rtl),
                  ),
                ]),
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: imgWidgets.isEmpty
                        ? pw.Text('-',
                            style: cellStyle,
                            textAlign: pw.TextAlign.center)
                        : pw.Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            alignment: pw.WrapAlignment.center,
                            children: imgWidgets,
                          ),
                  ),
                ]),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 10));
        }
      });

      return pw.Column(children: widgets);
    }

    static pw.Widget _tableCell(
      String text,
      pw.TextStyle style,
      bool isHeader,
    ) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          style: isHeader ? style.copyWith(color: PdfColors.white) : style,
          textAlign: pw.TextAlign.center,
          textDirection: pw.TextDirection.rtl,
        ),
      );
    }

    static pw.TableRow _headerRow(
      String title,
      pw.TextStyle style,
      PdfColor color,
    ) {
      return pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            alignment: pw.Alignment.center,
            color: color,
            child: pw.Text(
              title,
              style: style.copyWith(color: PdfColors.white),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
          pw.Container(),
        ],
      );
    }

    /// إنشاء تقرير من Snapshot جاهز
    static Future<PdfReportResult> generateFromSnapshot({
      required String projectId,
      required Map<String, dynamic> snapshot,
      String? generatedBy,
      String? generatedByRole,
      void Function(double progress)? onProgress,
      bool lowMemory = false,
      Uint8List? arabicFontBytes,
    }) async {
      try {
        onProgress?.call(0.0);
        
        // استخراج البيانات من Snapshot مع التحقق من صحة البيانات
        final phasesData = List<Map<String, dynamic>>.from(snapshot['phasesData'] ?? []);
        final testsData = List<Map<String, dynamic>>.from(snapshot['testsData'] ?? []);
        final materialsData = List<Map<String, dynamic>>.from(snapshot['materialsData'] ?? []);
        final imagesData = List<Map<String, dynamic>>.from(snapshot['imagesData'] ?? []);
        
        // فحص إذا كان الـ Snapshot فارغاً أو يحتوي على بيانات غير صالحة
        final totalEntries = phasesData.fold<int>(0, (sum, phase) {
          final entries = phase['entries'] as List? ?? [];
          return sum + entries.length;
        });
        
        if (totalEntries == 0 && testsData.isEmpty && materialsData.isEmpty) {
          throw Exception('لا توجد بيانات في Snapshot - قد تحتاج إلى إعادة بناء Snapshot');
        }
        
        print('Generating report from snapshot - Phases: ${phasesData.length}, Total entries: $totalEntries, Tests: ${testsData.length}, Materials: ${materialsData.length}');
        
        onProgress?.call(0.2);
        
        // تجميع URLs الصور
        final Set<String> imageUrls = {};
        for (final image in imagesData) {
          if (image['url'] != null) {
            imageUrls.add(image['url'].toString());
          }
        }
        
        onProgress?.call(0.4);
        
        // معالجة الصور (مع الكاش المحسن)
        final tempDir = await Directory.systemTemp.createTemp('report_imgs');
        final fetchedImages = await _fetchImagesForUrls(
          imageUrls.toList(),
          onProgress: (p) => onProgress?.call(0.4 + p * 0.3),
          concurrency: lowMemory ? 1 : 3,
          maxDimension: lowMemory ? _lowMemImageDimension : _maxImageDimension,
          quality: lowMemory ? _lowMemJpgQuality : _jpgQuality,
          tempDir: tempDir,
        );
        
        onProgress?.call(0.7);
        
        // إنشاء PDF (نفس المنطق الموجود)
        await _loadArabicFont(fontBytes: arabicFontBytes);
        if (_arabicFont == null) {
          throw Exception('Arabic font not available');
        }
        
        final pdf = pw.Document(compress: true, version: PdfVersion.pdf_1_5);
        final fileName = 'report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
        final token = generateReportToken();
        final qrLink = buildReportDownloadUrl(fileName, token);

        // استخدام البيانات من Snapshot لبناء PDF
        final projectData = snapshot['projectData'] as Map<String, dynamic>? ?? {};
        final projectName = projectData['name'] ?? 'مشروع غير مسمى';
        final clientName = projectData['clientName'] ?? 'غير معروف';
        
        // بناء صفحات PDF باستخدام البيانات المجمعة
        pdf.addPage(
          pw.MultiPage(
            maxPages: 10000,
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              textDirection: pw.TextDirection.rtl,
              theme: pw.ThemeData.withFont(
                base: _arabicFont,
                bold: _arabicFont,
                italic: _arabicFont,
                boldItalic: _arabicFont,
              ),
              margin: const pw.EdgeInsets.all(20),
            ),
            header: (context) => pw.Container(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text('تقرير المشروع: $projectName', 
                style: pw.TextStyle(font: _arabicFont, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            build: (context) => [
              // تفاصيل المشروع
              pw.Text('اسم المشروع: $projectName', style: pw.TextStyle(font: _arabicFont, fontSize: 16)),
              pw.Text('اسم العميل: $clientName', style: pw.TextStyle(font: _arabicFont, fontSize: 16)),
              pw.SizedBox(height: 20),
              
              // إحصائيات سريعة
              pw.Text('إحصائيات التقرير:', style: pw.TextStyle(font: _arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('عدد الإدخالات: ${phasesData.length}', style: pw.TextStyle(font: _arabicFont, fontSize: 14)),
              pw.Text('عدد الاختبارات: ${testsData.length}', style: pw.TextStyle(font: _arabicFont, fontSize: 14)),
              pw.Text('عدد طلبات المواد: ${materialsData.length}', style: pw.TextStyle(font: _arabicFont, fontSize: 14)),
              pw.Text('عدد الصور: ${imagesData.length}', style: pw.TextStyle(font: _arabicFont, fontSize: 14)),
              pw.SizedBox(height: 20),
              
              // ملخص المراحل مع التفاصيل
              if (phasesData.isNotEmpty) ...[
                pw.Text('المراحل:', style: pw.TextStyle(font: _arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ...phasesData.map((phase) {
                  final entries = phase['entries'] as List? ?? [];
                  final entryCount = entries.length;
                  final phaseName = phase['name'] ?? phase['id'];
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• $phaseName ($entryCount إدخال)', 
                        style: pw.TextStyle(font: _arabicFont, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (entryCount > 0) ...[
                        pw.SizedBox(height: 5),
                        ...entries.take(3).map((entry) => pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 20),
                          child: pw.Text('- ${entry['notes'] ?? 'لا توجد ملاحظات'}', 
                            style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
                        )),
                        if (entryCount > 3)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(right: 20),
                            child: pw.Text('... و ${entryCount - 3} إدخالات أخرى', 
                              style: pw.TextStyle(font: _arabicFont, fontSize: 12, fontStyle: pw.FontStyle.italic)),
                          ),
                      ],
                      pw.SizedBox(height: 10),
                    ],
                  );
                }),
                pw.SizedBox(height: 20),
              ],
              
              // ملخص الاختبارات مع التفاصيل
              if (testsData.isNotEmpty) ...[
                pw.Text('الاختبارات:', style: pw.TextStyle(font: _arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ...testsData.map((test) {
                  final testName = test['name'] ?? test['id'];
                  final status = test['status'] ?? 'غير محدد';
                  final notes = test['notes'] ?? '';
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• $testName (الحالة: $status)', 
                        style: pw.TextStyle(font: _arabicFont, fontSize: 14)),
                      if (notes.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 20),
                          child: pw.Text('ملاحظات: $notes', 
                            style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
                        ),
                      pw.SizedBox(height: 5),
                    ],
                  );
                }),
                pw.SizedBox(height: 20),
              ],
              
              // ملخص طلبات المواد
              if (materialsData.isNotEmpty) ...[
                pw.Text('طلبات المواد:', style: pw.TextStyle(font: _arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ...materialsData.map((material) {
                  final materialName = material['materialName'] ?? 'مادة غير مسماة';
                  final quantity = material['quantity'] ?? 0;
                  final status = material['status'] ?? 'معلق';
                  return pw.Text('• $materialName (الكمية: $quantity، الحالة: $status)', 
                    style: pw.TextStyle(font: _arabicFont, fontSize: 14));
                }),
                pw.SizedBox(height: 20),
              ],
              
              // رسالة إذا لم تكن هناك بيانات
              if (phasesData.isEmpty && testsData.isEmpty && materialsData.isEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.orange),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('⚠️ تنبيه', 
                        style: pw.TextStyle(font: _arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Text('لا توجد بيانات متاحة في هذا التقرير. قد تحتاج إلى:', 
                        style: pw.TextStyle(font: _arabicFont, fontSize: 14)),
                      pw.Text('• إضافة بيانات للمشروع', 
                        style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
                      pw.Text('• إعادة بناء Snapshot التقرير', 
                        style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
        PdfImageCache.clearPrecache();

        onProgress?.call(0.9);
        
        final pdfBytes = await pdf.save();
        final url = await uploadReportPdf(pdfBytes, fileName, token);
        await tempDir.delete(recursive: true);
        PdfImageCache.clearPrecache();
        
        onProgress?.call(1.0);
        
        return PdfReportResult(bytes: pdfBytes, downloadUrl: url);
        
      } catch (e) {
        print('Error generating PDF from snapshot: $e');
        rethrow;
      }
    }

  }

  // The isolate implementation previously used for offloading PDF generation
  // has been removed. Generating the report directly simplifies asset and
  // Firebase usage, ensuring compatibility across all platforms.