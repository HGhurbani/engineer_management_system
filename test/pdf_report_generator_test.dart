import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineer_management_system/utils/pdf_report_generator.dart';
import 'package:image/image.dart' as img;

void main() {
  test('resizeImageForTest downscales large images', () async {
    final image = img.Image(width: 2000, height: 2000); // Solid image
    final bytes = Uint8List.fromList(img.encodeJpg(image));
    final resized =
        await PdfReportGenerator.resizeImageForTest(bytes, maxDimension: 256);
    final decoded = img.decodeImage(resized)!;
    // Images should be resized to at most 256 pixels on the longest side
    expect(decoded.width <= 256, isTrue);
    expect(decoded.height <= 256, isTrue);
  });
}
