import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfStyles {
  static pw.Widget buildHeader({
    required pw.Font font,
    required pw.MemoryImage logo,
    required String headerText,
    required DateTime now,
    required String projectName,
    required String clientName,
  }) {
    final PdfColor primaryColor = PdfColor.fromHex('#1B4D3E');
    final PdfColor lightGrey = PdfColor.fromHex('#F5F5F5');
    final pw.TextStyle titleStyle = pw.TextStyle(
      font: font,
      fontWeight: pw.FontWeight.bold,
      fontSize: 24,
      color: primaryColor,
    );
    final pw.TextStyle regularStyle =
        pw.TextStyle(font: font, fontSize: 12, color: PdfColors.black);

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(headerText, style: titleStyle),
              pw.SizedBox(height: 5),
              pw.Text('المشروع: $projectName', style: regularStyle),
              pw.SizedBox(height: 2),
              pw.Text('العميل: $clientName', style: regularStyle),
              pw.SizedBox(height: 5),
              pw.Text(
                'تاريخ الإنشاء: ${DateFormat('dd-MM-yyyy HH:mm').format(now)}',
                textDirection: pw.TextDirection.rtl,
                style: regularStyle.copyWith(color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Image(logo, width: 70, height: 70),
        ],
      ),
    );
  }

  static pw.Widget buildFooter(pw.Context context,
      {required pw.Font font, List<pw.Font> fontFallback = const []}) {
    return pw.Container(
      height: 80,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColor.fromHex('#1B4D3E'), PdfColor.fromHex('#2E8B57')],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'صفحة ${context.pageNumber} من ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: font,
                        color: PdfColors.white,
                        fontSize: 10,
                        fontFallback: fontFallback,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'تم إنشاء هذا التقرير آلياً',
                      style: pw.TextStyle(
                        font: font,
                        color: PdfColor.fromHex('#F5C842'),
                        fontSize: 8,
                        fontFallback: fontFallback,
                      ),
                    ),
                  ],
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'المملكة العربية السعودية - الأحساء - سجل تجاري رقم: ٢٢٠١٤٩٢٠٥٠',
                            style: pw.TextStyle(
                              font: font,
                              color: PdfColors.white,
                              fontSize: 9,
                              fontFallback: fontFallback,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 12,
                            height: 12,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#F5C842'),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Center(
                              child: pw.Text('📍',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontFallback: fontFallback)),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'الرقم الضريبي: ٣٠٠٤٧١٣٦٥٠٠٠٠٣',
                            style: pw.TextStyle(
                              font: font,
                              color: PdfColor.fromHex('#F5C842'),
                              fontSize: 9,
                              fontFallback: fontFallback,
                            ),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            '+966 54 538 8835',
                            style: pw.TextStyle(
                              font: font,
                              color: PdfColors.white,
                              fontSize: 9,
                              fontFallback: fontFallback,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 12,
                            height: 12,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#F5C842'),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Center(
                              child: pw.Text('📞',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontFallback: fontFallback)),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'bhbcont@outlook.sa',
                        style: pw.TextStyle(
                          font: font,
                          color: PdfColor.fromHex('#F5C842'),
                          fontSize: 9,
                          fontFallback: fontFallback,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 40,
                  height: 40,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'QR',
                      style: pw.TextStyle(
                        font: font,
                        color: PdfColor.fromHex('#1B4D3E'),
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        fontFallback: fontFallback,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
