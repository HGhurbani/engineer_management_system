import 'dart:async';
import 'package:flutter/foundation.dart';

/// مراقب الأداء لتحسين التطبيق
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, List<int>> _operationTimes = {};
  static final Map<String, int> _operationCounts = {};
  static final List<String> _memoryWarnings = [];
  static Timer? _cleanupTimer;
  
  /// بدء توقيت لعملية
  static void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
  }
  
  /// إنهاء توقيت لعملية
  static void endTimer(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMilliseconds;
      
      // تسجيل وقت العملية
      if (!_operationTimes.containsKey(operation)) {
        _operationTimes[operation] = [];
      }
      _operationTimes[operation]!.add(duration);
      
      // تسجيل عدد مرات التنفيذ
      _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
      
      // طباعة الوقت إذا كان بطيئاً
      if (duration > 1000) {
        print('⚠️ Slow operation: $operation took ${duration}ms');
      } else if (duration > 500) {
        print('⚠️ Medium operation: $operation took ${duration}ms');
      } else {
        print('✅ Fast operation: $operation took ${duration}ms');
      }
      
      _timers.remove(operation);
    }
  }
  
  /// تسجيل استخدام الذاكرة
  static void logMemoryUsage(String operation) {
    if (kIsWeb) {
      // في الويب، يمكن استخدام Web APIs لفحص الذاكرة
      print('📊 Memory usage logged for: $operation');
      
      // محاكاة فحص الذاكرة
      final memoryUsage = _simulateMemoryUsage();
      if (memoryUsage > 80) {
        final warning = 'High memory usage: ${memoryUsage}% during $operation';
        _memoryWarnings.add(warning);
        print('🚨 $warning');
      }
    }
  }
  
  /// محاكاة فحص استخدام الذاكرة
  static int _simulateMemoryUsage() {
    // في التطبيق الحقيقي، يمكن استخدام Web APIs
    return DateTime.now().millisecond % 100;
  }
  
  /// الحصول على إحصائيات الأداء
  static Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    // إحصائيات العمليات
    for (final operation in _operationTimes.keys) {
      final times = _operationTimes[operation]!;
      final count = _operationCounts[operation] ?? 0;
      
      if (times.isNotEmpty) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final maxTime = times.reduce((a, b) => a > b ? a : b);
        final minTime = times.reduce((a, b) => a < b ? a : b);
        
        stats[operation] = {
          'count': count,
          'averageTime': avgTime.round(),
          'maxTime': maxTime,
          'minTime': minTime,
          'totalTime': times.reduce((a, b) => a + b),
        };
      }
    }
    
    // إحصائيات الذاكرة
    stats['memoryWarnings'] = _memoryWarnings.length;
    stats['recentWarnings'] = _memoryWarnings.take(5).toList();
    
    return stats;
  }
  
  /// تنظيف البيانات القديمة
  static void cleanup() {
    // إزالة العمليات القديمة
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    
    for (final operation in _operationTimes.keys.toList()) {
      // الاحتفاظ فقط بالعمليات الحديثة
      if (_operationTimes[operation]!.length > 100) {
        _operationTimes[operation] = _operationTimes[operation]!.take(50).toList();
      }
    }
    
    // تنظيف التحذيرات القديمة
    if (_memoryWarnings.length > 20) {
      _memoryWarnings.removeRange(0, _memoryWarnings.length - 10);
    }
    
    print('🧹 PerformanceMonitor cleanup completed');
  }
  
  /// بدء التنظيف التلقائي
  static void startAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      cleanup();
    });
  }
  
  /// إيقاف التنظيف التلقائي
  static void stopAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
  
  /// فحص الأداء العام
  static String getPerformanceSummary() {
    final stats = getPerformanceStats();
    final slowOperations = <String>[];
    
    for (final entry in stats.entries) {
      if (entry.key != 'memoryWarnings' && entry.key != 'recentWarnings') {
        final data = entry.value as Map<String, dynamic>;
        if (data['averageTime'] > 1000) {
          slowOperations.add('${entry.key}: ${data['averageTime']}ms avg');
        }
      }
    }
    
    if (slowOperations.isEmpty) {
      return '✅ All operations are performing well';
    } else {
      return '⚠️ Slow operations detected:\n${slowOperations.join('\n')}';
    }
  }
  
  /// تسجيل خطأ في الأداء
  static void logPerformanceError(String operation, String error) {
    print('❌ Performance error in $operation: $error');
    
    // إضافة للتحذيرات
    _memoryWarnings.add('Error in $operation: $error');
  }
  
  /// فحص إذا كان الأداء مقبول
  static bool get isPerformanceAcceptable {
    final stats = getPerformanceStats();
    
    for (final entry in stats.entries) {
      if (entry.key != 'memoryWarnings' && entry.key != 'recentWarnings') {
        final data = entry.value as Map<String, dynamic>;
        if (data['averageTime'] > 2000) {
          return false;
        }
      }
    }
    
    return _memoryWarnings.length < 5;
  }
  
  /// إعادة تعيين جميع الإحصائيات
  static void reset() {
    _timers.clear();
    _operationTimes.clear();
    _operationCounts.clear();
    _memoryWarnings.clear();
    _cleanupTimer?.cancel();
    
    print('🔄 PerformanceMonitor reset completed');
  }
  
  /// التخلص من الموارد
  static void dispose() {
    _cleanupTimer?.cancel();
    _timers.clear();
    _operationTimes.clear();
    _operationCounts.clear();
    _memoryWarnings.clear();
    
    print('🗑️ PerformanceMonitor disposed');
  }
}




