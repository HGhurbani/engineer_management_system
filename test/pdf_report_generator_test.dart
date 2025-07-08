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
    expect(decoded.width <= 1024, true);
    expect(decoded.height <= 1024, true);
  });
}
