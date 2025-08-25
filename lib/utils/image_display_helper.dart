import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_constants.dart';
import 'hybrid_image_service.dart';

class ImageDisplayHelper {
  /// عرض صورة واحدة مع دعم كامل للصور من Firebase والاستضافة الخاصة
  static Widget buildNetworkImage({
    required String imageUrl,
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(AppConstants.borderRadius / 2.5),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: width,
        fit: fit,
        placeholder: (context, url) => placeholder ?? Container(
          height: height ?? 100,
          width: width ?? 100,
          color: AppConstants.backgroundColor.withOpacity(0.3),
          child: const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppConstants.primaryLight,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => errorWidget ?? Container(
          height: height ?? 100,
          width: width ?? 100,
          color: AppConstants.backgroundColor.withOpacity(0.5),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: AppConstants.textSecondary.withOpacity(0.7),
                  size: (height != null && height < 60) ? 20 : 30,
                ),
                if (height == null || height >= 60)
                  Text(
                    _getImageSourceLabel(imageUrl),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppConstants.textSecondary.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
        // إضافة headers للصور من Firebase إذا لزم الأمر
        httpHeaders: _getImageHeaders(imageUrl),
      ),
    );
  }

  /// عرض صورة مع إمكانية النقر عليها
  static Widget buildClickableImage({
    required String imageUrl,
    required VoidCallback onTap,
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return InkWell(
      onTap: onTap,
      child: buildNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: width,
        fit: fit,
        borderRadius: borderRadius,
      ),
    );
  }

  /// عرض مجموعة من الصور في Wrap
  static Widget buildImageGrid({
    required List<String> imageUrls,
    required Function(String) onImageTap,
    double imageSize = 100,
    double spacing = 8.0,
    double runSpacing = 8.0,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Wrap(
      textDirection: TextDirection.rtl,
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: imageUrls.map((url) {
        return buildClickableImage(
          imageUrl: url,
          onTap: () => onImageTap(url),
          height: imageSize,
          width: imageSize,
        );
      }).toList(),
    );
  }

  /// عرض صور مع عنوان
  static Widget buildImageSection({
    required String title,
    required List<String> imageUrls,
    required Function(String) onImageTap,
    Function(List<String>)? onViewAllTap,
    double imageSize = 100,
    EdgeInsets? padding,
  }) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: AppConstants.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              if (imageUrls.length > 1 && onViewAllTap != null)
                TextButton(
                  onPressed: () => onViewAllTap(imageUrls),
                  child: Text(
                    'عرض الكل (${imageUrls.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.primaryLight,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          buildImageGrid(
            imageUrls: imageUrls,
            onImageTap: onImageTap,
            imageSize: imageSize,
            spacing: AppConstants.paddingSmall / 2,
            runSpacing: AppConstants.paddingSmall / 2,
          ),
        ],
      ),
    );
  }

  /// الحصول على headers للصور (مفيد للصور من Firebase)
  static Map<String, String>? _getImageHeaders(String imageUrl) {
    if (HybridImageService.isFirebaseUrl(imageUrl)) {
      return {
        'Accept': 'image/*',
        'Cache-Control': 'max-age=3600',
      };
    }
    return null;
  }

  /// الحصول على تسمية مصدر الصورة
  static String _getImageSourceLabel(String imageUrl) {
    final sourceType = HybridImageService.getImageSourceType(imageUrl);
    switch (sourceType) {
      case ImageSourceType.firebase:
        return 'Firebase';
      case ImageSourceType.customHosting:
        return 'Server';
      case ImageSourceType.unknown:
        return 'Unknown';
    }
  }

  /// فحص إذا كانت الصورة متاحة
  static Future<bool> isImageAvailable(String imageUrl) async {
    try {
      await CachedNetworkImage.evictFromCache(imageUrl);
      return true;
    } catch (e) {
      print('Error checking image availability: $e');
      return false;
    }
  }

  /// تنظيف cache الصور
  static Future<void> clearImageCache() async {
    await CachedNetworkImage.evictFromCache('');
  }

  /// إنشاء placeholder مخصص
  static Widget buildPlaceholder({
    double? height,
    double? width,
    String? text,
  }) {
    return Container(
      height: height ?? 100,
      width: width ?? 100,
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2.5),
                          border: Border.all(
                    color: AppConstants.textSecondary.withOpacity(0.3),
                    width: 1,
                  ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              color: AppConstants.textSecondary.withOpacity(0.5),
              size: (height != null && height < 60) ? 20 : 30,
            ),
            if (text != null && (height == null || height >= 60))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppConstants.textSecondary.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
