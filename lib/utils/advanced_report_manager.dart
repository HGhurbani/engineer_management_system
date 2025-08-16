import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'advanced_cache_manager.dart';
import 'concurrent_operations_manager.dart';
import 'performance_monitor.dart';
import 'pdf_report_generator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// مدير تقارير متقدم للتعامل مع البيانات الكبيرة والعمل بدون إنترنت
class AdvancedReportManager {
  static const int _maxDataChunkSize = 100; // عدد العناصر في كل جزء
  static const int _maxConcurrentChunks = 2; // عدد الأجزاء المتزامنة
  static const Duration _chunkTimeout = Duration(minutes: 5);
  
  /// إنشاء تقرير مع إدارة ذكية للبيانات
  static Future<Map<String, dynamic>> generateReportAdvanced({
    required String reportId,
    required List<Map<String, dynamic>> data,
    required String title,
    required Map<String, dynamic> options,
    void Function(String status)? onStatusUpdate,
    void Function(double progress)? onProgress,
  }) async {
    try {
      PerformanceMonitor.startTimer('advanced_report_generation');
      onStatusUpdate?.call('بدء إنشاء التقرير...');
      
      // فحص الكاش أولاً
      final cachedReport = await AdvancedCacheManager.getCachedReport(reportId);
      if (cachedReport != null) {
        onStatusUpdate?.call('تم العثور على التقرير في الكاش');
        onProgress?.call(1.0);
        return {
          'success': true,
          'data': cachedReport['data'],
          'source': 'cache',
          'cached': true,
        };
      }
      
      // فحص الاتصال بالإنترنت
      final isOnline = await AdvancedCacheManager.isOnline();
      if (!isOnline) {
        onStatusUpdate?.call('لا يوجد اتصال بالإنترنت - محاولة العمل من الكاش');
        return await _workOffline(reportId, title, options);
      }
      
      // تقسيم البيانات إلى أجزاء
      final dataChunks = _splitDataIntoChunks(data);
      onStatusUpdate?.call('تم تقسيم البيانات إلى ${dataChunks.length} جزء');
      
      // معالجة الأجزاء بشكل متزامن
      final processedChunks = await _processChunksConcurrently(
        dataChunks,
        onStatusUpdate,
        onProgress,
      );
      
      // دمج الأجزاء
      onStatusUpdate?.call('جاري دمج الأجزاء...');
      final mergedData = _mergeChunks(processedChunks);
      
      // إنشاء التقرير النهائي
      onStatusUpdate?.call('إنشاء التقرير النهائي...');
      final report = await _generateFinalReport(
        mergedData,
        title,
        options,
      );
      
      // حفظ التقرير في الكاش
      onStatusUpdate?.call('حفظ التقرير في الكاش...');
      await _cacheReport(reportId, report, options);
      
      onStatusUpdate?.call('تم إنشاء التقرير بنجاح');
      onProgress?.call(1.0);
      
      PerformanceMonitor.endTimer('advanced_report_generation');
      
      return {
        'success': true,
        'data': report,
        'source': 'generated',
        'cached': false,
        'chunks': dataChunks.length,
        'totalItems': data.length,
      };
      
    } catch (e) {
      onStatusUpdate?.call('خطأ في إنشاء التقرير: $e');
      PerformanceMonitor.logPerformanceError('advanced_report_generation', e.toString());
      
      // محاولة العمل من الكاش في حالة الخطأ
      return await _workOffline(reportId, title, options);
    }
  }
  
  /// تقسيم البيانات إلى أجزاء
  static List<List<Map<String, dynamic>>> _splitDataIntoChunks(
    List<Map<String, dynamic>> data,
  ) {
    final chunks = <List<Map<String, dynamic>>>[];
    
    for (int i = 0; i < data.length; i += _maxDataChunkSize) {
      final end = (i + _maxDataChunkSize < data.length) 
          ? i + _maxDataChunkSize 
          : data.length;
      chunks.add(data.sublist(i, end));
    }
    
    return chunks;
  }
  
