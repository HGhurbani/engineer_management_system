
<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

try {
    // إضافة debug information
    error_log('POST data keys: ' . implode(', ', array_keys($_POST)));
    error_log('FILES data: ' . json_encode($_FILES));
    error_log('Content length: ' . ($_SERVER['CONTENT_LENGTH'] ?? 'unknown'));
    error_log('Max post size: ' . ini_get('post_max_size'));
    error_log('Max upload size: ' . ini_get('upload_max_filesize'));
    
    $projectId = $_POST['project_id'] ?? 'general';
    $category = $_POST['category'] ?? 'uploads';
    $timestamp = $_POST['timestamp'] ?? time();
    
    // التحقق من طريقة الرفع (ملف مباشر أو base64)
    if (isset($_POST['image']) && !empty($_POST['image'])) {
        // رفع عبر base64
        $base64Data = $_POST['image'];
        error_log('Base64 data length: ' . strlen($base64Data));
        
        // إزالة header من base64 إذا وُجد
        if (strpos($base64Data, ',') !== false) {
            $base64Data = explode(',', $base64Data)[1];
        }
        
        $imageData = base64_decode($base64Data);
        if ($imageData === false || strlen($imageData) === 0) {
            error_log('Base64 decode failed or empty result');
            throw new Exception('فشل في فك تشفير الصورة');
        }
        
        error_log('Decoded image size: ' . strlen($imageData));
        
        // إنشاء ملف مؤقت
        $tempFile = tempnam(sys_get_temp_dir(), 'upload_');
        if (file_put_contents($tempFile, $imageData) === false) {
            throw new Exception('فشل في إنشاء الملف المؤقت');
        }
        
        $uploadedFile = [
            'tmp_name' => $tempFile,
            'size' => strlen($imageData),
            'name' => 'image.jpg',
            'error' => UPLOAD_ERR_OK
        ];
        
        $isBase64Upload = true;
        error_log('Base64 upload prepared successfully');
        
    } elseif (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        // رفع عبر $_FILES العادي
        $uploadedFile = $_FILES['image'];
        $isBase64Upload = false;
        error_log('File upload detected');
        
    } else {
        error_log('No valid image data found');
        error_log('POST image isset: ' . (isset($_POST['image']) ? 'yes' : 'no'));
        error_log('POST image empty: ' . (empty($_POST['image']) ? 'yes' : 'no'));
        error_log('FILES image exists: ' . (isset($_FILES['image']) ? 'yes' : 'no'));
        throw new Exception('لم يتم رفع الصورة بشكل صحيح');
    }
    
    // التحقق من نوع الملف
    $allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    $fileType = mime_content_type($uploadedFile['tmp_name']);
    
    if (!in_array($fileType, $allowedTypes)) {
        throw new Exception('نوع الملف غير مدعوم');
    }
    
    // التحقق من حجم الملف (حد أقصى 10 ميجابايت)
    $maxSize = 10 * 1024 * 1024;
    if ($uploadedFile['size'] > $maxSize) {
        throw new Exception('حجم الملف كبير جداً');
    }
    
    // إنشاء مجلد التخزين
    $uploadDir = "../uploads/{$category}/{$projectId}/" . date('Y/m/', $timestamp);
    
    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0755, true)) {
            throw new Exception('فشل في إنشاء مجلد التخزين');
        }
    }
    
    // إنشاء اسم ملف فريد
    $fileExtension = pathinfo($uploadedFile['name'], PATHINFO_EXTENSION);
    $fileName = uniqid($timestamp . '_') . '.' . $fileExtension;
    $filePath = $uploadDir . $fileName;
    
    // نقل الملف
    if (!move_uploaded_file($uploadedFile['tmp_name'], $filePath)) {
        throw new Exception('فشل في حفظ الملف');
    }
    
    // إنشاء URL للصورة
    $baseUrl = 'https://bhbgroup.me';
    $imageUrl = $baseUrl . "/uploads/{$category}/{$projectId}/" . date('Y/m/', $timestamp) . $fileName;
    
    // حفظ معلومات الصورة في قاعدة البيانات (اختياري)
    // saveImageMetadata($imageUrl, $projectId, $category, $timestamp);
    
    echo json_encode([
        'success' => true,
        'url' => $imageUrl,
        'file_name' => $fileName,
        'file_size' => $uploadedFile['size'],
        'mime_type' => $fileType
    ]);
    
    // تنظيف الملف المؤقت إذا كان رفع base64
    if (isset($isBase64Upload) && $isBase64Upload && isset($tempFile) && file_exists($tempFile)) {
        unlink($tempFile);
    }
    
} catch (Exception $e) {
    // تنظيف الملف المؤقت في حالة الخطأ
    if (isset($isBase64Upload) && $isBase64Upload && isset($tempFile) && file_exists($tempFile)) {
        unlink($tempFile);
    }
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

// دالة لحفظ معلومات الصورة في قاعدة البيانات (اختياري)
function saveImageMetadata($imageUrl, $projectId, $category, $timestamp) {
    // يمكنك إضافة كود قاعدة البيانات هنا إذا كنت تحتاج لحفظ معلومات الصور
}
?>
