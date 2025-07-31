import 'dart:async';

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


  import 'pdf_styles.dart';

  import 'pdf_image_cache.dart';

  import 'report_storage.dart';

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
  static const int _lowMemJpgQuality = 60;
  // Automatically enable low-memory mode when the report contains
  // a large number of photos. This prevents out-of-memory failures on
  // devices with limited resources by downscaling images and reducing
  // concurrency from the start instead of retrying after a crash.
  static const int _autoLowMemoryThreshold = 100; // photos
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
    if (count >= 200) return _veryLowMemImageDimension;
    if (count >= 100) return 192;
    if (count >= 50) return _lowMemImageDimension;
    return _lowMemImageDimension;
  }

    /// استخدام أبعاد عالية الجودة بشكل دائم
  static int _adaptiveHighQualityDimension(int count) {
    if (count >= 200) return 256;
    if (count >= 100) return 384;
    if (count >= 50) return 512;
    return _maxImageDimension;
  }


    static Future<void> _loadArabicFont({Uint8List? fontBytes}) async {

      if (_arabicFont != null) return;

      try {

        final bytes = fontBytes ??
            (await rootBundle.load('assets/fonts/Tajawal-Bold.ttf')).buffer.asUint8List();

        _arabicFont = pw.Font.ttf(bytes);

      } catch (e) {

        print('Error loading Arabic font: $e');

      }

    }

  static Future<Uint8List> _resizeImageIfNeeded(Uint8List bytes,
      {int? maxDimension, int? quality}) async {
    // Fallback to max dimension when none provided.
    final dim = maxDimension ?? _maxImageDimension;
    final q = quality ?? _jpgQuality;
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    // Skip resizing when the image is already within the limit.
    if (image.width <= dim && image.height <= dim) {
      return Uint8List.fromList(img.encodeJpg(image, quality: q));
    }
    final resized = img.copyResize(image,
        width: image.width >= image.height ? dim : null,
        height: image.height > image.width ? dim : null);
    return Uint8List.fromList(img.encodeJpg(resized, quality: q));
  }

    @visibleForTesting
    static Future<Uint8List> resizeImageForTest(Uint8List bytes,
            {int? maxDimension, int? quality}) =>
        _resizeImageIfNeeded(bytes,
            maxDimension: maxDimension, quality: quality);




    static Future<Map<String, pw.MemoryImage>> _fetchImagesForUrls(
        List<String> urls, {
        void Function(double progress)? onProgress,
        // Reduce concurrent downloads to lower simultaneous memory pressure.
        int concurrency = 3,
        int? maxDimension,
        int? quality,
      }) async {
      final Map<String, pw.MemoryImage> fetched = {};
      final uniqueUrls = urls.toSet().toList();
      int completed = 0;

      Future<void> handleUrl(String url) async {
        if (fetched.containsKey(url)) return;
        final cached = PdfImageCache.get(url);
        if (cached != null) {
          fetched[url] = cached;
        } else {
          try {
            // Check the file size first to avoid downloading extremely large
            // images that could cause memory issues during decoding.
            try {
              final head = await http
                  .head(Uri.parse(url))
                  .timeout(const Duration(seconds: 30));
              final lenStr = head.headers['content-length'];
              final len = lenStr != null ? int.tryParse(lenStr) : null;
              if (len != null && len > maxImageFileSize) {
                // Skip oversized images
                print('Skipping large image from URL $url: $len bytes');
                return;
              }
            } catch (_) {
              // Ignore HEAD errors and attempt full download.
            }

            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 120));
            final contentType = response.headers['content-type'] ?? '';
            if (response.statusCode == 200 && contentType.startsWith('image/')) {
              final resizedBytes = await _resizeImageIfNeeded(response.bodyBytes,
                  maxDimension: maxDimension, quality: quality);
              final memImg = pw.MemoryImage(resizedBytes);
              fetched[url] = memImg;
              PdfImageCache.put(url, memImg);
            }
          } catch (e) {
            print('Error fetching image from URL $url: $e');
          }
        }
        onProgress?.call(++completed / uniqueUrls.length);
      }

      for (int i = 0; i < uniqueUrls.length; i += concurrency) {
        final batch = uniqueUrls.skip(i).take(concurrency).toList();
        await Future.wait(batch.map(handleUrl));
        // Drop references to the batch images once they are cached
        PdfImageCache.clearPrecache();
        // Allow GC to run between batches
        await Future.delayed(const Duration(milliseconds: 10));
      }
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
      bool lowMemory = false,
      Uint8List? arabicFontBytes,
    }) async {
      // Ensure the cache does not retain images from previous reports
      PdfImageCache.clear();
      onProgress?.call(0.0);
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
            final imgs = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final beforeImgs = (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final afterImgs = (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
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
              final imgs = (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final beforeImgs = (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final afterImgs = (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
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


      // Enable low-memory mode automatically when the number of
      // collected images exceeds the configured threshold.
      if (!lowMemory && imageUrls.length > _autoLowMemoryThreshold) {
        lowMemory = true;
        imgQuality = _lowMemJpgQuality;
        fetchConcurrency = 1;
      }

      await _loadArabicFont(fontBytes: arabicFontBytes);

      if (_arabicFont == null) {

        throw Exception('Arabic font not available');

      }

      // Determine image size based on photo count and memory mode
      final int imgDim = lowMemory
          ? _adaptiveLowMemoryDimension(imageUrls.length)
          : _adaptiveHighQualityDimension(imageUrls.length);

      final fetchedImages = await _fetchImagesForUrls(
        imageUrls.toList(),
        onProgress: (p) => onProgress?.call(0.6 + p * 0.3),
        concurrency: fetchConcurrency,
        maxDimension: imgDim,
        quality: imgQuality,
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

            final widgets = <pw.Widget>[];
            widgets.add(
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
            );
            widgets.add(pw.SizedBox(height: 20));



            widgets.add(pw.SizedBox(height: 30));


            widgets.add(_buildSectionHeader('الملاحظات والتحديثات', headerStyle, PdfColors.blueGrey800));

            widgets.add(pw.SizedBox(height: 15));

            if (dayEntries.isEmpty) {

              widgets.add(_buildEmptyState('لا توجد ملاحظات مسجلة في هذه الفترة', regularStyle, PdfColors.grey100));

            } else {

              for (int i = 0; i < dayEntries.length; i++) {

                final entry = dayEntries[i];

                widgets.add(_buildEntryCard(
                    entry,
                    i + 1,
                    headerStyle,
                    regularStyle,
                    regularStyle,
                    smallGrey,
                    PdfColors.grey400,
                    PdfColors.grey100,
                    images: fetchedImages));

                widgets.add(pw.SizedBox(height: 15));

              }

            }


            widgets.add(pw.SizedBox(height: 20));

            widgets.add(_buildSectionHeader('الاختبارات والفحوصات', headerStyle, PdfColors.blueGrey800));

            widgets.add(pw.SizedBox(height: 15));

            if (dayTests.isEmpty) {

              widgets.add(_buildEmptyState('لا توجد اختبارات محدثة في هذه الفترة', regularStyle, PdfColors.grey100));

            } else {

              for (int i = 0; i < dayTests.length; i++) {

                final test = dayTests[i];

                widgets.add(_buildTestCard(

                    test,

                    i + 1,

                    headerStyle,

                    regularStyle,

                    regularStyle,

                    smallGrey,

                    PdfColors.grey400,

                    PdfColors.grey100,

                    images: fetchedImages));

                widgets.add(pw.SizedBox(height: 15));

              }

            }


            widgets.add(pw.SizedBox(height: 20));

            widgets.add(_buildSectionHeader('طلبات المواد والمعدات', headerStyle, PdfColors.blueGrey800));

            widgets.add(pw.SizedBox(height: 15));

            if (dayRequests.isEmpty) {

              widgets.add(_buildEmptyState('لا توجد طلبات مواد في هذه الفترة', regularStyle, PdfColors.grey100));

            } else {

              widgets.add(_buildRequestsTable(dayRequests, regularStyle, regularStyle,

                  PdfColors.grey400, PdfColors.grey100));

            }


            widgets.add(pw.SizedBox(height: 20));

            widgets.add(_buildImportantNotice(regularStyle));

            return widgets;

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
      // Release any cached images once the page is rendered.
      PdfImageCache.clear();

      final pdfBytes = await pdf.save();
      onProgress?.call(1.0);
      final url = await uploadReportPdf(pdfBytes, fileName, token);

      return PdfReportResult(bytes: pdfBytes, downloadUrl: url);
      } finally {
        PdfImageCache.clear();
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
      if (!lowMemory) {
        // For modern devices it's faster to run on the main isolate.
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

      // Older low-memory devices benefit from offloading the heavy work.
      final fontBytes =
          (await rootBundle.load('assets/fonts/Tajawal-Bold.ttf')).buffer.asUint8List();

      return compute(_generateIsolate, {
        'projectId': projectId,
        'projectData': projectData,
        'phases': phases,
        'testsStructure': testsStructure,
        'generatedBy': generatedBy,
        'generatedByRole': generatedByRole,
        'start': start,
        'end': end,
        'fontData': fontBytes,
      });
    }

  static Future<PdfReportResult> _generateIsolate(
        Map<String, dynamic> args) async {
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
        {Map<String, pw.MemoryImage>? images}) {
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
                _buildImagesGrid(beforeUrls, borderColor, images: images),
                pw.SizedBox(height: 10),
              ],
              if (afterUrls.isNotEmpty) ...[
                pw.Text('صور بعد:',  style: labelStyle,
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,),
                pw.SizedBox(height: 5),
                _buildImagesGrid(afterUrls, borderColor, images: images),
                pw.SizedBox(height: 10),
              ],
              if (imageUrls.isNotEmpty) ...[
                pw.Text('صور إضافية:',  style: labelStyle,
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,),
                pw.SizedBox(height: 5),
                _buildImagesGrid(imageUrls, borderColor, images: images),
              ],
            ],
          ],
        ),
      );
    }

    static pw.Widget _buildImagesGrid(
        List<String> urls,
        PdfColor borderColor, {
          Map<String, pw.MemoryImage>? images,
        }) {
      if (urls.isEmpty) return pw.SizedBox();

      final widgets = <pw.Widget>[];

      for (final url in urls) {
        final memImg = images?[url];
        if (memImg == null) continue;

        widgets.add(
          pw.Column(                      // <-- حاوية لكل صورة وزرها
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Image(memImg, fit: pw.BoxFit.cover),
              ),
              pw.SizedBox(height: 4),
              pw.UrlLink(                 // <-- زر/رابط «معاينة»
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
          ),
        );
      }

      // التفاف العناصر من اليمين (RTL ⇒ start)
      return pw.Container(
        width: double.infinity,
        alignment: pw.Alignment.topRight,
        child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Wrap(
            alignment: pw.WrapAlignment.start,     // <-- البداية = يمين
            runAlignment: pw.WrapAlignment.start,  // <-- كل الأسطر تبدأ يمين
            spacing: 6,
            runSpacing: 6,
            children: widgets,
          ),
        ),
      );
    }



    static List<pw.Widget> _buildImageLinkWidgets(
        List<String> urls,
        Map<String, pw.MemoryImage> images,
        ) {
      return urls.map((url) {
        final img = images[url];
        if (img == null) return pw.SizedBox();
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Image(img, width: 80, height: 80),
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
        {Map<String, pw.MemoryImage>? images}) {
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
                pw.Image(images![imgUrl]!, width: 120, height: 120),
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

          ...requests.map((pr) {

            final List<dynamic>? items = pr['items'];

            String name;

            String qty;

            if (items != null && items.isNotEmpty) {

              name = items.map((e) => '${e['name']} (${e['quantity']})').join('، ');

              qty = '-';

            } else {

              name = pr['partName'] ?? '';

              qty = pr['quantity']?.toString() ?? '1';

            }

            final status = pr['status'] ?? '';

            final eng = pr['engineerName'] ?? '';

            final ts = (pr['requestedAt'] as Timestamp?)?.toDate();

            final dateStr = ts != null ? DateFormat('dd/MM/yy', 'ar').format(ts) : '';


            return pw.TableRow(

              children: [

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(dateStr,

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(eng,

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(status,

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(qty,

                      style: regularStyle, textAlign: pw.TextAlign.center),

                ),

                pw.Padding(

                  padding: const pw.EdgeInsets.all(8),

                  child: pw.Text(name,

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
              final imgs =
                  (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final beforeImgs =
                  (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final afterImgs =
                  (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
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
                final imgs =
                    (data['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final beforeImgs =
                    (data['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final afterImgs =
                    (data['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
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

      // Determine image size based on photo count and memory mode
      final int imgDim = lowMemory
          ? _adaptiveLowMemoryDimension(imageUrls.length)
          : _adaptiveHighQualityDimension(imageUrls.length);

      final fetchedImages = await _fetchImagesForUrls(
        imageUrls.toList(),
        onProgress: (p) => onProgress?.call(0.6 + p * 0.3),
        concurrency: fetchConcurrency,
        maxDimension: imgDim,
        quality: imgQuality,
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
                  ),
          ],
        ),
      );
      // Clear the cache after rendering the page.
      PdfImageCache.clear();

      final bytes = await pdf.save();
      onProgress?.call(1.0);
      await uploadReportPdf(bytes, fileName, token);
      return bytes;
      } finally {
        PdfImageCache.clear();
      }
    }

    static pw.Widget _buildSimpleEntriesTable(
      List<Map<String, dynamic>> entries,
      pw.TextStyle headerStyle,
      pw.TextStyle cellStyle,
      PdfColor headerColor,
      PdfColor borderColor,
      Map<String, pw.MemoryImage> images,
    ) {
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
          final imgWidgets = _buildImageLinkWidgets(imgs, images);

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
      Map<String, pw.MemoryImage> images,
    ) {
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
          final imgWidgets =
              url != null ? _buildImageLinkWidgets([url], images) : <pw.Widget>[];

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

  }

  // The isolate implementation previously used for offloading PDF generation
  // has been removed. Generating the report directly simplifies asset and
  // Firebase usage, ensuring compatibility across all platforms.