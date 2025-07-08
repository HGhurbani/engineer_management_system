import 'package:flutter/material.dart';
import '../theme/app_constants.dart';

class ProgressDialog {
  static ValueNotifier<double> show(BuildContext context, String message) {
    final notifier = ValueNotifier<double>(0);
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

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
