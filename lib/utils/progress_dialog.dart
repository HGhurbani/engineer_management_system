import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

class ProgressDialog {
  static DateTime? _shownAt;
  static const Duration _minDisplayDuration = Duration(seconds: 1);
  static ValueNotifier<double>? _currentNotifier;
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// عرض مربع حوار التقدم مع إمكانية التحكم في النسبة المئوية
  static ValueNotifier<double> show(
      BuildContext context,
      String message, {
        bool useOverlay = false,
        Color? progressColor,
        Color? backgroundColor,
        double? elevation,
        BorderRadius? borderRadius,
      }) {
    if (_isShowing) {
      hide(context);
    }

    final notifier = ValueNotifier<double>(0);
    _currentNotifier = notifier;
    _shownAt = DateTime.now();
    _isShowing = true;

    if (useOverlay) {
      _showOverlay(context, message, notifier, progressColor, backgroundColor, elevation, borderRadius);
    } else {
      _showDialog(context, message, notifier, progressColor, backgroundColor, elevation, borderRadius);
    }

    return notifier;
  }

  /// عرض مربع الحوار التقليدي
  static void _showDialog(
      BuildContext context,
      String message,
      ValueNotifier<double> notifier,
      Color? progressColor,
      Color? backgroundColor,
      double? elevation,
      BorderRadius? borderRadius,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: _buildProgressWidget(
                message,
                notifier,
                progressColor,
                backgroundColor,
                elevation,
                borderRadius,
              ),
            ),
          ),
        );
      },
    );
  }

  /// عرض الـ Overlay
  static void _showOverlay(
      BuildContext context,
      String message,
      ValueNotifier<double> notifier,
      Color? progressColor,
      Color? backgroundColor,
      double? elevation,
      BorderRadius? borderRadius,
      ) {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: _buildProgressWidget(
              message,
              notifier,
              progressColor,
              backgroundColor,
              elevation,
              borderRadius,
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  /// بناء عنصر التقدم
  static Widget _buildProgressWidget(
      String message,
      ValueNotifier<double> notifier,
      Color? progressColor,
      Color? backgroundColor,
      double? elevation,
      BorderRadius? borderRadius,
      ) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, child) {
        final theme = Theme.of(context);
        final isRTL = Directionality.of(context) == TextDirection.rtl;

        return Container(
          constraints: const BoxConstraints(
            minWidth: 280,
            maxWidth: 320,
          ),
          margin: const EdgeInsets.all(20),
          child: Card(
            elevation: elevation ?? 8,
            color: backgroundColor ?? theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius ?? BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // مؤشر التقدم الدائري
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (progressColor ?? AppConstants.primaryColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: value == 0 ? null : value,
                          color: progressColor ?? AppConstants.primaryColor,
                          strokeWidth: 3,
                          backgroundColor: (progressColor ?? AppConstants.primaryColor).withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // النص والنسبة المئوية
                  Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'NotoSansArabic',
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                  ),

                  const SizedBox(height: 12),

                  // شريط التقدم الخطي
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: value == 0 ? null : value,
                        color: progressColor ?? AppConstants.primaryColor,
                        backgroundColor: (progressColor ?? AppConstants.primaryColor).withOpacity(0.1),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value == 0 ? 'جاري التحميل...' : '${(value * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'NotoSansArabic',
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// إخفاء مربع حوار التقدم
  static Future<void> hide(BuildContext context) async {
    if (!_isShowing) return;

    // التأكد من عرض الحوار لمدة لا تقل عن الحد الأدنى
    final elapsed = DateTime.now().difference(_shownAt ?? DateTime.now());
    final remaining = _minDisplayDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    // إخفاء الحوار أو الـ Overlay
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // إعادة تعيين المتغيرات
    _isShowing = false;
    _currentNotifier = null;
    _shownAt = null;
  }

  /// التحقق من حالة العرض
  static bool get isShowing => _isShowing;

  /// الحصول على المؤشر الحالي
  static ValueNotifier<double>? get currentNotifier => _currentNotifier;

  /// تحديث التقدم
  static void updateProgress(double progress) {
    _currentNotifier?.value = progress.clamp(0.0, 1.0);
  }

  /// عرض حوار تحميل بسيط بدون تحكم في النسبة
  static void showSimple(BuildContext context, String message) {
    show(context, message);
  }

  /// عرض حوار تحميل مع نسبة مئوية محددة
  static void showWithProgress(
      BuildContext context,
      String message,
      double progress
      ) {
    final notifier = show(context, message);
    notifier.value = progress.clamp(0.0, 1.0);
  }
}