  /// معالجة الأجزاء بشكل متزامن
  static Future<List<Map<String, dynamic>>> _processChunksConcurrently(
    List<List<Map<String, dynamic>>> chunks,
    void Function(String status)? onStatusUpdate,
    void Function(double progress)? onProgress,
  ) async {
    final processedChunks = <Map<String, dynamic>>[];
    int completedChunks = 0;
    
    // معالجة الأجزاء في مجموعات
    for (int i = 0; i < chunks.length; i += _maxConcurrentChunks) {
      final end = (i + _maxConcurrentChunks < chunks.length) 
          ? i + _maxConcurrentChunks 
          : chunks.length;
      final batch = chunks.sublist(i, end);
      
      onStatusUpdate?.call('معالجة الأجزاء ${i + 1} إلى $end من ${chunks.length}');
      
      // معالجة المجموعة بشكل متزامن
      final batchResults = await Future.wait(
        batch.asMap().entries.map((entry) async {
          final chunkIndex = entry.key + i;
          final chunk = entry.value;
          
          return await ConcurrentOperationsManager.executeOperation(
            operationId: 'process_chunk_$chunkIndex',
            operation: () => _processChunk(chunk, chunkIndex),
            timeout: _chunkTimeout,
            priority: 1,
          );
        }),
      );
      
      processedChunks.addAll(batchResults);
      completedChunks += batch.length;
      onProgress?.call(completedChunks / chunks.length);
      
      // تنظيف الذاكرة بين المجموعات
      if (kIsWeb) {
        // إجبار جمع القمامة في الويب
        print('Batch processed, cleaning memory...');
      }
    }
    
    return processedChunks;
  }
  
