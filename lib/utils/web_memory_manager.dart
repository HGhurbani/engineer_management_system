import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// نظام إدارة الذاكرة المحسن للويب
class WebMemoryManager {
  static bool _isInitialized = false;
  static Timer? _memoryMonitorTimer;
  static int _lastMemoryUsage = 0;
  static const int _memoryThreshold = 80; // نسبة الذاكرة المسموحة
  static const int _checkInterval = 5000; // فحص كل 5 ثواني

  /// تهيئة نظام إدارة الذاكرة للويب
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      await _setupMemoryMonitoring();
      _isInitialized = true;
      print('Web memory manager initialized');
    }
  }

  /// إعداد مراقبة الذاكرة
  static Future<void> _setupMemoryMonitoring() async {
    try {
      // بدء مراقبة الذاكرة
      _startMemoryMonitoring();
      
      // إعداد معالج لتنظيف الذاكرة عند الحاجة
      _setupMemoryCleanup();
      
      print('Memory monitoring setup completed');
    } catch (e) {
      print('Error setting up memory monitoring: $e');
    }
  }

  /// بدء مراقبة الذاكرة
  static void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(
      const Duration(milliseconds: _checkInterval),
      (timer) {
        _checkMemoryUsage();
      },
    );
  }

  /// فحص استخدام الذاكرة
  static void _checkMemoryUsage() {
    try {
      final currentUsage = _getCurrentMemoryUsage();
      
      if (currentUsage > _memoryThreshold) {
        _triggerMemoryCleanup();
      }
      
      _lastMemoryUsage = currentUsage;
    } catch (e) {
      print('Error checking memory usage: $e');
    }
  }

  /// الحصول على استخدام الذاكرة الحالي
  static int _getCurrentMemoryUsage() {
    try {
      // استخدام Performance API للويب
      final performance = js.context['performance'];
      if (performance != null) {
        final memory = performance['memory'];
        if (memory != null) {
          final used = memory['usedJSHeapSize'];
          final total = memory['totalJSHeapSize'];
          if (used != null && total != null) {
            return ((used / total) * 100).round();
          }
        }
      }
    } catch (e) {
      print('Error getting memory usage: $e');
    }
    return 0;
  }

  /// تفعيل تنظيف الذاكرة
  static void _triggerMemoryCleanup() {
    print('Memory usage high (${_lastMemoryUsage}%), triggering cleanup');
    
    // تنظيف الذاكرة
    _forceGarbageCollection();
    
    // إخطار النظام بضرورة تنظيف الذاكرة
    _notifyMemoryCleanup();
  }

  /// إجبار جمع القمامة
  static void _forceGarbageCollection() {
    try {
      // محاولة إجبار جمع القمامة في الويب
      js.context.callMethod('eval', ['if (window.gc) window.gc();']);
      
      // تأخير قصير للسماح بجمع القمامة
      Future.delayed(const Duration(milliseconds: 100));
      
      print('Garbage collection triggered');
    } catch (e) {
      print('Error forcing garbage collection: $e');
    }
  }

  /// إعداد معالج تنظيف الذاكرة
  static void _setupMemoryCleanup() {
    // إضافة مستمع لحدث تنظيف الذاكرة
    try {
      js.context.callMethod('addEventListener', [
        'beforeunload',
        (event) {
          _cleanupBeforeUnload();
        },
      ]);
    } catch (e) {
      print('Error setting up memory cleanup: $e');
    }
  }

  /// تنظيف الذاكرة قبل إغلاق الصفحة
  static void _cleanupBeforeUnload() {
    try {
      // تنظيف الموارد قبل إغلاق الصفحة
      _clearAllCaches();
      _forceGarbageCollection();
    } catch (e) {
      print('Error in beforeunload cleanup: $e');
    }
  }

  /// إخطار النظام بضرورة تنظيف الذاكرة
  static void _notifyMemoryCleanup() {
    // يمكن إضافة إشعارات للمستخدم هنا
    print('Memory cleanup notification sent');
  }

  /// تنظيف جميع الكاشات
  static void _clearAllCaches() {
    try {
      // تنظيف كاش المتصفح
      js.context.callMethod('eval', [
        'if (window.caches) { caches.keys().then(names => names.forEach(name => caches.delete(name))); }'
      ]);
      
      print('All caches cleared');
    } catch (e) {
      print('Error clearing caches: $e');
    }
  }

  /// الحصول على معلومات الذاكرة
  static Map<String, dynamic> getMemoryInfo() {
    try {
      final performance = js.context['performance'];
      if (performance != null) {
        final memory = performance['memory'];
        if (memory != null) {
          return {
            'used': memory['usedJSHeapSize'] ?? 0,
            'total': memory['totalJSHeapSize'] ?? 0,
            'limit': memory['jsHeapSizeLimit'] ?? 0,
            'percentage': _lastMemoryUsage,
          };
        }
      }
    } catch (e) {
      print('Error getting memory info: $e');
    }
    return {};
  }

  /// التحقق من حالة الذاكرة
  static bool isMemoryLow() {
    return _lastMemoryUsage > _memoryThreshold;
  }

  /// إيقاف مراقبة الذاكرة
  static void dispose() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    _isInitialized = false;
    print('Web memory manager disposed');
  }

  /// تنظيف الذاكرة يدوياً
  static void manualCleanup() {
    _forceGarbageCollection();
    _clearAllCaches();
    print('Manual memory cleanup completed');
  }

  /// الحصول على نسبة استخدام الذاكرة
  static int get memoryUsagePercentage => _lastMemoryUsage;
  
  /// التحقق من تهيئة النظام
  static bool get isInitialized => _isInitialized;
} 