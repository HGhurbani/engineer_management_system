import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; // تأكد من استيراد هذه المكتبة إذا كنت تستخدم PdfGoogleFonts

import 'pdf_styles.dart'; // تأكد من وجود هذا الملف
import 'pdf_image_cache.dart'; // تأكد من وجود هذا الملف
import 'report_storage.dart'; // تأكد من وجود هذا الملف

class PdfReportGenerator {
  static pw.Font? _arabicFont;

  // دالة لتحميل الخط العربي (Tajawal-Regular.ttf)
  // هذا الخط ضروري لعرض النصوص العربية بشكل صحيح في الـ PDF.
  static Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    try {
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      print('Error loading Arabic font: $e');
      // يمكنك هنا إظهار رسالة خطأ للمستخدم أو استخدام خط احتياطي
      throw Exception('Failed to load Arabic font. Please ensure Tajawal-Regular.ttf is in assets/fonts/');
    }
  }

  // دالة لجلب الصور من الروابط وتخزينها مؤقتًا
  // هذا يساعد في تحسين أداء تحميل الصور ويمنع تكرار جلب نفس الصورة.
  static Future<Map<String, pw.MemoryImage>> _fetchImagesForUrls(
      List<String> urls) async {
    final Map<String, pw.MemoryImage> fetched = {};
    await Future.wait(urls.map((url) async {
      if (url.isEmpty || fetched.containsKey(url)) return; // تجنب الروابط الفارغة أو المكررة
      final cached = PdfImageCache.get(url);
      if (cached != null) {
        fetched[url] = cached;
        return;
      }
      try {
        final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        final contentType = response.headers['content-type'] ?? '';
        if (response.statusCode == 200 && contentType.startsWith('image/')) {
          final decoded = img.decodeImage(response.bodyBytes);
          if (decoded != null) {
            final memImg = pw.MemoryImage(response.bodyBytes);
            fetched[url] = memImg;
            PdfImageCache.put(url, memImg);
          }
        } else {
          print('Failed to fetch image or invalid content type for URL $url: Status ${response.statusCode}, Type $contentType');
        }
      } catch (e) {
        print('Error fetching image from URL $url: $e');
      }
    }));
    return fetched;
  }

  // الدالة الرئيسية لتوليد التقرير
  static Future<Uint8List> generate({
    required String projectId,
    required DocumentSnapshot? projectSnapshot,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> testsStructure,
    String? generatedBy,
    DateTime? start,
    DateTime? end,
  }) async {
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
    final Set<String> imageUrls = {}; // لجمع كل روابط الصور الفريدة

    try {
      List<Future<void>> fetchTasks = [];

      // جلب الملاحظات (entries) من المراحل والمراحل الفرعية
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
            imageUrls.addAll(imgs);
            dayEntries.add({
              ...data,
              'phaseName': phaseName,
              'subPhaseName': null, // للإشارة إلى أنها ملاحظة مرحلة رئيسية
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
              imageUrls.addAll(imgs);
              dayEntries.add({
                ...data,
                'phaseName': phaseName,
                'subPhaseName': subName, // للإشارة إلى أنها ملاحظة مرحلة فرعية
              });
            }
          }());
        }
      }

      // تحضير معلومات الاختبارات (مثل أسمائها وأقسامها)
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

      // جلب الاختبارات (tests)
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
          if (imgUrl != null && imgUrl.isNotEmpty) imageUrls.add(imgUrl);
          dayTests.add({
            ...data,
            'testId': doc.id,
            'testName': info?['name'] ?? doc.id,
            'sectionName': info?['section'] ?? 'غير محدد',
          });
        }
      }());

      // جلب طلبات المواد (part requests)
      fetchTasks.add(() async {
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
      }());

      await Future.wait(fetchTasks); // انتظار اكتمال جميع عمليات جلب البيانات
    } catch (e) {
      print('Error preparing report details: $e');
      throw Exception('Failed to prepare report data.');
    }

    // التأكد من تحميل الخط العربي
    await _loadArabicFont();
    if (_arabicFont == null) {
      throw Exception('Arabic font not available');
    }

    // جلب الصور الفعلية بعد جمع كل الروابط
    final fetchedImages = await _fetchImagesForUrls(imageUrls.toList());

    // محاولة تحميل خط الإيموجي للتعامل مع الرموز التعبيرية
    pw.Font? emojiFont;
    try {
      emojiFont = await pw.Font.ttf(await rootBundle.load('assets/fonts/NotoColorEmoji.ttf'));
    } catch (e) {
      try {
        // إذا فشل تحميل الخط المحلي، جرب تحميله من جوجل فونتس
        emojiFont = await PdfGoogleFonts.notoColorEmoji();
      } catch (e) {
        print('Error loading emoji font from assets or Google Fonts: $e');
      }
    }

    // قائمة الخطوط الاحتياطية (مهمة لدعم الإيموجي)
    final List<pw.Font> commonFontFallback = [];
    if (emojiFont != null) commonFontFallback.add(emojiFont);

    final pdf = pw.Document();
    final fileName = 'report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final token = generateReportToken(); // دالة لتوليد توكن فريد
    final qrLink = buildReportDownloadUrl(fileName, token); // دالة لبناء رابط تحميل التقرير

    final projectDataMap = projectSnapshot?.data() as Map<String, dynamic>?;
    final String projectName = projectDataMap?['name'] ?? 'مشروع غير مسمى';
    final String clientName = projectDataMap?['clientName'] ?? 'غير معروف';

    // تحميل شعار التطبيق
    final ByteData logoByteData = await rootBundle.load('assets/images/app_logo.png');
    final Uint8List logoBytes = logoByteData.buffer.asUint8List();
    final pw.MemoryImage appLogo = pw.MemoryImage(logoBytes);

    // تعريف أنماط النصوص والألوان لسهولة التعديل والتناسق
    final pw.TextStyle headerStyle = pw.TextStyle(
        font: _arabicFont,
        fontWeight: pw.FontWeight.bold,
        fontSize: 18, // حجم أكبر لرأس التقرير
        color: PdfColors.blueGrey900,
        fontFallback: commonFontFallback);
    final pw.TextStyle subHeaderStyle = pw.TextStyle(
        font: _arabicFont,
        fontWeight: pw.FontWeight.bold,
        fontSize: 16,
        color: PdfColors.blueGrey800,
        fontFallback: commonFontFallback);
    final pw.TextStyle regularStyle = pw.TextStyle(
        font: _arabicFont, fontSize: 11, color: PdfColors.black, fontFallback: commonFontFallback); // حجم خط أصغر للنصوص العادية
    final pw.TextStyle labelStyle = pw.TextStyle(
        font: _arabicFont,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey700,
        fontFallback: commonFontFallback);
    final pw.TextStyle smallGrey = pw.TextStyle(
        font: _arabicFont,
        fontSize: 9,
        color: PdfColors.grey600,
        fontFallback: commonFontFallback);

    final String reportTitle = isFullReport
        ? 'التقرير الشامل لسير العمل'
        : useRange
        ? 'التقرير التراكمي لسير العمل'
        : 'التقرير اليومي لسير العمل';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: _arabicFont, fontFallback: commonFontFallback),
          margin: PdfStyles.pageMargins,
        ),
        header: (context) => PdfStyles.buildHeader( // رأس الصفحة (من ملف pdf_styles.dart)
          font: _arabicFont!,
          logo: appLogo,
          headerText: reportTitle,
          now: now,
          projectName: projectName,
          clientName: clientName,
        ),
        build: (context) {
          final widgets = <pw.Widget>[];

          // 1. ملخص التقرير
          widgets.add(_buildSummaryCard(
              dayEntries.length,
              dayTests.length,
              dayRequests.length,
              headerStyle,
              regularStyle,
              PdfColors.blueGrey800,
              PdfColors.blueGrey50)); // خلفية أفتح للملخص
          widgets.add(pw.SizedBox(height: 30));

          // 2. الملاحظات والتحديثات
          widgets.add(_buildSectionHeader('الملاحظات والتحديثات اليومية 📝', subHeaderStyle, PdfColors.indigo600)); // لون أزرق داكن
          widgets.add(pw.SizedBox(height: 15));
          if (dayEntries.isEmpty) {
            widgets.add(_buildEmptyState('لا توجد ملاحظات مسجلة في هذه الفترة.', regularStyle, PdfColors.grey100));
          } else {
            widgets.add(_buildEntriesTable(dayEntries, fetchedImages, regularStyle, labelStyle, smallGrey, PdfColors.grey300, PdfColors.indigo100));
          }

          widgets.add(pw.SizedBox(height: 20));

          // 3. الاختبارات والفحوصات
          widgets.add(_buildSectionHeader('الاختبارات والفحوصات المحدثة ✅', subHeaderStyle, PdfColors.teal600)); // لون أخضر مزرق
          widgets.add(pw.SizedBox(height: 15));
          if (dayTests.isEmpty) {
            widgets.add(_buildEmptyState('لا توجد اختبارات محدثة في هذه الفترة.', regularStyle, PdfColors.grey100));
          } else {
            widgets.add(_buildTestsTable(dayTests, fetchedImages, regularStyle, labelStyle, smallGrey, PdfColors.grey300, PdfColors.teal100));
          }

          widgets.add(pw.SizedBox(height: 20));

          // 4. طلبات المواد والمعدات
          widgets.add(_buildSectionHeader('طلبات المواد والمعدات 📦', subHeaderStyle, PdfColors.orange600)); // لون برتقالي
          widgets.add(pw.SizedBox(height: 15));
          if (dayRequests.isEmpty) {
            widgets.add(_buildEmptyState('لا توجد طلبات مواد في هذه الفترة.', regularStyle, PdfColors.grey100));
          } else {
            widgets.add(_buildRequestsTable(dayRequests, regularStyle, labelStyle, PdfColors.grey300, PdfColors.orange100)); // خلفية خفيفة للجدول
          }

          widgets.add(pw.SizedBox(height: 20));

          // 5. ملاحظة هامة
          widgets.add(_buildImportantNotice(regularStyle));
          return widgets;
        },
        footer: (context) => PdfStyles.buildFooter( // تذييل الصفحة (من ملف pdf_styles.dart)
            context,
            font: _arabicFont!,
            fontFallback: commonFontFallback,
            qrData: qrLink,
            generatedByText:
            'تم إنشاء التقرير بواسطة: ${generatedBy ?? 'غير محدد'}'),
      ),
    );

    final pdfBytes = await pdf.save();
    // تحميل التقرير إلى التخزين (Firebase Storage أو غيره)
    await uploadReportPdf(pdfBytes, fileName, token);
    return pdfBytes;
  }

  // ----------------------------------------------------
  // دوال بناء عناصر الـ PDF
  // ----------------------------------------------------

  // بناء بطاقة الملخص في بداية التقرير
  static pw.Widget _buildSummaryCard(
      int entriesCount,
      int testsCount,
      int requestsCount,
      pw.TextStyle headerStyle,
      pw.TextStyle regularStyle,
      PdfColor primaryColor,
      PdfColor lightBgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
          color: lightBgColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: primaryColor, width: 1),
          boxShadow: [
            pw.BoxShadow(color: PdfColors.grey300, blurRadius: 5, offset: const PdfPoint(0, 3))
          ]
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('ملخص سريع لأداء المشروع', style: headerStyle),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem('الملاحظات', entriesCount.toString(), regularStyle, PdfColors.blue),
              _buildSummaryItem('الاختبارات', testsCount.toString(), regularStyle, PdfColors.green),
              _buildSummaryItem('طلبات المواد', requestsCount.toString(), regularStyle, PdfColors.orange),
            ],
          ),
        ],
      ),
    );
  }

  // بناء عنصر فردي داخل بطاقة الملخص
  static pw.Widget _buildSummaryItem(
      String label, String value, pw.TextStyle regularStyle, PdfColor itemColor) {
    return pw.Column(
      children: [
        pw.Container(
          width: 50,
          height: 50,
          decoration: pw.BoxDecoration(
              color: itemColor,
              borderRadius: pw.BorderRadius.circular(25),
              boxShadow: [
                pw.BoxShadow(color: itemColor.shade(500), blurRadius: 3, offset: const PdfPoint(0, 2))
              ]
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
        pw.Text(label, style: regularStyle.copyWith(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
      ],
    );
  }

  // بناء رأس القسم (عنوان القسم مع لون خلفية مميز)
  static pw.Widget _buildSectionHeader(
      String title, pw.TextStyle headerStyle, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(5),
          boxShadow: [
            pw.BoxShadow(color: bgColor.shade(400), blurRadius: 2, offset: const PdfPoint(0, 2))
          ]
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: _arabicFont,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // بناء حالة "لا توجد بيانات"
  static pw.Widget _buildEmptyState(
      String message, pw.TextStyle regularStyle, PdfColor lightGrey) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300)
      ),
      child: pw.Center(
        child: pw.Text(message, style: regularStyle.copyWith(color: PdfColors.grey700)),
      ),
    );
  }

  // بناء جدول الملاحظات والتحديثات
  static pw.Widget _buildEntriesTable(
      List<Map<String, dynamic>> entries,
      Map<String, pw.MemoryImage> fetchedImages,
      pw.TextStyle regularStyle,
      pw.TextStyle labelStyle,
      pw.TextStyle metaStyle,
      PdfColor borderColor,
      PdfColor headerBgColor) {
    final List<List<String>> data = [];
    final List<pw.Widget> imageWidgets = [];

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final note = entry['note'] ?? 'لا توجد ملاحظة';
      final engineer = entry['employeeName'] ?? entry['engineerName'] ?? 'غير محدد';
      final ts = (entry['timestamp'] as Timestamp?)?.toDate();
      final dateStr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'ar').format(ts) : '';
      final phaseName = entry['phaseName'] ?? 'غير معروفة';
      final subName = entry['subPhaseName'];
      final location = subName != null ? '$phaseName / $subName' : phaseName;
      final imageUrls =
          (entry['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

      data.add([
        (i + 1).toString(), // الرقم التسلسلي
        location,
        engineer,
        dateStr,
        note.toString(),
        imageUrls.isNotEmpty ? '✅ يوجد صور' : '❌ لا يوجد', // للإشارة لوجود صور
      ]);

      // إضافة الصور كعناصر منفصلة أسفل الجدول أو في صفحتها
      if (imageUrls.isNotEmpty) {
        imageWidgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 15, bottom: 5),
          child: pw.Text('صور مرفقة للملاحظة رقم ${i + 1}:', style: labelStyle),
        ));
        for (var imageUrl in imageUrls) {
          if (fetchedImages.containsKey(imageUrl)) {
            imageWidgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.ClipRRect(
                  child: pw.Image(
                    fetchedImages[imageUrl]!,
                    width: 200, // حجم أصغر للصور داخل التقرير
                    height: 250,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Table.fromTextArray(
          border: pw.TableBorder.all(color: borderColor),
          cellPadding: const pw.EdgeInsets.all(8),
          cellAlignments: {
            0: pw.Alignment.center, // الرقم
            1: pw.Alignment.centerRight, // الموقع
            2: pw.Alignment.centerRight, // المهندس
            3: pw.Alignment.center, // التاريخ
            4: pw.Alignment.centerRight, // الملاحظة
            5: pw.Alignment.center, // الصور
          },
          headerDecoration: pw.BoxDecoration(color: headerBgColor),
          headerStyle: labelStyle.copyWith(color: PdfColors.blueGrey800),
          cellStyle: regularStyle,
          rowDecoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          oddRowDecoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          headers: [
            'الرقم',
            'الموقع (المرحلة/المرحلة الفرعية)',
            'المهندس',
            'التاريخ والوقت',
            'الملاحظة',
            'مرفقات',
          ],
          data: data,
        ),
        // عرض الصور بعد الجدول (إذا كانت موجودة)
        if (imageWidgets.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey400, thickness: 1),
          pw.SizedBox(height: 10),
          ...imageWidgets,
        ],
      ],
    );
  }

  // بناء جدول الاختبارات والفحوصات
  static pw.Widget _buildTestsTable(
      List<Map<String, dynamic>> tests,
      Map<String, pw.MemoryImage> fetchedImages,
      pw.TextStyle regularStyle,
      pw.TextStyle labelStyle,
      pw.TextStyle metaStyle,
      PdfColor borderColor,
      PdfColor headerBgColor) {
    final List<List<String>> data = [];
    final List<pw.Widget> imageWidgets = [];

    for (int i = 0; i < tests.length; i++) {
      final test = tests[i];
      final note = test['note'] ?? 'لا توجد ملاحظة';
      final engineer = test['engineerName'] ?? 'غير محدد';
      final ts = (test['lastUpdatedAt'] as Timestamp?)?.toDate();
      final dateStr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'ar').format(ts) : '';
      final section = test['sectionName'] ?? 'غير محدد';
      final name = test['testName'] ?? 'غير مسمى';
      final status = test['status'] ?? 'قيد التنفيذ'; // حالة الاختبار
      final imgUrl = test['imageUrl'];

      data.add([
        (i + 1).toString(),
        '$section / $name',
        engineer,
        dateStr,
        status,
        note.toString(),
        imgUrl != null && imgUrl.isNotEmpty ? '✅ يوجد صورة' : '❌ لا يوجد',
      ]);

      if (imgUrl != null && imgUrl.isNotEmpty && fetchedImages.containsKey(imgUrl)) {
        imageWidgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 15, bottom: 5),
          child: pw.Text('صورة مرفقة للاختبار رقم ${i + 1}:', style: labelStyle),
        ));
        imageWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.ClipRRect(
              child: pw.Image(
                fetchedImages[imgUrl]!,
                width: 200,
                height: 250,
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Table.fromTextArray(
          border: pw.TableBorder.all(color: borderColor),
          cellPadding: const pw.EdgeInsets.all(8),
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.center,
          },
          headerDecoration: pw.BoxDecoration(color: headerBgColor),
          headerStyle: labelStyle.copyWith(color: PdfColors.blueGrey800),
          cellStyle: regularStyle,
          rowDecoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          oddRowDecoration: pw.BoxDecoration(
            color: PdfColors.teal50,
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          headers: [
            'الرقم',
            'اسم الاختبار / القسم',
            'المهندس',
            'تاريخ آخر تحديث',
            'الحالة',
            'ملاحظات',
            'صورة مرفقة',
          ],
          data: data,
        ),
        if (imageWidgets.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey400, thickness: 1),
          pw.SizedBox(height: 10),
          ...imageWidgets,
        ],
      ],
    );
  }

  // بناء جدول طلبات المواد والمعدات (مع تحسينات الألوان)
  static pw.Widget _buildRequestsTable(
      List<Map<String, dynamic>> requests,
      pw.TextStyle regularStyle,
      pw.TextStyle labelStyle,
      PdfColor borderColor,
      PdfColor headerBgColor) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBgColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('التاريخ',
                  style: labelStyle.copyWith(color: PdfColors.blueGrey800), textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('المهندس',
                  style: labelStyle.copyWith(color: PdfColors.blueGrey800), textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('الحالة',
                  style: labelStyle.copyWith(color: PdfColors.blueGrey800), textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('الكمية',
                  style: labelStyle.copyWith(color: PdfColors.blueGrey800), textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('اسم المادة',
                  style: labelStyle.copyWith(color: PdfColors.blueGrey800), textAlign: pw.TextAlign.center),
            ),
          ],
        ),
        ...requests.map((pr) {
          final List<dynamic>? items = pr['items'];
          String name;
          String qty;
          if (items != null && items.isNotEmpty) {
            name = items.map((e) => '${e['name']} (${e['quantity']})').join('، ');
            qty = '-'; // إذا كانت متعددة، لا نضع كمية إجمالية هنا
          } else {
            name = pr['partName'] ?? 'غير محدد';
            qty = pr['quantity']?.toString() ?? '1';
          }
          final status = pr['status'] ?? 'قيد الانتظار';
          final eng = pr['engineerName'] ?? 'غير محدد';
          final ts = (pr['requestedAt'] as Timestamp?)?.toDate();
          final dateStr = ts != null ? DateFormat('dd/MM/yy', 'ar').format(ts) : '';

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: requests.indexOf(pr) % 2 == 0 ? PdfColors.white : PdfColors.orange50, // تناوب الألوان للصفوف
              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.5)),
            ),
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

  // بناء ملاحظة هامة (في نهاية التقرير)
  static pw.Widget _buildImportantNotice(pw.TextStyle regularStyle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF3E0'), // خلفية برتقالية فاتحة جداً
        border: pw.Border.all(color: PdfColor.fromHex('#FF9800'), width: 2), // حدود برتقالية
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'ملاحظة هامة: في حال مضى 24 ساعة على إنشاء هذا التقرير، يعتبر مكتملًا وغير قابل للتعديل.',
              style: pw.TextStyle(
                font: _arabicFont,
                color: PdfColor.fromHex('#E65100'), // نص برتقالي داكن
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
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
              color: PdfColor.fromHex('#FF9800'), // دائرة برتقالية
              borderRadius: pw.BorderRadius.circular(15),
            ),
            child: pw.Center(
              child: pw.Text(
                '!',
                style: pw.TextStyle(
                  font: _arabicFont,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}