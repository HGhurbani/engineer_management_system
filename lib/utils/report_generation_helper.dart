import 'dart:async';
import 'package:flutter/foundation.dart';
import 'pdf_report_generator.dart';
import 'report_snapshot_manager.dart';
import 'memory_optimizer.dart';
import 'report_storage.dart';

/// مساعد إنشاء التقارير مع التحسينات الذكية
class ReportGenerationHelper {
  
  /// إنشاء تقرير بأفضل طريقة متاحة
  static Future<PdfReportResult> generateOptimizedReport({
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
    try {
      // 1. محاولة استخدام Snapshot (الأسرع)
      final snapshot = await ReportSnapshotManager.getReportSnapshot(
        projectId: projectId,
        startDate: start,
        endDate: end,
        onStatusUpdate: onStatusUpdate,
        onProgress: onProgress,
      );
      
      if (snapshot != null) {
        onStatusUpdate?.call('إنشاء التقرير من البيانات المجمعة...');
        return await PdfReportGenerator.generateFromSnapshot(
          projectId: projectId,
          snapshot: snapshot,
          generatedBy: generatedBy,
          generatedByRole: generatedByRole,
          onProgress: onProgress,
        );
      }
      
      // 2. استخدام النظام المحسن
      onStatusUpdate?.call('إنشاء التقرير بالطريقة المحسنة...');
      return await PdfReportGenerator.generate(
        projectId: projectId,
        projectData: projectData,
        phases: phases,
        testsStructure: testsStructure,
        generatedBy: generatedBy,
        generatedByRole: generatedByRole,
        start: start,
        end: end,
        onProgress: onProgress,
        onStatusUpdate: onStatusUpdate,
      );
      
    } catch (e) {
      // 3. Fallback للنظام القديم مع إعدادات الذاكرة المنخفضة
      onStatusUpdate?.call('إعادة المحاولة مع إعدادات الذاكرة المنخفضة...');
      
      return await PdfReportGenerator.generateWithIsolate(
        projectId: projectId,
        projectData: projectData,
        phases: phases,
        testsStructure: testsStructure,
        generatedBy: generatedBy,
        generatedByRole: generatedByRole,
        start: start,
        end: end,
        onProgress: onProgress,
        lowMemory: true,
      );
    }
  }
  
  /// إنشاء تقرير سريع (بدون صور)
  static Future<PdfReportResult> generateQuickReport({
    required String projectId,
    required Map<String, dynamic>? projectData,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> testsStructure,
    String? generatedBy,
    String? generatedByRole,
    DateTime? start,
    DateTime? end,
    void Function(double progress)? onProgress,
  }) async {
    // استخدام generateSimpleTables للتقارير السريعة
    final bytes = await PdfReportGenerator.generateSimpleTables(
      projectId: projectId,
      phases: phases,
      testsStructure: testsStructure,
      start: start,
      end: end,
      onProgress: onProgress,
      lowMemory: true,
    );
    
    // رفع التقرير
    final fileName = 'quick_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final token = generateReportToken();
    final url = await uploadReportPdf(bytes, fileName, token);
    
    return PdfReportResult(bytes: bytes, downloadUrl: url);
  }
  
  /// فحص حالة النظام
  static Future<Map<String, dynamic>> getSystemStatus() async {
    return {
      'memoryOptimizer': MemoryOptimizer.isLowMemoryMode,
      'snapshotStats': await ReportSnapshotManager.getSnapshotStats(),
      'imageProcessorStats': EnhancedImageProcessor.getProcessingStats(),
    };
  }
}
