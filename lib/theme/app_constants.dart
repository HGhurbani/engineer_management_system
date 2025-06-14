import 'package:flutter/material.dart';

class AppConstants {
  // Primary colors
  static const Color primaryColor = Color(0xFF21206C);
  static const Color primaryLight = Color(0xFF2D2C70);
  static const Color primaryDark = Color(0xFF21206C);

  // Accent and surface colors
  static const Color accentColor = Color(0xFF10B981);
  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);

  // Text colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status colors
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color highlightColor = Color(0xFFFFF59D);
  static const Color deleteColor = errorColor;

  // Spacing and dimensions
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double borderRadius = 16.0;
  static const double borderRadiusSmall = 8.0;
  static const double itemSpacing = 16.0;

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  // Misc
  static const Color dividerColor = Color(0xFFEEEEEE);

  // File upload
  static const String uploadUrl =
      'https://bhbgroup.me/images_upload/upload_image.php';
}
