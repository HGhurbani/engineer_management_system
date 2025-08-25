# دليل ترحيل الصور من Firebase إلى الاستضافة الخاصة

## نظرة عامة
تم تطوير نظام هجين لإدارة الصور يدعم:
- **رفع الصور الجديدة**: إلى الاستضافة الخاصة `bhbgroup.me`
- **قراءة الصور القديمة**: من Firebase Storage والاستضافة الخاصة
- **التوافق الكامل**: مع البيانات الموجودة

## الملفات المضافة/المحدثة

### 1. الخدمات الجديدة
- `lib/utils/hybrid_image_service.dart` - خدمة رفع الصور الهجينة
- `lib/utils/image_display_helper.dart` - مساعد عرض الصور
- `lib/utils/image_migration_service.dart` - خدمة ترحيل الصور
- `lib/pages/admin/image_migration_page.dart` - صفحة إدارة الترحيل

### 2. الصفحات المحدثة
- `lib/pages/admin/admin_add_phase_entry_page.dart` - تستخدم الآن الاستضافة الخاصة
- `lib/pages/engineer/add_phase_entry_page.dart` - تستخدم الآن الاستضافة الخاصة

### 3. الخادم
- `server_files/api/upload_image.php` - محدث لدعم رفع base64

## كيفية عمل النظام الهجين

### رفع الصور الجديدة
```dart
// استخدام الخدمة الجديدة
final urls = await HybridImageService.uploadImagesWithProgress(
  images,
  projectId,
  folder,
  (progress) => print('Progress: $progress'),
);
```

### عرض الصور (يدعم Firebase والاستضافة الخاصة)
```dart
// استخدام مساعد العرض
ImageDisplayHelper.buildNetworkImage(
  imageUrl: url, // يعمل مع أي نوع من الروابط
  height: 100,
  width: 100,
);
```

### فحص نوع الصورة
```dart
final sourceType = HybridImageService.getImageSourceType(url);
if (sourceType == ImageSourceType.firebase) {
  print('صورة من Firebase');
} else if (sourceType == ImageSourceType.customHosting) {
  print('صورة من الاستضافة الخاصة');
}
```

## ترحيل الصور القديمة (اختياري)

### 1. تحليل الصور الموجودة
```dart
final analysis = await ImageMigrationService.analyzeAllImages();
print('صور Firebase: ${analysis['total_firebase_images']}');
print('صور الاستضافة: ${analysis['total_custom_hosting_images']}');
```

### 2. ترحيل جميع الصور
```dart
final result = await ImageMigrationService.migrateAllImages();
if (result['success']) {
  print('تم ترحيل ${result['migrated_images']} صورة');
}
```

### 3. ترحيل مشروع واحد
```dart
final result = await ImageMigrationService.migrateProjectImages(projectId);
```

## واجهة إدارة الترحيل

تم إضافة صفحة إدارية لإدارة عملية الترحيل:
- تحليل الصور الموجودة
- عرض إحصائيات مفصلة
- ترحيل الصور بنقرة واحدة
- مراقبة تقدم العملية

## التوافق مع البيانات القديمة

### الصور الموجودة
- **صور Firebase**: تعمل بشكل طبيعي، يمكن عرضها وقراءتها
- **صور الاستضافة**: تعمل بشكل طبيعي
- **لا حاجة لتعديل قاعدة البيانات**: النظام يتعرف تلقائياً على نوع الصورة

### الصور الجديدة
- **جميع الصور الجديدة**: ترفع إلى `bhbgroup.me`
- **تنسيق الروابط**: `https://bhbgroup.me/uploads/{category}/{project_id}/{year}/{month}/{filename}`

## مميزات النظام الجديد

### 1. الأداء
- **ضغط تلقائي**: للصور الكبيرة
- **تحسين الأبعاد**: حسب المنصة (ويب/موبايل)
- **رفع متوازي**: للصور المتعددة

### 2. الموثوقية
- **معالجة الأخطاء**: مع الاستمرار في رفع الصور الأخرى
- **إعادة المحاولة**: في حالة فشل الرفع
- **تنظيف الذاكرة**: تلقائي

### 3. المرونة
- **دعم متعدد المصادر**: Firebase + استضافة خاصة
- **ترحيل اختياري**: للصور القديمة
- **واجهة إدارية**: لمراقبة العملية

## استخدام الخدمات

### في صفحات الإدارة والمهندس
```dart
// استيراد الخدمة
import '../../utils/hybrid_image_service.dart';

// رفع الصور
Future<List<String>> _uploadImages(List<XFile> images, String folder) async {
  return await HybridImageService.uploadImagesWithProgress(
    images,
    widget.projectId,
    folder,
    (progress) {
      setState(() {
        _uploadProgress = progress;
      });
    },
  );
}
```

### عرض الصور
```dart
// استخدام Image.network العادي يعمل مع جميع الأنواع
Image.network(
  imageUrl, // يدعم Firebase و bhbgroup.me
  height: 100,
  width: 100,
  fit: BoxFit.cover,
  errorBuilder: (c, e, s) => Container(
    // معالجة الأخطاء
  ),
)

// أو استخدام المساعد المحسن
ImageDisplayHelper.buildNetworkImage(
  imageUrl: imageUrl,
  height: 100,
  width: 100,
)
```

## ملاحظات مهمة

### 1. عدم الحاجة لتعديل قاعدة البيانات
- الروابط القديمة تبقى كما هي
- النظام يتعرف تلقائياً على نوع الرابط
- لا حاجة لترحيل فوري

### 2. الترحيل اختياري
- يمكن ترك الصور القديمة في Firebase
- الترحيل مفيد لتوحيد مصدر التخزين
- يمكن الترحيل تدريجياً

### 3. الأمان
- جميع الصور محمية بنفس طريقة Firebase
- تنظيف تلقائي للملفات المؤقتة
- معالجة شاملة للأخطاء

## الخطوات التالية

1. **اختبار النظام**: تأكد من عمل رفع الصور الجديدة
2. **تحليل البيانات**: استخدم صفحة إدارة الترحيل لفهم الوضع الحالي
3. **الترحيل (اختياري)**: رحل الصور القديمة إذا رغبت في توحيد المصدر
4. **المراقبة**: تابع أداء النظام الجديد

## الدعم الفني

في حالة وجود مشاكل:
1. تحقق من logs في Developer Console
2. استخدم صفحة إدارة الترحيل لفهم المشكلة
3. تأكد من صحة إعدادات الخادم `bhbgroup.me`
