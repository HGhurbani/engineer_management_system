import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Generates a unique token for use with Firebase Storage download URLs.
String generateReportToken() => const Uuid().v4();

/// Builds the public download URL for a PDF report using the given [fileName]
/// and [token].
String buildReportDownloadUrl(String fileName, String token) {
  final bucket = FirebaseStorage.instance.bucket;
  final encodedPath = Uri.encodeComponent('reports/\$fileName');
  return 'https://firebasestorage.googleapis.com/v0/b/\$bucket/o/\$encodedPath?alt=media&token=\$token';
}

/// Uploads [bytes] to Firebase Storage under `reports/[fileName]` with the
/// provided [token] so the download URL is stable.
Future<void> uploadReportPdf(Uint8List bytes, String fileName, String token) async {
  final ref = FirebaseStorage.instance.ref().child('reports/\$fileName');
  await ref.putData(
    bytes,
    SettableMetadata(customMetadata: {
      'firebaseStorageDownloadTokens': token,
    }),
  );
}
