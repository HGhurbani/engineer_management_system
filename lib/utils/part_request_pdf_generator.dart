import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pdf_styles.dart';

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

  static Future<Uint8List> generate(Map<String, dynamic> data) async {
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

    final List<List<String>> tableData = [];
    final List<dynamic>? items = data['items'];
    if (items != null && items.isNotEmpty) {
      for (var item in items) {
        tableData.add([
          item['name']?.toString() ?? '',
          item['quantity']?.toString() ?? ''
        ]);
      }
    } else {
      tableData.add([
        data['partName']?.toString() ?? '',
        data['quantity']?.toString() ?? ''
      ]);
    }

    final pdf = pw.Document();
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
          pw.Text('المهندس: $engineerName',
              style: pw.TextStyle(
                  font: _arabicFont,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14)),
          pw.Text('حالة الطلب: $status',
              style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
          pw.Text('تاريخ الطلب: $formattedDate',
              style: pw.TextStyle(font: _arabicFont, fontSize: 12)),
          pw.SizedBox(height: 10),
          PdfStyles.buildTable(
            font: _arabicFont!,
            headers: ['اسم المادة', 'الكمية'],
            data: tableData,
            isRtl: true,
          ),
        ],
        footer: (context) => PdfStyles.buildFooter(
          context,
          font: _arabicFont!,
          generatedByText: 'المهندس: $engineerName',
        ),
      ),
    );

    return pdf.save();
  }
}
