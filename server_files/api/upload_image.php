
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
    // التحقق من وجود الصورة
    if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('لم يتم رفع الصورة بشكل صحيح');
    }
    
    $uploadedFile = $_FILES['image'];
    $projectId = $_POST['project_id'] ?? 'general';
    $category = $_POST['category'] ?? 'uploads';
    $timestamp = $_POST['timestamp'] ?? time();
    
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
    
} catch (Exception $e) {
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
