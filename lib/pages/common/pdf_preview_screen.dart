// lib/pages/common/pdf_preview_screen.dart
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // Import this if not already present

import '../../theme/app_constants.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String shareText;
  final String? clientPhone; // This already exists

  const PdfPreviewScreen({
    Key? key,
    required this.pdfBytes,
    required this.fileName,
    required this.shareText,
    this.clientPhone, // This already exists
  }) : super(key: key);

  Future<void> _sharePdf(BuildContext context) async {
    // Save the PDF file temporarily
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(pdfBytes, flush: true);

    if (clientPhone != null && clientPhone!.isNotEmpty) {
      // Normalize phone number: remove non-digits and add country code if missing
      String normalizedPhone = clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalizedPhone.startsWith('0')) {
        // Assuming Saudi Arabia for '0' prefix, replace with '966'
        normalizedPhone = '966${normalizedPhone.substring(1)}';
      }

      // Construct WhatsApp URL
      final Uri whatsappUri = Uri.parse("whatsapp://send?phone=$normalizedPhone&text=${Uri.encodeComponent(shareText)}");

      // Try to launch WhatsApp directly with the text and file
      // Note: Sending files via WhatsApp API directly is complex.
      // For simplicity, this will open WhatsApp to the contact with pre-filled text.
      // The user would then manually attach the PDF from their device.
      // To send the PDF directly, you'd need WhatsApp Business API or similar integration,
      // which is beyond direct client-side URL launching.
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to generic share if WhatsApp direct link fails or is not installed
        await Share.shareXFiles([XFile(path)], text: shareText, subject: "تقرير المشروع");
      }
    } else {
      // If no client phone is available, use generic sharing
      await Share.shareXFiles([XFile(path)], text: shareText, subject: "تقرير المشروع");
    }
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