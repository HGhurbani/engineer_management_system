import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'instant_image_cache.dart';
import 'advanced_cache_manager.dart';
import 'report_snapshot_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// مولد التقارير الفوري المحسن
class InstantPdfGenerator {
  
  /// إنشاء تقرير فوري باستخدام الكاش الذكي
  static Future<PdfReportResult> generateInstantReport({
    required String projectId,
    required Map<String, dynamic>? projectData,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> testsStructure,
    String? generatedBy,
    String? generatedByRole,
    DateTime? start,
    DateTime? end,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatusUpdate,
  }) async {
    
    onProgress?.call(0.0);
    onStatusUpdate?.call('بدء إنشاء التقرير الفوري...');
    
    try {
      // 1. محاولة الحصول على تقرير جاهز من الكاش
      final cachedReport = await _getCachedReport(projectId, start, end);
      if (cachedReport != null) {
        onStatusUpdate?.call('تم العثور على التقرير في الكاش');
        onProgress?.call(1.0);
        return PdfReportResult(bytes: cachedReport);
      }
      
      onProgress?.call(0.1);
      
      // 2. تجميع URLs الصور بسرعة
      onStatusUpdate?.call('تجميع معلومات الصور...');
      final imageUrls = await _collectImageUrls(phases, start, end);
      onProgress?.call(0.2);
      
      // 3. الحصول على الصور بشكل فوري من الكاش
      onStatusUpdate?.call('تحضير الصور...');
      final processedImages = await InstantImageCache.getImagesInstantly(
        imageUrls: imageUrls,
        onProgress: (p) => onProgress?.call(0.2 + p * 0.5),
        onStatusUpdate: onStatusUpdate,
      );
      
      onProgress?.call(0.7);
      
      // 4. إنشاء PDF بسرعة (بدون انتظار معالجة الصور)
      onStatusUpdate?.call('إنشاء ملف PDF...');
      final pdfBytes = await _generatePdfQuickly(
        projectData: projectData,
        phases: phases,
        testsStructure: testsStructure,
        processedImages: processedImages,
        generatedBy: generatedBy,
        generatedByRole: generatedByRole,
        start: start,
        end: end,
      );
      
      onProgress?.call(0.9);
      
      // 5. حفظ التقرير في الكاش للمرات القادمة
      await _cacheReport(projectId, start, end, pdfBytes);
      
      onProgress?.call(1.0);
      onStatusUpdate?.call('تم إنشاء التقرير بنجاح');
      
      return PdfReportResult(bytes: pdfBytes);
      
    } catch (e) {
      onStatusUpdate?.call('خطأ في إنشاء التقرير: $e');
      rethrow;
    }
  }
  
  /// تجميع URLs الصور بسرعة
  static Future<List<String>> _collectImageUrls(
    List<Map<String, dynamic>> phases,
    DateTime? start,
    DateTime? end,
  ) async {
    final Set<String> imageUrls = {};
    
    for (final phase in phases) {
      final subPhases = phase['subPhases'] as List? ?? [];
      
      for (final subPhase in subPhases) {
        final entries = subPhase['entries'] as List? ?? [];
        
        for (final entry in entries) {
          // فلترة الإدخالات حسب التاريخ إذا لزم الأمر
          if (start != null && end != null) {
            final entryDate = (entry['date'] as Timestamp?)?.toDate();
            if (entryDate == null || 
                entryDate.isBefore(start) || 
                entryDate.isAfter(end)) {
              continue;
            }
          }
          
          // تجميع URLs الصور - دعم الهياكل القديمة والجديدة
          final images = entry['images'] as List? ?? [];
          final imageUrlsList = entry['imageUrls'] as List? ?? 
                               entry['otherImages'] as List? ?? 
                               entry['otherImageUrls'] as List? ?? [];
          final beforeUrls = entry['beforeImageUrls'] as List? ?? 
                            entry['beforeImages'] as List? ?? [];
          final afterUrls = entry['afterImageUrls'] as List? ?? 
                           entry['afterImages'] as List? ?? [];
          
          // معالجة الصور من الحقل images القديم
          for (final image in images) {
            if (image is String && image.isNotEmpty) {
              imageUrls.add(image);
            } else if (image is Map && image['url'] != null) {
              imageUrls.add(image['url'].toString());
            }
          }
          
          // معالجة الصور من الحقول الجديدة
          for (final url in imageUrlsList) {
            if (url is String && url.isNotEmpty) {
              imageUrls.add(url);
            }
          }
          for (final url in beforeUrls) {
            if (url is String && url.isNotEmpty) {
              imageUrls.add(url);
            }
          }
          for (final url in afterUrls) {
            if (url is String && url.isNotEmpty) {
              imageUrls.add(url);
            }
          }
        }
      }
    }
    
    return imageUrls.toList();
  }
  
