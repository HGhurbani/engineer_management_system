// lib/pages/common/pdf_preview_screen.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:engineer_management_system/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

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
  final String? shareLink;
  final String? imageUrl;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfBytes,
    required this.fileName,
    required this.shareText,
    this.clientPhone, // This already exists
    this.shareLink,
    this.imageUrl,
  }) : super(key: key);

  Future<void> _sharePdf(BuildContext context) async {
    final text = shareLink != null ? '$shareText\n$shareLink' : shareText;

    if (kIsWeb) {
      if (shareLink != null) {
        final linkOnly = shareLink!;
        if (clientPhone != null && clientPhone!.isNotEmpty) {
          String normalizedPhone =
              clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
          if (normalizedPhone.startsWith('0')) {
            normalizedPhone = '966${normalizedPhone.substring(1)}';
          }
          final Uri whatsappWebUri = Uri.parse(
            'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(linkOnly)}',
          );
          await launchUrl(whatsappWebUri, webOnlyWindowName: '_blank');
        } else {
          await Share.share(linkOnly);
        }
      } else {
        // Fallback to downloading the PDF if no link is provided.
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      }
      return;
    }

    // Save the PDF file temporarily on non-web platforms and share it.
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(pdfBytes, flush: true);

    await Share.shareXFiles(
      [XFile(path)],
      text: text,
      subject: 'تقرير المشروع',
    );
  }

  Future<void> _viewImageDialog(BuildContext context, String imageUrl) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.all(10),
        content: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(
                        color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => const Center(
                child: Icon(Icons.error_outline,
                    color: AppConstants.errorColor, size: 50)),
          ),
        ),
        actions: [
          TextButton(
            style:
                TextButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5)),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          )
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة PDF', style: TextStyle(color: Colors.white)),
        backgroundColor: AppConstants.primaryColor,
        actions: [
          if (imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => _viewImageDialog(context, imageUrl!),
                icon: const Icon(Icons.image_outlined, color: Colors.white),
                label: const Text('عرض الصورة'),
              ),
            ),
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