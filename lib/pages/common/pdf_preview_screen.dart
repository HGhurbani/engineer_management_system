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

  const PdfPreviewScreen({
    Key? key,
    required this.pdfBytes,
    required this.fileName,
    required this.shareText,
    this.clientPhone, // This already exists
    this.shareLink,
  }) : super(key: key);

  Future<void> _sharePdf(BuildContext context) async {
    if (shareLink != null) {
      final text = '$shareText\n$shareLink';
      if (kIsWeb) {
        if (clientPhone != null && clientPhone!.isNotEmpty) {
          String normalizedPhone =
              clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
          if (normalizedPhone.startsWith('0')) {
            normalizedPhone = '966${normalizedPhone.substring(1)}';
          }
          final Uri whatsappWebUri = Uri.parse(
            'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(text)}',
          );
          await launchUrl(whatsappWebUri, webOnlyWindowName: '_blank');
        } else {
          await Share.share(text);
        }
      } else {
        if (clientPhone != null && clientPhone!.isNotEmpty) {
          String normalizedPhone =
              clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
          if (normalizedPhone.startsWith('0')) {
            normalizedPhone = '966${normalizedPhone.substring(1)}';
          }
          final Uri whatsappUri = Uri.parse(
            'whatsapp://send?phone=$normalizedPhone&text=${Uri.encodeComponent(text)}',
          );
          if (await canLaunchUrl(whatsappUri)) {
            await launchUrl(whatsappUri,
                mode: LaunchMode.externalApplication);
          } else {
            await Share.share(text);
          }
        } else {
          await Share.share(text);
        }
      }
      return;
    }

    if (kIsWeb) {
      // On web, trigger PDF download then open WhatsApp Web in a new tab.
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (clientPhone != null && clientPhone!.isNotEmpty) {
        String normalizedPhone = clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalizedPhone.startsWith('0')) {
          normalizedPhone = '966${normalizedPhone.substring(1)}';
        }
        final Uri whatsappWebUri = Uri.parse(
          'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(shareText)}',
        );
        await launchUrl(whatsappWebUri, webOnlyWindowName: '_blank');
      }
    } else {
      // Save the PDF file temporarily on mobile/desktop platforms.
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes, flush: true);

      if (clientPhone != null && clientPhone!.isNotEmpty) {
        // Normalize phone number: remove non-digits and add country code if missing
        String normalizedPhone =
            clientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalizedPhone.startsWith('0')) {
          normalizedPhone = '966${normalizedPhone.substring(1)}';
        }

        final Uri whatsappUri = Uri.parse(
          'whatsapp://send?phone=$normalizedPhone&text=${Uri.encodeComponent(shareText)}',
        );

        if (await canLaunchUrl(whatsappUri)) {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        } else {
          await Share.shareXFiles(
            [XFile(path)],
            text: shareText,
            subject: 'تقرير المشروع',
          );
        }
      } else {
        await Share.shareXFiles(
          [XFile(path)],
          text: shareText,
          subject: 'تقرير المشروع',
        );
      }
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