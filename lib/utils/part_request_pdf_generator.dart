import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:http/http.dart' as http;

import 'pdf_styles.dart';
import 'pdf_report_generator.dart';
import 'pdf_image_cache.dart';

class PartRequestPdfGenerator {
  static pw.Font? _arabicFont;

  static Future<void> _loadArabicFont() async {
    if (_arabicFont != null) return;
    try {
      final data = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _arabicFont = pw.Font.ttf(data);
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
        try {
          final head =
              await http.head(Uri.parse(url)).timeout(const Duration(seconds: 30));
          final lenStr = head.headers['content-length'];
          final len = lenStr != null ? int.tryParse(lenStr) : null;
          if (len != null && len > PdfReportGenerator.maxImageFileSize) {
            return;
          }
        } catch (_) {}

        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
        final contentType = response.headers['content-type'] ?? '';
        if (response.statusCode == 200 && contentType.startsWith('image/')) {
          final resized = await PdfReportGenerator.resizeImageForTest(
              response.bodyBytes,
              maxDimension: 200);
          final memImg = pw.MemoryImage(resized);
          fetched[url] = memImg;
          PdfImageCache.put(url, memImg);
        }
      } on TimeoutException catch (_) {
        print('Timeout fetching image from URL $url');
      } catch (e) {
        print('Error fetching image from URL $url: $e');
      }
    }));
    return fetched;
  }

  static Future<Uint8List> generate(Map<String, dynamic> data,
      {String generatedByRole = 'المهندس'}) async {
    await _loadArabicFont();
    if (_arabicFont == null) {
      throw Exception('Arabic font not available');
    }

    final ByteData logoData = await rootBundle.load('assets/images/app_logo.png');
    final pw.MemoryImage appLogo = pw.MemoryImage(logoData.buffer.asUint8List());

    final String projectName = data['projectName'] ?? 'غير محدد';
    final String engineerName = data['engineerName'] ?? 'غير محدد';
    final String status = data['status'] ?? 'غير معروف';
    final DateTime? requestedAt =
        (data['requestedAt'] as Timestamp?)?.toDate();
    final String formattedDate = requestedAt != null
        ? DateFormat('yyyy/MM/dd – HH:mm', 'ar').format(requestedAt)
        : 'غير معروف';

    final List<Map<String, String>> rows = [];
    final List<String> imageUrls = [];
    final List<dynamic>? items = data['items'];
    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        final name = item['name']?.toString() ?? '';
        final qty = item['quantity']?.toString() ?? '';
        final img = item['imageUrl']?.toString() ?? '';
        rows.add({'name': name, 'qty': qty, 'img': img});
        if (img.isNotEmpty) imageUrls.add(img);
      }
    } else {
      rows.add({
        'name': data['partName']?.toString() ?? '',
        'qty': data['quantity']?.toString() ?? '',
        'img': ''
      });
    }

    final images = await _fetchImagesForUrls(imageUrls);

    // Enable compression to keep the generated document lightweight
    final pdf = pw.Document(compress: true);
    pdf.addPage(
      pw.MultiPage(
        maxPages: 10000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: _arabicFont!,
            bold: _arabicFont!,
            italic: _arabicFont!,
            boldItalic: _arabicFont!,
          ),
          margin: PdfStyles.pageMargins,
        ),
        header: (context) => PdfStyles.buildHeader(
          font: _arabicFont!,
          logo: appLogo,
          headerText: 'تقرير طلب مواد',
          now: DateTime.now(),
          projectName: projectName,
          clientName: 'غير محدد',
        ),
        build: (context) => [
          pw.Text('$generatedByRole: $engineerName',
              style: pw.TextStyle(
                  font: _arabicFont,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14)),
          pw.Text('حالة الطلب: $status',
              style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
          pw.Text('تاريخ الطلب: $formattedDate',
              style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
          pw.SizedBox(height: 10),
          _buildImageTable(rows, images),
        ],
        footer: (context) => PdfStyles.buildFooter(
          context,
          font: _arabicFont!,
          generatedByText: '$generatedByRole: $engineerName',
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildImageTable(
      List<Map<String, String>> rows, Map<String, pw.MemoryImage> images) {
    final headerStyle = pw.TextStyle(
      font: _arabicFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(font: _arabicFont, fontSize: 11);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {2: pw.FixedColumnWidth(60)},
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#21206C')),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('الكمية', style: headerStyle, textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('اسم المادة', style: headerStyle, textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('الصورة', style: headerStyle, textAlign: pw.TextAlign.center),
            ),
          ],
        ),
        ...List.generate(rows.length, (index) {
          final row = rows[index];
          final alt = index.isOdd;
          final bg = alt ? PdfColors.grey100 : PdfColors.white;
          final imgUrl = row['img'] ?? '';
          final img = images[imgUrl];
          final imgWidget = img != null
              ? pw.Image(img, width: 40, height: 40, fit: pw.BoxFit.cover)
              : pw.Text('لا يوجد', style: cellStyle, textAlign: pw.TextAlign.center);
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(row['qty'] ?? '', style: cellStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(row['name'] ?? '', style: cellStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Center(child: imgWidget),
              ),
            ],
          );
        }),
      ],
    );
  }
}
