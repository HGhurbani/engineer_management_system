import 'dart:collection';
import "package:pdf/widgets.dart" as pw;

/// Simple LRU cache for [pw.MemoryImage] objects used while generating PDFs.
///
/// Limiting the number of cached images helps keep the memory footprint
/// manageable when many images are included in a single report.
class PdfImageCache {
  PdfImageCache._();

  static final LinkedHashMap<String, pw.MemoryImage> _cache = LinkedHashMap();
  // Maximum number of images to keep in memory at any time. Reducing the
  // cache size lowers peak memory usage when a report contains many photos.
  // Fewer cached images further limit memory usage when generating
  // very large reports with hundreds of pictures.
  static const int _maxEntries = 50;

  static pw.MemoryImage? get(String url) {
    final img = _cache.remove(url);
    if (img != null) {
      // Re-insert to mark as most recently used.
      _cache[url] = img;
    }
    return img;
  }

  static void put(String url, pw.MemoryImage image) {
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = image;
  }

  static void clear() {
    _cache.clear();
  }
}
