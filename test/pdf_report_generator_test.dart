import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:engineer_management_system/utils/pdf_report_generator.dart';
import 'package:image/image.dart' as img;

void main() {
  test('resizeImageForTest shrinks large image', () async {
    final image = img.Image(width: 2000, height: 2000); // Solid image
    final bytes = Uint8List.fromList(img.encodeJpg(image));
    final resized = await PdfReportGenerator.resizeImageForTest(bytes);
    final decoded = img.decodeImage(resized)!;
    // Images should be resized down to the configured maximum dimension
    expect(decoded.width, lessThanOrEqualTo(96));
    expect(decoded.height, lessThanOrEqualTo(96));
  });
}
