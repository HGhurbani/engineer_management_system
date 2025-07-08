import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineer_management_system/utils/pdf_report_generator.dart';
import 'package:image/image.dart' as img;

void main() {
  test('resizeImageForTest shrinks large image', () {
    final image = img.Image(width: 2000, height: 2000); // Solid image
    final bytes = Uint8List.fromList(img.encodeJpg(image));
    final resized = PdfReportGenerator.resizeImageForTest(bytes);
    final decoded = img.decodeImage(resized)!;
    // Images should be resized down to the configured maximum dimension
    expect(decoded.width <= 128, true);
    expect(decoded.height <= 128, true);
  });
}
