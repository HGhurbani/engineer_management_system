import 'dart:async';
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
      onStatusUpdate?.call('فحص توفر البيانات...');
      
      // 1. محاولة استخدام Snapshot (الأسرع)
      final snapshot = await ReportSnapshotManager.getReportSnapshot(
        projectId: projectId,
        startDate: start,
        endDate: end,
        onStatusUpdate: onStatusUpdate,
        onProgress: (progress) => onProgress?.call(progress * 0.3),
      );
      
      // فحص إذا كان الـ Snapshot يحتوي على بيانات فعلية
      if (snapshot != null && _hasValidData(snapshot)) {
        onStatusUpdate?.call('إنشاء التقرير من البيانات المجمعة...');
        return await PdfReportGenerator.generateFromSnapshot(
          projectId: projectId,
          snapshot: snapshot,
          generatedBy: generatedBy,
          generatedByRole: generatedByRole,
          onProgress: (progress) => onProgress?.call(0.3 + progress * 0.7),
        );
      }
      
      // 2. إذا لم يكن هناك Snapshot صالح، استخدم النظام المحسن مع البيانات الأصلية
      onStatusUpdate?.call('قراءة البيانات من المصدر الأصلي...');
      return await _generateFromOriginalData(
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
      print('خطأ في generateOptimizedReport: $e');
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

  /// فحص إذا كان الـ Snapshot يحتوي على بيانات صالحة
  static bool _hasValidData(Map<String, dynamic> snapshot) {
    final phasesData = snapshot['phasesData'] as List? ?? [];
    final testsData = snapshot['testsData'] as List? ?? [];
    final materialsData = snapshot['materialsData'] as List? ?? [];
    
    // فحص إذا كانت هناك بيانات فعلية (ليس فقط هيكل فارغ)
    bool hasPhaseEntries = false;
    for (final phase in phasesData) {
      if (phase is Map<String, dynamic>) {
        final entries = phase['entries'] as List? ?? [];
        if (entries.isNotEmpty) {
          hasPhaseEntries = true;
          break;
        }
      }
    }
    
    return hasPhaseEntries || testsData.isNotEmpty || materialsData.isNotEmpty;
  }

  /// إنشاء التقرير من البيانات الأصلية
  static Future<PdfReportResult> _generateFromOriginalData({
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
      // محاولة استخدام النظام المحسن أولاً
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
      print('فشل النظام المحسن، التحويل للنظام القديم: $e');
      // إذا فشل، استخدم النظام القديم
      onStatusUpdate?.call('استخدام النظام القديم...');
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
        lowMemory: false,
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
