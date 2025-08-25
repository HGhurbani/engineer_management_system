import 'package:flutter/material.dart';
import '../../theme/app_constants.dart';
import '../../utils/image_migration_service.dart';

class ImageMigrationPage extends StatefulWidget {
  const ImageMigrationPage({Key? key}) : super(key: key);

  @override
  State<ImageMigrationPage> createState() => _ImageMigrationPageState();
}

class _ImageMigrationPageState extends State<ImageMigrationPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;
  Map<String, dynamic>? _migrationResult;
  // String _selectedProjectId = '';  // غير مستخدم حالياً
  
  @override
  void initState() {
    super.initState();
    _analyzeImages();
  }

  Future<void> _analyzeImages() async {
    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      final result = await ImageMigrationService.analyzeAllImages();
      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      _showErrorSnackBar('حدث خطأ أثناء تحليل الصور: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _migrateAllImages() async {
    final confirmed = await _showConfirmationDialog(
      'ترحيل جميع الصور',
      'هل أنت متأكد من ترحيل جميع الصور من Firebase إلى الاستضافة الخاصة؟\n\nهذه العملية قد تستغرق وقتاً طويلاً.',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _migrationResult = null;
    });

    try {
      final result = await ImageMigrationService.migrateAllImages();
      setState(() {
        _migrationResult = result;
      });
      
      if (result['success'] == true) {
        _showSuccessSnackBar(result['message'] ?? 'تم الترحيل بنجاح');
        _analyzeImages(); // إعادة تحليل البيانات
      } else {
        _showErrorSnackBar(result['message'] ?? 'فشل في الترحيل');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ أثناء الترحيل: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة ترحيل مشروع واحد - يمكن استخدامها لاحقاً
  // Future<void> _migrateProjectImages(String projectId) async { ... }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة ترحيل الصور'),
        backgroundColor: AppConstants.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _analyzeImages,
            tooltip: 'تحديث التحليل',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnalysisSection(),
                  const SizedBox(height: AppConstants.itemSpacing * 2),
                  _buildMigrationSection(),
                  if (_migrationResult != null) ...[
                    const SizedBox(height: AppConstants.itemSpacing * 2),
                    _buildMigrationResultSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAnalysisSection() {
    if (_analysisResult == null) {
      return const Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('جاري تحليل الصور...'),
        ),
      );
    }

    final result = _analysisResult!;
    final hasError = result.containsKey('error');

    if (hasError) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'خطأ في التحليل',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              Text(
                result['error'] ?? 'خطأ غير معروف',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحليل الصور الحالية',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            _buildStatRow('إجمالي الصور:', '${result['total_images'] ?? 0}'),
            _buildStatRow('صور Firebase:', '${result['total_firebase_images'] ?? 0}', 
                color: result['total_firebase_images'] > 0 ? Colors.orange : Colors.green),
            _buildStatRow('صور الاستضافة الخاصة:', '${result['total_custom_hosting_images'] ?? 0}', 
                color: Colors.green),
            if (result['total_unknown_images'] > 0)
              _buildStatRow('صور غير معروفة:', '${result['total_unknown_images']}', 
                  color: Colors.red),
            const Divider(),
            _buildStatRow('إجمالي المشاريع:', '${result['total_projects'] ?? 0}'),
            _buildStatRow('مشاريع تحتاج ترحيل:', '${result['projects_needing_migration'] ?? 0}', 
                color: result['projects_needing_migration'] > 0 ? Colors.orange : Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationSection() {
    if (_analysisResult == null || _analysisResult!.containsKey('error')) {
      return const SizedBox.shrink();
    }

    final needsMigration = _analysisResult!['migration_needed'] == true;
    final firebaseImages = _analysisResult!['total_firebase_images'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'عمليات الترحيل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            if (needsMigration) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingSmall),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: Text(
                        'يوجد $firebaseImages صورة في Firebase تحتاج إلى ترحيل',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _migrateAllImages,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('ترحيل جميع الصور'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingSmall),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: Text(
                        'جميع الصور موجودة في الاستضافة الخاصة',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMigrationResultSection() {
    final result = _migrationResult!;
    final success = result['success'] == true;

    return Card(
      color: success ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                Text(
                  success ? 'نتائج الترحيل الناجح' : 'فشل الترحيل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(
              result['message'] ?? (success ? 'تم الترحيل بنجاح' : 'فشل في الترحيل'),
              style: TextStyle(
                color: success ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            if (success && result['migrated_images'] != null) ...[
              const SizedBox(height: AppConstants.itemSpacing),
              _buildStatRow('الصور المرحلة:', '${result['migrated_images']}'),
              _buildStatRow('إجمالي الصور:', '${result['total_images']}'),
              if (result['successful_projects'] != null)
                _buildStatRow('المشاريع الناجحة:', '${result['successful_projects']}'),
              if (result['failed_projects'] != null && result['failed_projects'] > 0)
                _buildStatRow('المشاريع الفاشلة:', '${result['failed_projects']}', color: Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppConstants.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryLight,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
