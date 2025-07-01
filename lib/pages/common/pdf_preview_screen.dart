import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_share2/whatsapp_share2.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_constants.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String shareText;
  final String? clientPhone;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfBytes,
    required this.fileName,
    required this.shareText,
    this.clientPhone,
  }) : super(key: key);

  Future<void> _sharePdf(BuildContext context) async {
    if (kIsWeb) {
      await Share.shareXFiles(
        [XFile.fromData(pdfBytes, name: fileName, mimeType: 'application/pdf')],
        text: shareText,
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(pdfBytes, flush: true);

    if (clientPhone != null && clientPhone!.isNotEmpty) {
      var normalized = clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalized.startsWith('0')) {
        normalized = '966${normalized.substring(1)}';
      }

      try {
        await WhatsappShare.shareFile(
          phone: normalized,
          text: shareText,
          filePath: path,
        );
        return;
      } catch (_) {
        final url = Uri.parse(
            'https://wa.me/$normalized?text=${Uri.encodeComponent(shareText)}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    }

    await Share.shareXFiles([XFile(path)], text: shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة PDF', style: TextStyle(color: Colors.white)),
        backgroundColor: AppConstants.primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              onPressed: () => _sharePdf(context),
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('مشاركة واتساب'),
            ),
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