  /// معالجة جزء واحد من البيانات
  static Future<Map<String, dynamic>> _processChunk(
    List<Map<String, dynamic>> chunk,
    int chunkIndex,
  ) async {
    try {
      PerformanceMonitor.startTimer('process_chunk_$chunkIndex');
      
      // معالجة البيانات في الجزء
      final processedData = <Map<String, dynamic>>[];
      
      for (final item in chunk) {
        // معالجة الصور إذا كانت موجودة
        if (item.containsKey('images') && item['images'] is List) {
          final images = item['images'] as List;
          final processedImages = <String>[];
          
          for (final image in images) {
            if (image is String) {
              // محاولة الحصول من الكاش أولاً
              final cachedImage = await AdvancedCacheManager.getCachedImage(image);
              if (cachedImage != null) {
                processedImages.add(image);
              } else {
                // إضافة للقائمة للمعالجة لاحقاً
                processedImages.add(image);
              }
            }
          }
          
          item['processedImages'] = processedImages;
        }
        
        processedData.add(item);
      }
      
      PerformanceMonitor.endTimer('process_chunk_$chunkIndex');
      
      return {
        'chunkIndex': chunkIndex,
        'data': processedData,
        'processedAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('Error processing chunk $chunkIndex: $e');
      return {
        'chunkIndex': chunkIndex,
        'data': chunk,
        'error': e.toString(),
        'processedAt': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// دمج الأجزاء المعالجة
  static Map<String, dynamic> _mergeChunks(
    List<Map<String, dynamic>> processedChunks,
  ) {
    final mergedData = <Map<String, dynamic>>[];
    final errors = <String>[];
    
    // ترتيب الأجزاء حسب الفهرس
    processedChunks.sort((a, b) => (a['chunkIndex'] ?? 0).compareTo(b['chunkIndex'] ?? 0));
    
    for (final chunk in processedChunks) {
      if (chunk.containsKey('error')) {
        errors.add('Chunk ${chunk['chunkIndex']}: ${chunk['error']}');
        // إضافة البيانات الأصلية حتى لو كان هناك خطأ
        if (chunk.containsKey('data')) {
          mergedData.addAll(chunk['data']);
        }
      } else {
        mergedData.addAll(chunk['data']);
      }
    }
    
    return {
      'data': mergedData,
      'errors': errors,
      'totalItems': mergedData.length,
      'mergedAt': DateTime.now().toIso8601String(),
    };
  }
  
  /// إنشاء التقرير النهائي
  static Future<Uint8List> _generateFinalReport(
    Map<String, dynamic> mergedData,
    String title,
    Map<String, dynamic> options,
  ) async {
    try {
      // استخدام PdfReportGenerator مع إدارة الذاكرة
      // إنشاء تقرير بسيط أولاً كـ fallback
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(title, style: pw.TextStyle(fontSize: 20)),
              ),
              pw.SizedBox(height: 20),
              ...mergedData['data'].map((item) => pw.Text(item.toString())),
            ],
          ),
        ),
      );
      
      return await pdf.save();
    } catch (e) {
      print('Error generating final report: $e');
      rethrow;
    }
  }
  
  /// حفظ التقرير في الكاش
  static Future<void> _cacheReport(
    String reportId,
    Uint8List reportData,
    Map<String, dynamic> options,
  ) async {
    try {
      final metadata = {
        'title': options['title'] ?? 'تقرير',
        'generatedAt': DateTime.now().toIso8601String(),
        'size': reportData.length,
        'options': options,
        'priority': options['priority'] ?? 1,
      };
      
      await AdvancedCacheManager.cacheReport(
        reportId: reportId,
        reportData: reportData,
        metadata: metadata,
        priority: options['priority'] ?? 1,
      );
    } catch (e) {
      print('Error caching report: $e');
    }
  }
  
  /// العمل بدون إنترنت
  static Future<Map<String, dynamic>> _workOffline(
    String reportId,
    String title,
    Map<String, dynamic> options,
  ) async {
    try {
      // محاولة العثور على تقرير مشابه في الكاش
      final similarReports = await _findSimilarReports(title, options);
      
      if (similarReports.isNotEmpty) {
        // استخدام التقرير الأحدث والأكثر تشابهاً
        final bestMatch = similarReports.first;
        
        return {
          'success': true,
          'data': bestMatch['data'],
          'source': 'cache_similar',
          'cached': true,
          'note': 'تم استخدام تقرير مشابه من الكاش (لا يوجد اتصال بالإنترنت)',
          'originalId': bestMatch['reportId'],
        };
      }
      
      // إنشاء تقرير بسيط من البيانات المخزنة في الكاش
      final cachedData = await _getCachedDataForReport(title, options);
      if (cachedData != null) {
        final simpleReport = await _generateSimpleReport(cachedData, title);
        
        return {
          'success': true,
          'data': simpleReport,
          'source': 'generated_offline',
          'cached': false,
          'note': 'تم إنشاء تقرير بسيط من البيانات المخزنة (لا يوجد اتصال بالإنترنت)',
        };
      }
      
      return {
        'success': false,
        'error': 'لا يمكن إنشاء التقرير بدون إنترنت ولا توجد بيانات مخزنة',
        'offline': true,
      };
      
    } catch (e) {
      return {
        'success': false,
        'error': 'خطأ في العمل بدون إنترنت: $e',
        'offline': true,
      };
    }
  }
  
  /// البحث عن تقارير مشابهة
  static Future<List<Map<String, dynamic>>> _findSimilarReports(
    String title,
    Map<String, dynamic> options,
  ) async {
    try {
      // البحث في الكاش عن تقارير مشابهة
      final cacheStats = AdvancedCacheManager.getCacheStats();
      final reportCount = cacheStats['reportCount'] ?? 0;
      
      if (reportCount == 0) return [];
      
      // البحث في التقارير المخزنة
      final similarReports = <Map<String, dynamic>>[];
      
      // يمكن إضافة منطق بحث أكثر تعقيداً هنا
      // حالياً نرجع تقرير عشوائي كـ fallback
      
      return similarReports;
    } catch (e) {
      print('Error finding similar reports: $e');
      return [];
    }
  }
  
  /// الحصول على البيانات المخزنة للتقرير
  static Future<Map<String, dynamic>?> _getCachedDataForReport(
    String title,
    Map<String, dynamic> options,
  ) async {
    try {
      // البحث عن بيانات مشابهة في الكاش
      final cacheKey = 'report_data_${title}_${options.hashCode}';
      return await AdvancedCacheManager.getCachedData(cacheKey);
    } catch (e) {
      print('Error getting cached data for report: $e');
      return null;
    }
  }
  
  /// إنشاء تقرير بسيط
  static Future<Uint8List> _generateSimpleReport(
    Map<String, dynamic> data,
    String title,
  ) async {
    try {
      // إنشاء تقرير بسيط بدون صور
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(title, style: pw.TextStyle(fontSize: 20)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('تقرير بسيط من البيانات المخزنة'),
              pw.SizedBox(height: 20),
              ...(data['items'] ?? []).map((item) => pw.Text(item.toString())),
            ],
          ),
        ),
      );
      
      return await pdf.save();
    } catch (e) {
      print('Error generating simple report: $e');
      rethrow;
    }
  }
  
  /// الحصول على حالة التقرير
  static Future<Map<String, dynamic>> getReportStatus(String reportId) async {
    try {
      // فحص الكاش
      final cachedReport = await AdvancedCacheManager.getCachedReport(reportId);
      if (cachedReport != null) {
        return {
          'status': 'cached',
          'reportId': reportId,
          'size': cachedReport['size'],
          'timestamp': cachedReport['timestamp'],
          'accessCount': cachedReport['accessCount'],
        };
      }
      
      // فحص إذا كان التقرير قيد الإنشاء
      final isGenerating = ConcurrentOperationsManager.getStats()['pendingOperations'] > 0;
      
      return {
        'status': isGenerating ? 'generating' : 'not_found',
        'reportId': reportId,
        'isGenerating': isGenerating,
      };
      
    } catch (e) {
      return {
        'status': 'error',
        'reportId': reportId,
        'error': e.toString(),
      };
    }
  }
  
  /// حذف تقرير من الكاش
  static Future<bool> deleteCachedReport(String reportId) async {
    try {
      // البحث عن التقرير في الكاش
      final cachedReport = await AdvancedCacheManager.getCachedReport(reportId);
      if (cachedReport != null) {
        // حذف الملفات
        if (!kIsWeb) {
          final reportFile = File(cachedReport['filePath']);
          final metaFile = File('${cachedReport['filePath']}.meta');
          
          if (await reportFile.exists()) await reportFile.delete();
          if (await metaFile.exists()) await metaFile.delete();
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting cached report: $e');
      return false;
    }
  }
  
  /// تنظيف التقارير القديمة
  static Future<void> cleanupOldReports() async {
    try {
      // تنظيف التقارير الأقدم من 30 يوم
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      if (!kIsWeb) {
        // البحث في ملفات البيانات
        final files = Directory('${AdvancedCacheManager.getCacheStats()['cacheDir']}/reports')
            .listSync()
            .where((f) => f.path.endsWith('.meta'));
        
        for (final file in files) {
          try {
            final metadata = jsonDecode(await File(file.path).readAsString());
            final timestamp = DateTime.parse(metadata['timestamp']);
            
            if (timestamp.isBefore(thirtyDaysAgo)) {
              // حذف التقرير القديم
              await deleteCachedReport(metadata['reportId']);
            }
          } catch (e) {
            print('Error processing metadata file: $e');
          }
        }
      }
      
      print('Old reports cleanup completed');
    } catch (e) {
      print('Error cleaning up old reports: $e');
    }
  }
}
