import "package:pdf/widgets.dart" as pw;
class PdfImageCache {
  PdfImageCache._();

  static final Map<String, pw.MemoryImage> _cache = {};

  static pw.MemoryImage? get(String url) => _cache[url];

  static void put(String url, pw.MemoryImage image) {
    _cache[url] = image;
  }

  static void clear() {
    _cache.clear();
  }
}
