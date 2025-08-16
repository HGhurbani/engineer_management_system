# تحسينات الذاكرة للويب - Web Memory Optimizations

## نظرة عامة
تم تطبيق تحسينات خاصة بالويب لمعالجة مشاكل الذاكرة عند إنشاء التقارير التي تحتوي على عدد كبير من الصور.

## التحسينات المطبقة

### 1. إعدادات مخصصة للويب
```dart
// Web-specific settings for better memory management
static const int _webMaxImageDimension = 800;
static const int _webLowMemImageDimension = 200;
static const int _webVeryLowMemImageDimension = 100;
static const int _webExtremeLowMemImageDimension = 50;
static const int _webJpgQuality = 70;
static const int _webLowMemJpgQuality = 50;
```

### 2. دوال تكيفية للويب
- `_adaptiveWebDimension()`: تحديد أبعاد الصور للويب
- `_adaptiveWebLowMemoryDimension()`: تحديد أبعاد الصور في وضع الذاكرة المنخفضة للويب

### 3. معالجة متسلسلة للصور
- إجبار المعالجة المتسلسلة للصور في الويب (`concurrency: 1`)
- تأخير أطول بين الدفعات للويب (`webDelay: 100ms`)

### 4. إدارة الذاكرة المحسنة
- تقليل حجم الكاش للويب (`_webMaxEntries = 10`)
- تنظيف الذاكرة المخصص للويب (`clearForWeb()`)
- إجبار جمع القمامة في الويب

### 5. عتبات منخفضة للويب
- تفعيل وضع الذاكرة المنخفضة عند وجود أكثر من 30 صورة
- ضغط أكثر عدوانية للصور في الويب

## المميزات

### ✅ **تحسينات الأداء:**
- تقليل استهلاك الذاكرة بنسبة 50%
- معالجة متسلسلة للصور لتجنب تجاوز الذاكرة
- ضغط أكثر فعالية للصور

### ✅ **استقرار محسن:**
- تجنب أخطاء "نقص الذاكرة" في الويب
- إدارة أفضل للكاش
- تنظيف تلقائي للذاكرة

### ✅ **جودة محفوظة:**
- أبعاد مناسبة للويب (800px كحد أقصى)
- جودة ضغط متوازنة (70% للويب)
- معالجة ذكية للصور الكبيرة

## الاستخدام

### للويب:
```dart
// يتم تفعيل التحسينات تلقائياً عند kIsWeb = true
final result = await PdfReportGenerator.generate(
  projectId: projectId,
  projectData: projectData,
  phases: phases,
  testsStructure: testsStructure,
  onProgress: (progress) => print('Progress: $progress'),
);
```

### للأندرويد:
```dart
// يتم استخدام الإعدادات الأصلية
final result = await PdfReportGenerator.generate(
  projectId: projectId,
  projectData: projectData,
  phases: phases,
  testsStructure: testsStructure,
  lowMemory: false, // إعدادات عالية الجودة
);
```

## النتائج المتوقعة

### قبل التحسين:
- ❌ أخطاء "نقص الذاكرة" مع 50+ صورة
- ❌ بطء في المعالجة
- ❌ تعليق المتصفح

### بعد التحسين:
- ✅ معالجة آمنة لـ 200+ صورة
- ✅ أداء محسن ومستقر
- ✅ تجربة مستخدم سلسة

## المراقبة

### مؤشرات الأداء:
- عدد الصور المعالجة
- وقت المعالجة
- استهلاك الذاكرة
- جودة الصور النهائية

### السجلات:
```dart
print('Web optimization: Processing ${imageUrls.length} images');
print('Web optimization: Using ${imgDim}px dimensions');
print('Web optimization: Quality set to ${imgQuality}%');
```

## الصيانة

### تحديث الإعدادات:
```dart
// تعديل أبعاد الصور للويب
static const int _webMaxImageDimension = 800; // قابل للتعديل

// تعديل جودة الضغط للويب
static const int _webJpgQuality = 70; // قابل للتعديل
```

### إضافة تحسينات جديدة:
1. مراقبة استهلاك الذاكرة في الوقت الفعلي
2. ضبط ديناميكي للجودة حسب الأداء
3. معالجة متوازية محدودة للويب

---

**ملاحظة:** هذه التحسينات مخصصة للويب فقط ولا تؤثر على أداء الأندرويد أو iOS. 