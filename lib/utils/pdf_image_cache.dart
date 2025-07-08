import 'dart:collection';
import "package:pdf/widgets.dart" as pw;

/// Simple LRU cache for [pw.MemoryImage] objects used while generating PDFs.
///
/// Limiting the number of cached images helps keep the memory footprint
/// manageable when many images are included in a single report.
class PdfImageCache {
  PdfImageCache._();

  static final LinkedHashMap<String, pw.MemoryImage> _cache = LinkedHashMap();
  // Maximum number of images to keep in memory at any time.
  static const int _maxEntries = 100;

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
      // Remove the oldest entry (first item in the map).
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = image;
  }

  static void clear() {
    _cache.clear();
  }
}