  /// إنشاء PDF بسرعة باستخدام الصور المعالجة مسبقاً
  static Future<Uint8List> _generatePdfQuickly({
    required Map<String, dynamic>? projectData,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> testsStructure,
    required Map<String, String> processedImages,
    String? generatedBy,
    String? generatedByRole,
    DateTime? start,
    DateTime? end,
  }) async {
    
    // تحميل الخط العربي مرة واحدة فقط
    final arabicFont = await _loadArabicFontCached();
    
    final pdf = pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_5,
    );
    
    // إنشاء الصفحات بشكل متوازي
    final pages = await _generatePagesParallel(
      projectData: projectData,
      phases: phases,
      testsStructure: testsStructure,
      processedImages: processedImages,
      arabicFont: arabicFont,
      start: start,
      end: end,
    );
    
    // إضافة الصفحات للـ PDF
    for (final page in pages) {
      pdf.addPage(page);
    }
    
    return await pdf.save();
  }
  
  /// إنشاء الصفحات بشكل متوازي
  static Future<List<pw.Page>> _generatePagesParallel({
    required Map<String, dynamic>? projectData,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> testsStructure,
    required Map<String, String> processedImages,
    required pw.Font arabicFont,
    DateTime? start,
    DateTime? end,
  }) async {
    
    final List<pw.Page> pages = [];
    
    // صفحة الغلاف
    pages.add(await _generateCoverPage(projectData, arabicFont));
    
    // صفحات المراحل (معالجة متوازية)
    final phasePages = await _generatePhasePagesParallel(
      phases, 
      processedImages, 
      arabicFont,
      start,
      end,
    );
    pages.addAll(phasePages);
    
    // صفحات الاختبارات
    final testPages = await _generateTestPages(testsStructure, arabicFont);
    pages.addAll(testPages);
    
    return pages;
  }
  
  /// إنشاء صفحات المراحل بشكل متوازي
  static Future<List<pw.Page>> _generatePhasePagesParallel(
    List<Map<String, dynamic>> phases,
    Map<String, String> processedImages,
    pw.Font arabicFont,
    DateTime? start,
    DateTime? end,
  ) async {
    
    final List<Future<List<pw.Page>>> phaseTasks = [];
    
    for (final phase in phases) {
      phaseTasks.add(_generateSinglePhasePages(
        phase, 
        processedImages, 
        arabicFont,
        start,
        end,
      ));
    }
    
    // انتظار انتهاء جميع المراحل
    final phaseResults = await Future.wait(phaseTasks);
    
    // دمج النتائج
    final List<pw.Page> allPages = [];
    for (final pages in phaseResults) {
      allPages.addAll(pages);
    }
    
    return allPages;
  }
  
  /// إنشاء صفحات مرحلة واحدة
  static Future<List<pw.Page>> _generateSinglePhasePages(
    Map<String, dynamic> phase,
    Map<String, String> processedImages,
    pw.Font arabicFont,
    DateTime? start,
    DateTime? end,
  ) async {
    
    final List<pw.Page> pages = [];
    final subPhases = phase['subPhases'] as List? ?? [];
    
    for (final subPhase in subPhases) {
      final entries = subPhase['entries'] as List? ?? [];
      final List<pw.Widget> pageContent = [];
      
      // عنوان المرحلة الفرعية
      pageContent.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            subPhase['name'] ?? 'مرحلة فرعية',
            style: pw.TextStyle(
              font: arabicFont,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      );
      
      // معالجة الإدخالات
      for (final entry in entries) {
        // فلترة حسب التاريخ
        if (start != null && end != null) {
          final entryDate = (entry['date'] as Timestamp?)?.toDate();
          if (entryDate == null || 
              entryDate.isBefore(start) || 
              entryDate.isAfter(end)) {
            continue;
          }
        }
        
        // إضافة محتوى الإدخال
        pageContent.addAll(await _generateEntryContent(
          entry, 
          processedImages, 
          arabicFont
        ));
        
        // فاصل بين الإدخالات
        pageContent.add(pw.SizedBox(height: 10));
      }
      
      // إنشاء صفحة إذا كان هناك محتوى
      if (pageContent.length > 1) {
        pages.add(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: pageContent,
            ),
          ),
        );
      }
    }
    
    return pages;
  }
  
  /// إنشاء محتوى إدخال واحد
  static Future<List<pw.Widget>> _generateEntryContent(
    Map<String, dynamic> entry,
    Map<String, String> processedImages,
    pw.Font arabicFont,
  ) async {
    
    final List<pw.Widget> content = [];
    
    // النص
    if (entry['text'] != null && entry['text'].toString().isNotEmpty) {
      content.add(
        pw.Text(
          entry['text'].toString(),
          style: pw.TextStyle(font: arabicFont, fontSize: 12),
          textDirection: pw.TextDirection.rtl,
        ),
      );
    }
    
    // الصور (معالجة سريعة)
    final images = entry['images'] as List? ?? [];
    if (images.isNotEmpty) {
      final imageWidgets = await _generateImageWidgets(
        images, 
        processedImages, 
        arabicFont
      );
      content.addAll(imageWidgets);
    }
    
    return content;
  }
  
  /// إنشاء عناصر الصور بسرعة
  static Future<List<pw.Widget>> _generateImageWidgets(
    List images,
    Map<String, String> processedImages,
    pw.Font arabicFont,
  ) async {
    
    final List<pw.Widget> widgets = [];
    final List<pw.Widget> imageRow = [];
    
    for (final image in images) {
      String? imageUrl;
      
      if (image is String) {
        imageUrl = image;
      } else if (image is Map && image['url'] != null) {
        imageUrl = image['url'].toString();
      }
      
      if (imageUrl != null && processedImages.containsKey(imageUrl)) {
        final imagePath = processedImages[imageUrl]!;
        
        try {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final memoryImage = pw.MemoryImage(imageBytes);
            
            imageRow.add(
              pw.Container(
                width: 80,
                height: 80,
                margin: const pw.EdgeInsets.all(2),
                child: pw.Image(memoryImage, fit: pw.BoxFit.cover),
              ),
            );
            
            // إضافة صف جديد كل 4 صور
            if (imageRow.length >= 4) {
              widgets.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: List.from(imageRow),
                ),
              );
              imageRow.clear();
            }
          }
        } catch (e) {
          print('Error loading image: $e');
        }
      }
    }
    
    // إضافة الصور المتبقية
    if (imageRow.isNotEmpty) {
      widgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: List.from(imageRow),
        ),
      );
    }
    
    return widgets;
  }
  
  // باقي الوظائف المساعدة...
  static Future<pw.Font> _loadArabicFontCached() async {
    // تحميل الخط مع كاش
    // ... implementation
    throw UnimplementedError();
  }
  
  static Future<pw.Page> _generateCoverPage(Map<String, dynamic>? projectData, pw.Font arabicFont) async {
    // ... implementation
    throw UnimplementedError();
  }
  
  static Future<List<pw.Page>> _generateTestPages(List<Map<String, dynamic>> testsStructure, pw.Font arabicFont) async {
    // ... implementation
    return [];
  }
  
  static Future<Uint8List?> _getCachedReport(String projectId, DateTime? start, DateTime? end) async {
    // ... implementation
    return null;
  }
  
  static Future<void> _cacheReport(String projectId, DateTime? start, DateTime? end, Uint8List pdfBytes) async {
    // ... implementation
  }
}

class PdfReportResult {
  final Uint8List bytes;
  final String? downloadUrl;
  
  PdfReportResult({required this.bytes, this.downloadUrl});
}
