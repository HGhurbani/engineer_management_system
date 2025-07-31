
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
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['image_url'])) {
        throw new Exception('رابط الصورة مطلوب');
    }
    
    $imageUrl = $input['image_url'];
    $baseUrl = 'https://bhbgroup.me';
    
    // التحقق من أن الرابط ينتمي لموقعنا
    if (strpos($imageUrl, $baseUrl) !== 0) {
        throw new Exception('رابط غير صحيح');
    }
    
    // استخراج مسار الملف
    $relativePath = str_replace($baseUrl, '', $imageUrl);
    $filePath = '..' . $relativePath;
    
    // التحقق من وجود الملف وحذفه
    if (file_exists($filePath)) {
        if (unlink($filePath)) {
            echo json_encode(['success' => true, 'message' => 'تم حذف الصورة بنجاح']);
        } else {
            throw new Exception('فشل في حذف الملف');
        }
    } else {
        echo json_encode(['success' => true, 'message' => 'الملف غير موجود']);
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
