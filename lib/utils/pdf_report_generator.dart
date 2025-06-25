import 'dart:async';

import 'dart:typed_data';


import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'package:http/http.dart' as http;

import 'package:image/image.dart' as img;

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:intl/intl.dart';

import 'package:printing/printing.dart';


import 'pdf_styles.dart';

import 'pdf_image_cache.dart';

import 'report_storage.dart';


class PdfReportGenerator {

  static pw.Font? _arabicFont;


  static Future<void> _loadArabicFont() async {

    if (_arabicFont != null) return;

    try {

      // Use a slightly bolder font for a more formal look
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Medium.ttf');

      _arabicFont = pw.Font.ttf(fontData);

    } catch (e) {

      print('Error loading Arabic font: $e');

    }

  }


  static Future<Map<String, pw.MemoryImage>> _fetchImagesForUrls(

      List<String> urls) async {

    final Map<String, pw.MemoryImage> fetched = {};

    await Future.wait(urls.map((url) async {

      if (fetched.containsKey(url)) return;

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

        }

      } catch (e) {

        print('Error fetching image from URL $url: $e');

      }

    }));

    return fetched;

  }


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

            imageUrls.addAll(imgs);

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

              imageUrls.addAll(imgs);

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


      await Future.wait(fetchTasks);

    } catch (e) {

      print('Error preparing daily report details: $e');

    }


    await _loadArabicFont();

    if (_arabicFont == null) {

      throw Exception('Arabic font not available');

    }


    final fetchedImages = await _fetchImagesForUrls(imageUrls.toList());

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


    final pdf = pw.Document();

    final fileName =

        'daily_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';

    final token = generateReportToken();

    final qrLink = buildReportDownloadUrl(fileName, token);


    final projectDataMap = projectSnapshot?.data() as Map<String, dynamic>?;

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

        fontSize: 16,

        fontFallback: commonFontFallback);

    final pw.TextStyle regularStyle = pw.TextStyle(

        font: _arabicFont, fontSize: 14, fontFallback: commonFontFallback);

    final pw.TextStyle smallGrey = pw.TextStyle(

        font: _arabicFont,

        fontSize: 10,

        color: PdfColors.grey600,

        fontFallback: commonFontFallback);


    final String headerText = isFullReport

        ? 'التقرير الشامل'

        : useRange

        ? 'التقرير التراكمي'

        : 'التقرير اليومي';


    pdf.addPage(

      pw.MultiPage(

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

                  fetchedImages,

                  i + 1,

                  headerStyle,

                  regularStyle,

                  regularStyle,

                  smallGrey,

                  PdfColors.grey400,

                  PdfColors.grey100));

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

                  fetchedImages,

                  i + 1,

                  headerStyle,

                  regularStyle,

                  regularStyle,

                  smallGrey,

                  PdfColors.grey400,

                  PdfColors.grey100));

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

            'المهندس: ${generatedBy ?? 'غير محدد'}'),

      ),

    );


    final pdfBytes = await pdf.save();

    await uploadReportPdf(pdfBytes, fileName, token);

    return pdfBytes;

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

                fontSize: 16,

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

          fontSize: 16,

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
      Map<String, pw.MemoryImage> fetchedImages,
      int index,
      pw.TextStyle subHeaderStyle,
      pw.TextStyle regularStyle,
      pw.TextStyle labelStyle,
      pw.TextStyle metaStyle,
      PdfColor borderColor,
      PdfColor lightGrey,
      ) {
    final note = entry['note'] ?? '';
    final engineer = entry['employeeName'] ?? entry['engineerName'] ?? 'مهندس';
    final ts = (entry['timestamp'] as Timestamp?)?.toDate();
    final dateStr = ts != null ? DateFormat('dd/MM/yy HH:mm', 'ar').format(ts) : '';
    final phaseName = entry['phaseName'] ?? '';
    final subName = entry['subPhaseName'];
    final imageUrls = (entry['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

    // الألوان الاحترافية
    final primaryColor = PdfColor.fromHex('#21206C');
    final lightPrimaryColor = PdfColor.fromHex('#E8E8F5');
    final darkPrimaryColor = PdfColor.fromHex('#1A1957');
    final whiteColor = PdfColors.white;
    final shadowColor = PdfColor.fromHex('#E0E0E0');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 25),
      decoration: pw.BoxDecoration(
        color: whiteColor,
        border: pw.Border.all(color: primaryColor, width: 2),
        borderRadius: pw.BorderRadius.circular(16),
        boxShadow: [
          pw.BoxShadow(
            color: shadowColor,
            blurRadius: 8,
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // رأس البطاقة الاحترافي
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [primaryColor, darkPrimaryColor],
                begin: pw.Alignment.topRight,
                end: pw.Alignment.bottomLeft,
              ),
              borderRadius: const pw.BorderRadius.only(
                topRight: pw.Radius.circular(14),
                topLeft: pw.Radius.circular(14),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // رقم الإدخال
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(25),
                  ),
                  child: pw.Text(
                    '#$index',
                    style: pw.TextStyle(
                      color: whiteColor,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
                // اسم المرحلة
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 15),
                    child: pw.Text(
                      subName != null ? '$phaseName ← $subName' : phaseName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: whiteColor,
                      ),
                      textAlign: pw.TextAlign.right,
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قسم المعلومات الأساسية
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // معلومات المهندس والتاريخ
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: lightPrimaryColor,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    children: [
                      // المهندس المسؤول
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                          ),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                engineer,
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkPrimaryColor,
                                ),
                                textAlign: pw.TextAlign.right,
                                textDirection: pw.TextDirection.rtl,
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: primaryColor,
                                borderRadius: pw.BorderRadius.circular(20),
                              ),
                              child: pw.Text(
                                'المهندس المسؤول',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: whiteColor,
                                ),
                                textDirection: pw.TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // تاريخ التسجيل
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                dateStr,
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkPrimaryColor,
                                ),
                                textAlign: pw.TextAlign.right,
                                textDirection: pw.TextDirection.rtl,
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: pw.BoxDecoration(
                                color: primaryColor,
                                borderRadius: pw.BorderRadius.circular(20),
                              ),
                              child: pw.Text(
                                'تاريخ التسجيل',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: whiteColor,
                                ),
                                textDirection: pw.TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // قسم الملاحظات
                if (note.toString().isNotEmpty) ...[
                  pw.SizedBox(height: 20),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(18),
                    decoration: pw.BoxDecoration(
                      color: whiteColor,
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: primaryColor, width: 1.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            'الملاحظات',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: whiteColor,
                            ),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          note.toString(),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: darkPrimaryColor,
                            height: 1.6,
                          ),
                          textAlign: pw.TextAlign.right,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // قسم الصور المحسن
          if (imageUrls.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // عنوان قسم الصور
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [lightPrimaryColor, whiteColor],
                        begin: pw.Alignment.topRight,
                        end: pw.Alignment.bottomLeft,
                      ),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '(${imageUrls.where((url) => fetchedImages.containsKey(url)).length})',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'الصور المرفقة',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: darkPrimaryColor,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 15),

                  // عرض الصور في شبكة احترافية
                  ...() {
                    final availableImages = imageUrls
                        .where((imageUrl) => fetchedImages.containsKey(imageUrl))
                        .toList();

                    List<pw.Widget> imageRows = [];

                    for (int i = 0; i < availableImages.length; i += 3) {
                      final rowImages = availableImages.skip(i).take(3).toList();

                      imageRows.add(
                        pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 15),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                            children: rowImages.map((imageUrl) =>
                                pw.Container(
                                  width: 155,
                                  height: 190,
                                  decoration: pw.BoxDecoration(
                                    borderRadius: pw.BorderRadius.circular(12),
                                    boxShadow: [
                                      pw.BoxShadow(
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: pw.Stack(
                                    children: [
                                      pw.ClipRRect(
                                        horizontalRadius: 12,
                                        verticalRadius: 12,
                                        child: pw.Image(
                                          fetchedImages[imageUrl]!,
                                          fit: pw.BoxFit.cover,
                                          width: 155,
                                          height: 190,
                                        ),
                                      ),
                                      pw.Positioned.fill(
                                        child: pw.Container(
                                          decoration: pw.BoxDecoration(
                                            borderRadius: pw.BorderRadius.circular(12),
                                            border: pw.Border.all(
                                              color: primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ).toList(),
                          ),
                        ),
                      );
                    }

                    return imageRows;
                  }(),

                  // رسالة الصور الإضافية
                  if (imageUrls.where((url) => fetchedImages.containsKey(url)).length > 9)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: lightPrimaryColor,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        'وعدد ${imageUrls.where((url) => fetchedImages.containsKey(url)).length - 9} صورة إضافية غير معروضة هنا...',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: darkPrimaryColor,
                          fontStyle: pw.FontStyle.italic,
                        ),
                        textAlign: pw.TextAlign.center,
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  static pw.Widget _buildTestCard(
      Map<String, dynamic> test,
      Map<String, pw.MemoryImage> fetchedImages,
      int index,
      pw.TextStyle subHeaderStyle,
      pw.TextStyle regularStyle,
      pw.TextStyle labelStyle,
      pw.TextStyle metaStyle,
      PdfColor borderColor,
      PdfColor lightGrey,
      ) {
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
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    '$section - $name',
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
                          fontSize: 12,
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
                          fontSize: 12,
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
                          'الملاحظات:',
                          style: pw.TextStyle(
                            fontSize: 12,
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
          if (imgUrl != null && fetchedImages.containsKey(imgUrl)) ...[
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
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
                textAlign: pw.TextAlign.right,
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Center(
              child: pw.Container(
                width: 200,
                height: 250,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                  boxShadow: [
                    pw.BoxShadow(
                      color: PdfColors.grey300,
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    fetchedImages[imgUrl]!,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ),
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

                  fontSize: 16,

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
  }) async {
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
            imageUrls.addAll(imgs);
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
              imageUrls.addAll(imgs);
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
    } catch (e) {
      print('Error preparing simple report details: $e');
    }

    // Fetch all images referenced in entries and tests
    final fetchedImages = await _fetchImagesForUrls(imageUrls.toList());

    await _loadArabicFont();
    if (_arabicFont == null) {
      throw Exception('Arabic font not available');
    }

    final pdf = pw.Document();
    final fileName =
        'simple_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final token = generateReportToken();

    final pw.TextStyle headerStyle = pw.TextStyle(
      font: _arabicFont,
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    final pw.TextStyle cellStyle = pw.TextStyle(
      font: _arabicFont,
      fontSize: 12,
    );

    pdf.addPage(
      pw.MultiPage(
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
                  fetchedImages,
                  headerStyle,
                  cellStyle,
                  PdfColors.grey300,
                  PdfColors.grey400,
                ),
          pw.SizedBox(height: 20),
          pw.Text('الاختبارات والفحوصات', style: headerStyle),
          pw.SizedBox(height: 10),
          dayTests.isEmpty
              ? pw.Text('لا توجد بيانات', style: cellStyle)
              : _buildSimpleTestsTable(
                  dayTests,
                  fetchedImages,
                  headerStyle,
                  cellStyle,
                  PdfColors.grey300,
                  PdfColors.grey400,
                ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await uploadReportPdf(bytes, fileName, token);
    return bytes;
  }

  static pw.Widget _buildSimpleEntriesTable(
    List<Map<String, dynamic>> entries,
    Map<String, pw.MemoryImage> images,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor headerColor,
    PdfColor borderColor,
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
        final imgWidgets = <pw.Widget>[];
        for (final url in imgs) {
          final img = images[url];
          if (img != null) {
            imgWidgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.all(2),
                child: pw.Image(img,
                    width: 120, height: 120, fit: pw.BoxFit.cover),
              ),
            );
          }
        }

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
    Map<String, pw.MemoryImage> images,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor headerColor,
    PdfColor borderColor,
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
        final img = url != null ? images[url] : null;
        final imgWidgets = <pw.Widget>[];
        if (img != null) {
          imgWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.all(2),
              child:
                  pw.Image(img, width: 120, height: 120, fit: pw.BoxFit.cover),
            ),
          );
        }

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