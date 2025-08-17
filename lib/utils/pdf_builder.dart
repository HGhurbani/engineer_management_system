import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a PDF using a precomputed snapshot document.
class PdfBuilder {
  static Future<Uint8List> fromSnapshot(Map<String, dynamic> snapshot, {pw.Font? arabicFont}) async {
    final pdf = pw.Document();

    final List<pw.Widget> content = [];
    final summary = snapshot['summary'] as String?;
    if (summary != null && summary.isNotEmpty) {
      content.add(pw.Text(summary, style: pw.TextStyle(fontSize: 18, font: arabicFont)));
    }

    final sections = snapshot['sections'] as List<dynamic>? ?? [];
    for (final sec in sections) {
      final title = sec['title'] as String? ?? '';
      content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: arabicFont))));
      final body = sec['body'] as String?;
      if (body != null) {
        content.add(pw.Text(body, style: pw.TextStyle(font: arabicFont)));
      }
      final images = sec['images'] as List<dynamic>? ?? [];
      for (final img in images) {
        final path = img['thumbPath'] as String?;
        if (path == null) continue;
        final data = await FirebaseStorage.instance.ref(path).getData();
        if (data != null) {
          content.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Image(pw.MemoryImage(data), width: 200)));
        }
      }
    }

    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (context) => content));
    return pdf.save();
  }
}
