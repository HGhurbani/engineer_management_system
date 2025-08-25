import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// مدير العمليات المتزامنة لتحسين الأداء
class ConcurrentOperationsManager {
  static final Map<String, Completer> _operations = {};
  static final Map<String, Timer> _timers = {};
  static const int _maxConcurrentOperations = 3;
  static int _currentOperations = 0;
  static final Queue<Map<String, dynamic>> _pendingQueue = Queue();
  
  /// تنفيذ عملية مع حد العمليات المتزامنة
  static Future<T> executeOperation<T>({
    required String operationId,
    required Future<T> Function() operation,
    Duration timeout = const Duration(seconds: 30),
    int priority = 0,
  }) async {
    // فحص إذا كانت العملية معلقة بالفعل
    if (_operations.containsKey(operationId)) {
      final completer = _operations[operationId]!;
      return await completer.future;
    }
    
    // إضافة العملية للقائمة المعلقة
    _pendingQueue.add({
      'id': operationId,
      'operation': operation,
      'timeout': timeout,
      'priority': priority,
      'timestamp': DateTime.now(),
    });
    
    // ترتيب القائمة حسب الأولوية
    final sortedList = _pendingQueue.toList();
    sortedList.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
    _pendingQueue.clear();
    for (final item in sortedList) {
      _pendingQueue.add(item);
    }
    
    // محاولة تنفيذ العمليات
    _processQueue();
    
    // انتظار اكتمال العملية
    final completer = Completer<T>();
    _operations[operationId] = completer;
    
    try {
      final result = await completer.future;
      return result;
    } finally {
      _operations.remove(operationId);
      _currentOperations--;
      _processQueue(); // معالجة العمليات المعلقة
    }
  }
  
  /// معالجة قائمة العمليات المعلقة
  static void _processQueue() {
    while (_currentOperations < _maxConcurrentOperations && _pendingQueue.isNotEmpty) {
      final item = _pendingQueue.removeFirst();
      _executeQueuedOperation(item);
    }
  }
  
  /// تنفيذ عملية من القائمة المعلقة
  static void _executeQueuedOperation(Map<String, dynamic> item) async {
    final operationId = item['id'] as String;
    final operation = item['operation'] as Future<dynamic> Function();
    final timeout = item['timeout'] as Duration;
    
    _currentOperations++;
    
    try {
      final result = await operation().timeout(timeout);
      
      if (_operations.containsKey(operationId)) {
        final completer = _operations[operationId]!;
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }
    } catch (e) {
      if (_operations.containsKey(operationId)) {
        final completer = _operations[operationId]!;
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    }
  }
  
  /// إضافة timer مع إدارة
  static Timer addTimer(String key, Duration duration, VoidCallback callback) {
    final timer = Timer(duration, () {
      callback();
      _timers.remove(key);
    });
    
    _timers[key] = timer;
    return timer;
  }
  
  /// إلغاء timer
  static void cancelTimer(String key) {
    final timer = _timers[key];
    if (timer != null) {
      timer.cancel();
      _timers.remove(key);
    }
  }
  
  /// إلغاء جميع الـ timers
  static void cancelAllTimers() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
  
  /// تنظيف جميع العمليات
  static void dispose() {
    // إلغاء جميع العمليات المعلقة
    for (var completer in _operations.values) {
      if (!completer.isCompleted) {
        completer.completeError('Disposed');
      }
    }
    _operations.clear();
    
    // إلغاء جميع الـ timers
    cancelAllTimers();
    
    // إفراغ القائمة المعلقة
    _pendingQueue.clear();
    
    _currentOperations = 0;
    
    print('ConcurrentOperationsManager disposed successfully');
  }
  
  /// الحصول على إحصائيات العمليات
  static Map<String, dynamic> getStats() {
    return {
      'currentOperations': _currentOperations,
      'pendingOperations': _operations.length,
      'queuedOperations': _pendingQueue.length,
      'activeTimers': _timers.length,
      'maxConcurrentOperations': _maxConcurrentOperations,
    };
  }
  
  /// فحص حالة العمليات
  static bool get isIdle => _currentOperations == 0 && _pendingQueue.isEmpty;
  
  /// الحصول على عدد العمليات النشطة
  static int get activeOperationsCount => _currentOperations;
  
  /// الحصول على عدد العمليات المعلقة
  static int get pendingOperationsCount => _pendingQueue.length;

  /// تنفيذ عمليات متوازية مع إدارة الذاكرة
  static Future<List<T>> executeParallelOperations<T>({
    required List<Future<T> Function()> operations,
    int maxConcurrency = 3,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final results = <T>[];
    final semaphore = Semaphore(maxConcurrency);
    
    try {
      final futures = operations.map((operation) async {
        await semaphore.acquire();
        try {
          return await operation().timeout(timeout);
        } finally {
          semaphore.release();
        }
      });
      
      final completedResults = await Future.wait(futures);
      results.addAll(completedResults);
      
    } catch (e) {
      print('Error in parallel operations: $e');
    }
    
    return results;
  }
}

/// مدير الإشارات للتحكم في العمليات المتوازية
class Semaphore {
  final int _maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waiters = Queue();
  
  Semaphore(this._maxCount) : _currentCount = _maxCount;
  
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }
  
  void release() {
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      waiter.complete();
    } else {
      _currentCount++;
    }
  }
}
