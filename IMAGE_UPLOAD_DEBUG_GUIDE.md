# دليل تشخيص مشكلة رفع الصور

## المشكلة الحالية
الصور تفشل في الرفع مع رسالة الخطأ: "لم يتم رفع الصورة بشكل صحيح"

## التحسينات المضافة للتشخيص

### 1. في Flutter (lib/utils/hybrid_image_service.dart)
```dart
// سيظهر في Console:
print('Uploading image - Size: ${bytes.length} bytes');
print('Base64 length: ${base64Image.length}');
print('Project ID: $projectId, Category: $folder');
```

### 2. في PHP (server_files/api/upload_image.php)
```php
// سيظهر في error_log:
error_log('POST data keys: ' . implode(', ', array_keys($_POST)));
error_log('Content length: ' . ($_SERVER['CONTENT_LENGTH'] ?? 'unknown'));
error_log('Max post size: ' . ini_get('post_max_size'));
error_log('Base64 data length: ' . strlen($base64Data));
error_log('Decoded image size: ' . strlen($imageData));
```

### 3. طريقة رفع بديلة
- إضافة `uploadSingleImageMultipart()` كبديل للطريقة الأساسية
- النظام يجرب الطريقة الأولى (base64)، وإذا فشلت يجرب الثانية (multipart)

## خطوات التشخيص

### 1. تحقق من logs Flutter
في Android Studio أو VS Code، ابحث عن:
```
I/flutter: Uploading image - Size: XXXX bytes
I/flutter: Base64 length: XXXX
I/flutter: Upload failed with status: 400, body: {...}
```

### 2. تحقق من logs الخادم
في cPanel أو server logs، ابحث عن:
```
POST data keys: image, project_id, category, timestamp
Content length: XXXX
Max post size: 8M
Base64 data length: XXXX
```

### 3. المشاكل المحتملة وحلولها

#### أ) مشكلة حجم البيانات
**العلامات:**
- `Content length` أكبر من `Max post size`
- `Base64 data length` كبير جداً

**الحل:**
```php
// في php.ini أو .htaccess
post_max_size = 32M
upload_max_filesize = 16M
max_execution_time = 300
memory_limit = 256M
```

#### ب) مشكلة تشفير البيانات
**العلامات:**
- `Base64 decode failed or empty result`
- `POST data keys` لا يحتوي على 'image'

**الحل:**
- التأكد من صحة تشفير base64
- التحقق من encoding البيانات

#### ج) مشكلة أذونات الخادم
**العلامات:**
- `فشل في إنشاء الملف المؤقت`
- خطأ في `file_put_contents`

**الحل:**
```bash
# تعيين أذونات مجلد temp
chmod 755 /tmp
# أو تغيير مجلد temp في PHP
```

#### د) مشكلة CORS
**العلامات:**
- الطلب لا يصل للخادم
- خطأ في network

**الحل:**
```php
// في بداية upload_image.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
```

## اختبار الطرق المختلفة

### 1. اختبار مباشر للخادم
```bash
# اختبار بـ curl
curl -X POST https://bhbgroup.me/api/upload_image.php \
  -F "image=@test.jpg" \
  -F "project_id=test" \
  -F "category=test"
```

### 2. اختبار من Flutter
```dart
// في Developer Console
// ابحث عن الرسائل التشخيصية الجديدة
```

### 3. اختبار الطريقة البديلة
```dart
// النظام سيجرب تلقائياً:
// 1. base64 upload
// 2. multipart upload (إذا فشلت الأولى)
```

## معلومات إضافية للتشخيص

### التحقق من إعدادات PHP
```php
<?php
phpinfo();
// ابحث عن:
// - post_max_size
// - upload_max_filesize
// - max_execution_time
// - memory_limit
?>
```

### التحقق من مجلدات التخزين
```bash
# التأكد من وجود المجلدات
ls -la /path/to/uploads/
# التأكد من الأذونات
ls -la /tmp/
```

### التحقق من error logs
```bash
# في cPanel File Manager
tail -f /path/to/error_log

# أو في terminal
tail -f /var/log/apache2/error.log
```

## الخطوات التالية للإصلاح

1. **جرب الرفع مرة أخرى** وراقب logs Flutter
2. **تحقق من logs الخادم** لفهم سبب الفشل
3. **طبق الحلول المناسبة** بناءً على الأخطاء المكتشفة
4. **اختبر الطريقة البديلة** (multipart) إذا فشلت base64

## معلومات الاتصال بالدعم الفني

إذا استمرت المشكلة، قدم هذه المعلومات:
- Flutter Console logs
- Server error logs  
- نتائج `phpinfo()`
- حجم الصور المحاولة رفعها
- نوع الخادم وإصدار PHP
