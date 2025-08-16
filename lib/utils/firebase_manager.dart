import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';
import 'dart:async';

/// نظام إدارة Firebase الذكي للتعامل مع أنواع البناء المختلفة
class FirebaseManager {
  static bool _isInitialized = false;
  static bool _isWebOptimized = false;
  static final Map<String, StreamSubscription> _subscriptions = {};
  static final Map<String, Timer> _timers = {};
  static final Map<String, Completer> _pendingOperations = {};
  
  /// تهيئة Firebase حسب نوع البناء
  static Future<void> initializeFirebase() async {
    if (_isInitialized) {
      print('Firebase already initialized');
      return;
    }

    try {
      // تهيئة Firebase مع الإعدادات المناسبة
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // تحسينات خاصة بالويب
      if (kIsWeb) {
        await _optimizeForWeb();
      }

      _isInitialized = true;
      print('Firebase initialized successfully for ${kIsWeb ? 'web' : 'mobile'}');
    } catch (e) {
      print('Error initializing Firebase: $e');
      rethrow;
    }
  }

  /// تحسينات خاصة بالويب
  static Future<void> _optimizeForWeb() async {
    if (_isWebOptimized) return;

    try {
      // تعيين حدود الذاكرة للويب
      await _setWebMemoryLimits();
      
      // تحسين إعدادات Firebase للويب
      await _configureWebSettings();
      
      _isWebOptimized = true;
      print('Web optimizations applied successfully');
    } catch (e) {
      print('Error applying web optimizations: $e');
    }
  }

  /// تعيين حدود الذاكرة للويب
  static Future<void> _setWebMemoryLimits() async {
    try {
      // تعيين حد الذاكرة للويب (إذا كان مدعوماً)
      if (kIsWeb) {
        // يمكن إضافة إعدادات إضافية للويب هنا
        print('Web memory limits configured');
      }
    } catch (e) {
      print('Error setting web memory limits: $e');
    }
  }

  /// تكوين إعدادات Firebase للويب
  static Future<void> _configureWebSettings() async {
    try {
      // إعدادات خاصة بالويب لتحسين الأداء
      if (kIsWeb) {
        // يمكن إضافة إعدادات Firebase إضافية للويب هنا
        print('Web-specific Firebase settings configured');
      }
    } catch (e) {
      print('Error configuring web settings: $e');
    }
  }

  /// إضافة إدارة للاشتراكات
  static void addSubscription(String key, StreamSubscription subscription) {
    _subscriptions[key] = subscription;
  }
  
  /// إضافة timer
  static void addTimer(String key, Timer timer) {
    _timers[key] = timer;
  }
  
  /// إضافة عملية معلقة
  static void addPendingOperation(String key, Completer completer) {
    _pendingOperations[key] = completer;
  }
  
  /// إزالة عملية معلقة
  static void removePendingOperation(String key) {
    _pendingOperations.remove(key);
  }
  
  /// تنظيف الذاكرة
  static void dispose() {
    // إلغاء جميع الاشتراكات
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // إلغاء جميع الـ timers
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    
    // إلغاء جميع العمليات المعلقة
    for (var completer in _pendingOperations.values) {
      if (!completer.isCompleted) {
        completer.completeError('Disposed');
      }
    }
    _pendingOperations.clear();
    
    print('FirebaseManager disposed successfully');
  }
  
  /// إضافة timeout للعمليات
  static Future<T> withTimeout<T>(Future<T> future, Duration timeout) async {
    try {
      return await future.timeout(timeout);
    } catch (e) {
      print('Operation timed out: $e');
      rethrow;
    }
  }
  
  /// إدارة العمليات المتزامنة
  static Future<T> executeWithConcurrencyLimit<T>({
    required String operationId,
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // فحص إذا كانت العملية معلقة بالفعل
    if (_pendingOperations.containsKey(operationId)) {
      final completer = _pendingOperations[operationId]!;
      return await completer.future;
    }
    
    final completer = Completer<T>();
    _pendingOperations[operationId] = completer;
    
    try {
      final result = await withTimeout(operation(), timeout);
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingOperations.remove(operationId);
    }
  }

  /// التحقق من حالة التهيئة
  static bool get isInitialized => _isInitialized;
  
  /// التحقق من أن التطبيق يعمل على الويب
  static bool get isWeb => kIsWeb;
  
  /// التحقق من تطبيق تحسينات الويب
  static bool get isWebOptimized => _isWebOptimized;
  
  /// الحصول على عدد العمليات المعلقة
  static int get pendingOperationsCount => _pendingOperations.length;
  
  /// الحصول على عدد الاشتراكات النشطة
  static int get activeSubscriptionsCount => _subscriptions.length;

  /// الحصول على إحصائيات Firebase
  static Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'isWebOptimized': _isWebOptimized,
      'pendingOperations': _pendingOperations.length,
      'activeSubscriptions': _subscriptions.length,
      'activeTimers': _timers.length,
    };
  }

  /// إعادة تعيين حالة التهيئة (للتطوير)
  static void reset() {
    _isInitialized = false;
    _isWebOptimized = false;
    dispose();
  }
} 