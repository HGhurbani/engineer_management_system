import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

class ProgressDialog {
  static DateTime? _shownAt;
  static const Duration _minDisplayDuration = Duration(seconds: 1);

  static ValueNotifier<double> show(BuildContext context, String message) {
    final notifier = ValueNotifier<double>(0);
    _shownAt = DateTime.now();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return ValueListenableBuilder<double>(
          valueListenable: notifier,
          builder: (context, value, child) {
            return AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(
                    value: value == 0 ? null : value,
                    color: AppConstants.primaryColor,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      '$message ${(value * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontFamily: 'NotoSansArabic'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return notifier;
  }

  static Future<void> hide(BuildContext context) async {
    final elapsed = DateTime.now().difference(_shownAt ?? DateTime.now());
    final remaining = _minDisplayDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
