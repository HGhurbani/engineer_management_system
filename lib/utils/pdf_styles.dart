import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';

class PdfStyles {
  /// Default page margins for all generated PDF documents.
  static const pw.EdgeInsets pageMargins = pw.EdgeInsets.zero;
  static pw.Widget buildHeader({
    required pw.Font font,
    required pw.MemoryImage logo,
    required String headerText,
    required DateTime now,
    required String projectName,
    required String clientName,
  }) {
    final PdfColor primaryColor = PdfColor.fromHex('#21206C');
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
              pw.Text(
                headerText,
                style: titleStyle,
                textDirection: pw.TextDirection.rtl,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'المشروع: $projectName',
                style: regularStyle,
                textDirection: pw.TextDirection.rtl,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'العميل: $clientName',
                style: regularStyle,
                textDirection: pw.TextDirection.rtl,
              ),
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

  static pw.Widget buildTable({
    required pw.Font font,
    required List<String> headers,
    required List<List<String>> data,
    PdfColor? headerColor,
    PdfColor? borderColor,
    bool isRtl = false,
  }) {
    final PdfColor primary = headerColor ?? PdfColor.fromHex('#21206C');
    final PdfColor border = borderColor ?? PdfColors.grey300;

    final pw.TextStyle headerStyle = pw.TextStyle(
      font: font,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final pw.TextStyle cellStyle =
        pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black);

    final headerCells = isRtl ? headers.reversed.toList() : headers;
    final dataRows =
        isRtl ? data.map((row) => row.reversed.toList()).toList() : data;

    final List<pw.Widget> widgets = [];

    widgets.add(
      pw.Container(
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [primary, PdfColor.fromHex('#4A4A8A')],
            begin: pw.Alignment.centerLeft,
            end: pw.Alignment.centerRight,
          ),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: headerCells
              .map((h) => pw.Expanded(
                      child: pw.Text(
                    h,
                    style: headerStyle,
                    textAlign: pw.TextAlign.center,
                    textDirection: pw.TextDirection.rtl,
                  )))
              .toList(),
        ),
      ),
    );

    bool alternate = false;
    for (final row in dataRows) {
      final rowColor = alternate ? PdfColors.grey100 : PdfColors.white;
      alternate = !alternate;
      widgets.add(
        pw.Container(
          decoration: pw.BoxDecoration(
            color: rowColor,
            border: pw.Border(bottom: pw.BorderSide(color: border)),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: row
                .map((c) => pw.Expanded(
                        child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('🔹 ',
                            style: cellStyle.copyWith(color: primary)),
                        pw.Text(
                          c,
                          style: cellStyle,
                          textAlign: pw.TextAlign.center,
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    )))
                .toList(),
          ),
        ),
      );
    }

    return pw.Column(children: widgets);
  }

  static pw.Widget buildFooter(
    pw.Context context, {
    required pw.Font font,
    List<pw.Font> fontFallback = const [],
    String? qrData,
    required String generatedByText,
  }) {
    final pw.TextStyle footerStyle = pw.TextStyle(
      font: font,
      fontSize: 10,
      fontFallback: fontFallback,
    );
    final pw.TextStyle infoStyle = pw.TextStyle(
      font: font,
      fontSize: 9,
      color: PdfColors.grey600,
      fontFallback: fontFallback,
    );

    final pageText =
        'Page ${context.pageNumber} of ${context.pagesCount}';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(pageText, style: footerStyle),
              pw.Text(generatedByText, style: footerStyle),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'BHB Contracting - +966 54 538 8835 - bhbcont@outlook.sa',
            style: infoStyle,
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
