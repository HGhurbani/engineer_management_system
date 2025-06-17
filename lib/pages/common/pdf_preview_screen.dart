import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_constants.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String shareText;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfBytes,
    required this.fileName,
    required this.shareText,
  }) : super(key: key);

  Future<void> _sharePdf(BuildContext context) async {
    if (kIsWeb) {
      await Share.shareXFiles([XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')], text: shareText);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes, flush: true);
      await Share.shareXFiles([XFile(path)], text: shareText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة PDF', style: TextStyle(color: Colors.white)),
        backgroundColor: AppConstants.primaryColor,
        actions: [
          TextButton.icon(
            onPressed: () => _sharePdf(context),
            icon: const Icon(Icons.whatsapp, color: Colors.white),
            label: const Text('مشاركة واتساب', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
      ),
    );
  }
}
