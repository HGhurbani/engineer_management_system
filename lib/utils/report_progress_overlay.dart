import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

class ReportProgressOverlay {
  static OverlayEntry? _overlayEntry;
  static ValueNotifier<double>? _progressNotifier;
  static ValueNotifier<String>? _messageNotifier;
  static ValueNotifier<Offset>? _positionNotifier;
  static bool _isShowing = false;
  static String _reportId = '';

  // عرض بوب أب التقدم على اليمين
  static void showProgressOverlay(
    BuildContext context, {
    required String reportId,
    required String initialMessage,
    double initialProgress = 0.0,
  }) {
    if (_isShowing) {
      hideProgressOverlay();
    }

    _reportId = reportId;
    _progressNotifier = ValueNotifier<double>(initialProgress);
    _messageNotifier = ValueNotifier<String>(initialMessage);
    _positionNotifier = ValueNotifier<Offset>(const Offset(20, 100)); // الموقع الافتراضي
    _isShowing = true;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildProgressWidget(context),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // إخفاء بوب أب التقدم
  static void hideProgressOverlay() {
    if (!_isShowing) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
    _progressNotifier = null;
    _messageNotifier = null;
    _positionNotifier = null;
    _reportId = '';
  }

  // تحديث التقدم
  static void updateProgress(double progress, {String? message}) {
    if (_progressNotifier != null) {
      _progressNotifier!.value = progress.clamp(0.0, 1.0);
    }
    if (message != null && _messageNotifier != null) {
      _messageNotifier!.value = message;
    }
  }

  // عرض إشعار اكتمال التقرير
  static void showCompletionNotification(
    BuildContext context, {
    required String reportId,
    required String fileName,
    required VoidCallback onTap,
  }) {
    _showCompletionSnackBar(context, fileName, onTap);
  }

  // بناء عنصر التقدم
  static Widget _buildProgressWidget(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _positionNotifier!,
      builder: (context, position, child) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onPanUpdate: (details) {
                // تحديث الموقع عند السحب
                final newPosition = Offset(
                  position.dx + details.delta.dx,
                  position.dy + details.delta.dy,
                );
                
                // التأكد من أن البوب أب يبقى داخل حدود الشاشة
                final screenSize = MediaQuery.of(context).size;
                final popupWidth = 300.0;
                final popupHeight = 200.0;
                
                final clampedPosition = Offset(
                  newPosition.dx.clamp(0, screenSize.width - popupWidth),
                  newPosition.dy.clamp(0, screenSize.height - popupHeight),
                );
                
                _positionNotifier!.value = clampedPosition;
              },
              child: Container(
                width: 300,
                constraints: const BoxConstraints(
                  minHeight: 120,
                  maxHeight: 200,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _progressNotifier!,
                    builder: (context, progress, child) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _messageNotifier!,
                        builder: (context, message, child) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // رأس البوب أب مع مؤشر السحب
                                Row(
                                  children: [
                                    // مؤشر السحب
                                    Container(
                                      width: 40,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.drag_handle,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'إنشاء التقرير',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: hideProgressOverlay,
                                      icon: const Icon(Icons.close, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // شريط التقدم
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // النسبة المئوية
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppConstants.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // الرسالة
                                Text(
                                  message,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // عرض إشعار اكتمال التقرير
  static void _showCompletionSnackBar(
    BuildContext context,
    String fileName,
    VoidCallback onTap,
  ) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تم إنشاء التقرير بنجاح',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: AppConstants.successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'عرض',
        textColor: Colors.white,
        onPressed: onTap,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // التحقق من حالة العرض
  static bool get isShowing => _isShowing;

  // الحصول على معرف التقرير الحالي
  static String get currentReportId => _reportId;
} 