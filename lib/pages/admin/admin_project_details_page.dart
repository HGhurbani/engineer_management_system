import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // لفتح روابط الواتساب والبريد
import 'package:share_plus/share_plus.dart'; // للمشاركة

// Constants for consistent styling and text (يمكنك وضعها في ملف منفصل)
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح
  static const Color deleteColor = Colors.redAccent; // لون لزر الحذف
  static const Color warningColor = Color(0xFFFFA000); // لون للتحذير (برتقالي أغمق)
  static const Color infoColor = Color(0xFF00BCD4); // لون للمعلومات (أزرق فاتح)

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

// افتراض: طريقة للحصول على دور المستخدم
// في تطبيقك الحقيقي، ستستبدل هذا بالوصول إلى نظام المصادقة الخاص بك
bool isEngineer = true; // اجعلها true للاختبار كمهندس، و false كإداري
bool isAdmin = true; // اجعلها true إذا كان المستخدم إداريًا

// Define the three default Electromechanical phases
const List<Map<String, dynamic>> defaultElectromechanicalPhases = [
  {'number': 1, 'name': 'مرحلة أعمال التصميم'},
  {'number': 2, 'name': 'مرحلة أعمال التركيب والتنفيذ'},
  {'number': 3, 'name': 'مرحلة الاختبار والتسليم'},
];

class AdminProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const AdminProjectDetailsPage({super.key, required this.projectId});

  @override
  State<AdminProjectDetailsPage> createState() => _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> {
  Key _projectFutureBuilderKey = UniqueKey();

  // URL الخاص بسكريبت PHP لرفع الصور
  static const String UPLOAD_URL = 'https://creditphoneqatar.com/eng-app/upload_image.php';

  @override
  void initState() {
    super.initState();
    // No need to create phases here if it's done during project creation
    // _createDefaultPhasesIfNeeded(); // This would be called when a project is first created
  }

  // Helper function to show a success SnackBar
  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper function to show an error SnackBar
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper function to show an info SnackBar
  void _showInfoSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.infoColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper function for input decoration
  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: AppConstants.primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
        borderSide: const BorderSide(color: AppConstants.accentColor, width: 2),
      ),
    );
  }

  // Helper method for building info rows in the summary card
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              textDirection: TextDirection.rtl, // لضمان محاذاة النص داخل RichText
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                  ),
                  TextSpan(
                    text: ' $value',
                    style: TextStyle(
                      fontSize: 16,
                      color: valueColor ?? AppConstants.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for displaying images within phase details
  Widget _buildImageSection(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink(); // لا تعرض القسم إذا لم تكن هناك صورة
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textColor),
        ),
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200, // حافظ على نفس الارتفاع حتى لو فشلت الصورة
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      const Text('فشل تحميل الصورة', style: TextStyle(color: AppConstants.secondaryTextColor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.itemSpacing),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // NEW: Function to create default phases when a new project is created
  // This function should be called ONCE when a new project document is added to Firestore.
  // Example: In your project creation logic (e.g., in an `_addNewProject` function)
  // ----------------------------------------------------------------------
  static Future<void> createDefaultPhasesForProject(String projectId) async {
    final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
    final batch = FirebaseFirestore.instance.batch();

    // Set initial project currentPhaseName and currentStage
    batch.update(projectRef, {
      'currentStage': defaultElectromechanicalPhases[0]['number'],
      'currentPhaseName': defaultElectromechanicalPhases[0]['name'],
    });

    for (var phaseData in defaultElectromechanicalPhases) {
      batch.set(projectRef.collection('phases').doc(), {
        'number': phaseData['number'],
        'name': phaseData['name'], // Store the predefined phase name
        'completed': false,
        'note': '',
        'imageUrl': null,
        'image360Url': null,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    print('Default Electromechanical phases created for project: $projectId');
  }

  // ----------------------------------------------------------------------
  // MODIFIED: Function to update project's currentStage and currentPhaseName
  // This needs to be called after any phase update that changes completion status.
  // ----------------------------------------------------------------------
  Future<void> _updateProjectCurrentPhaseStatus() async {
    try {
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
      final phasesSnapshot = await projectRef.collection('phases').orderBy('number').get();

      // Find the first non-completed phase or the last completed phase if all are done
      int? nextStageNumber;
      String? nextPhaseName;
      bool allPhasesCompleted = true;

      for (var doc in phasesSnapshot.docs) {
        final phaseData = doc.data();
        if (phaseData['completed'] == false) {
          nextStageNumber = phaseData['number'] as int?;
          nextPhaseName = phaseData['name'] as String?;
          allPhasesCompleted = false;
          break; // Found the next incomplete phase
        }
      }

      if (allPhasesCompleted) {
        // If all phases are completed, set to the last phase's number and name, and status to 'مكتمل'
        final lastPhase = phasesSnapshot.docs.last.data();
        nextStageNumber = lastPhase['number'] as int?;
        nextPhaseName = lastPhase['name'] as String?;
        await projectRef.update({
          'currentStage': nextStageNumber,
          'currentPhaseName': nextPhaseName,
          'status': 'مكتمل', // Set project status to completed
        });
      } else if (nextStageNumber != null && nextPhaseName != null) {
        // If there's an incomplete phase, set project to its number and name, and status to 'نشط'
        await projectRef.update({
          'currentStage': nextStageNumber,
          'currentPhaseName': nextPhaseName,
          'status': 'نشط', // Set project status to active
        });
      } else {
        // Fallback for cases where no phases are found or initial state (should ideally not happen with default phases)
        await projectRef.update({
          'currentStage': 1,
          'currentPhaseName': defaultElectromechanicalPhases[0]['name'],
          'status': 'نشط',
        });
      }

      // Refresh the UI to reflect changes
      if (mounted) {
        setState(() {
          _projectFutureBuilderKey = UniqueKey();
        });
      }
    } catch (e) {
      print('Error updating project current phase status: $e');
      _showErrorSnackBar(context, 'فشل تحديث حالة المشروع: $e');
    }
  }

  // ----------------------------------------------------
  // دالة تحديث المرحلة الرئيسية (MODIFIED)
  // ----------------------------------------------------
  Future<void> _updatePhase(
      String phaseDocId, Map<String, dynamic> currentData) async {
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    final noteController = TextEditingController(text: currentData['note'] ?? '');
    bool completed = currentData['completed'] ?? false;
    bool hasSubPhases = currentData['hasSubPhases'] ?? false;
    final bool initialCompletedState = completed;
    // initialPhaseName is kept for comparison if we were allowing name changes by engineer
    // but now engineers cannot change predefined names, so it's less critical here.
    // final String initialPhaseName = currentData['name'] ?? '';

    String? imageUrl = currentData['imageUrl'] as String?;
    String? image360Url = currentData['image360Url'] as String?;
    final int phaseNumber = currentData['number'];

    // دالة لالتقاط الصورة ورفعها إلى خادم PHP
    Future<void> pickAndUploadImage(bool is360Image, Function(VoidCallback) setDialogState) async {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        try {
          _showInfoSnackBar(context, 'جاري رفع الصورة...');

          var request = http.MultipartRequest('POST', Uri.parse(UPLOAD_URL));
          request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['status'] == 'success') {
              String uploadedImageUrl = responseData['url'];
              setDialogState(() {
                if (is360Image) {
                  image360Url = uploadedImageUrl;
                } else {
                  imageUrl = uploadedImageUrl;
                }
              });
              _showSuccessSnackBar(context, 'تم رفع الصورة بنجاح.');
            } else {
              _showErrorSnackBar(context, 'فشل الرفع: ${responseData['message']}');
            }
          } else {
            _showErrorSnackBar(context, 'خطأ في الخادم: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          _showErrorSnackBar(context, 'فشل رفع الصورة: $e');
        }
      } else {
        _showInfoSnackBar(context, 'لم يتم التقاط أي صورة.');
      }
    }

    // تحديد ما إذا كان يمكن تحرير الحقول: المهندس لا يمكنه التعديل إذا كانت مكتملة، الإداري يمكنه دائمًا.
    // اسم المرحلة يمكن تعديله فقط بواسطة الإداري.
    bool canEditGeneral = isAdmin || !(completed && isEngineer);
    bool canEditName = isAdmin; // Only admin can change phase name

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: Text(
                'تعديل المرحلة $phaseNumber: ${nameController.text}', // Display current name
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // اسم المرحلة
                    TextField(
                      controller: nameController,
                      decoration: _inputDecoration('اسم المرحلة', Icons.label),
                      enabled: canEditName, // Only admin can edit name
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // ملاحظات المرحلة
                    TextField(
                      controller: noteController,
                      decoration: _inputDecoration('ملاحظات المرحلة', Icons.notes),
                      maxLines: 3,
                      enabled: canEditGeneral,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // حالة الاكتمال
                    Row(
                      children: [
                        Checkbox(
                          value: completed,
                          onChanged: canEditGeneral
                              ? (bool? value) {
                            setDialogState(() {
                              completed = value ?? false;
                            });
                          }
                              : null,
                          activeColor: AppConstants.successColor,
                        ),
                        Text(
                          'مكتملة',
                          style: TextStyle(
                              fontSize: 16,
                              color: canEditGeneral
                                  ? AppConstants.textColor
                                  : AppConstants.secondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // هل تحتوي على مراحل فرعية؟ (للإداري والمهندس إذا كانت غير مكتملة)
                    if (isAdmin || (!completed && isEngineer))
                      Row(
                        children: [
                          Checkbox(
                            value: hasSubPhases,
                            onChanged: canEditGeneral // Engineers can only change if not completed
                                ? (bool? value) {
                              setDialogState(() {
                                hasSubPhases = value ?? false;
                              });
                            }
                                : null,
                            activeColor: AppConstants.accentColor,
                          ),
                          Text(
                            'تحتوي على مراحل فرعية',
                            style: TextStyle(
                                fontSize: 16,
                                color: canEditGeneral
                                    ? AppConstants.textColor
                                    : AppConstants.secondaryTextColor),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // زر التقاط ورفع الصورة
                    if (canEditGeneral)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (innerContext) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                title: const Text('نوع الصورة'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.image),
                                      title: const Text('صورة عادية'),
                                      onTap: () {
                                        Navigator.pop(innerContext);
                                        pickAndUploadImage(false, setDialogState);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.threed_rotation),
                                      title: const Text('صورة 360°'),
                                      onTap: () {
                                        Navigator.pop(innerContext);
                                        pickAndUploadImage(true, setDialogState);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text(
                          'التقاط ورفع صورة',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentColor),
                      ),
                    const SizedBox(height: AppConstants.itemSpacing),

                    // عرض الصور الموجودة مع زر الحذف
                    Text(
                      'الصور المرفوعة:',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textColor),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing / 2),
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('صورة عادية:'),
                          const SizedBox(height: 8),
                          _buildImageSection('', imageUrl), // Use the helper
                          if (canEditGeneral)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_forever,
                                  color: AppConstants.deleteColor),
                              label: const Text('حذف الصورة'),
                              onPressed: () {
                                setDialogState(() {
                                  imageUrl = null;
                                });
                              },
                            ),
                          const SizedBox(height: AppConstants.itemSpacing / 2),
                        ],
                      ),
                    if (image360Url != null && image360Url!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('صورة 360°:'),
                          const SizedBox(height: 8),
                          _buildImageSection('', image360Url), // Use the helper
                          if (canEditGeneral)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_forever,
                                  color: AppConstants.deleteColor),
                              label: const Text('حذف صورة 360°'),
                              onPressed: () {
                                setDialogState(() {
                                  image360Url = null;
                                });
                              },
                            ),
                          const SizedBox(height: AppConstants.itemSpacing / 2),
                        ],
                      ),
                    if ((imageUrl == null || imageUrl!.isEmpty) && (image360Url == null || image360Url!.isEmpty))
                      Text(
                        'لا توجد صور مرفوعة لهذه المرحلة.',
                        style: TextStyle(
                            fontSize: 15,
                            color: AppConstants.secondaryTextColor
                                .withOpacity(0.7)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء',
                      style: TextStyle(color: AppConstants.secondaryTextColor)),
                ),
                if (canEditGeneral || canEditName) // Save button if anything can be edited
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('projects')
                            .doc(widget.projectId)
                            .collection('phases')
                            .doc(phaseDocId)
                            .update({
                          'name': nameController.text.trim(), // تحديث اسم المرحلة
                          'note': noteController.text.trim(),
                          'completed': completed,
                          'hasSubPhases': hasSubPhases, // تحديث وجود مراحل فرعية
                          'imageUrl': imageUrl,
                          'image360Url': image360Url,
                        });

                        // إذا تغيرت حالة اكتمال المرحلة، قم بتحديث currentStage للمشروع
                        if (initialCompletedState != completed) {
                          await _updateProjectCurrentPhaseStatus();
                        }

                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(context, 'تم تحديث المرحلة $phaseNumber بنجاح.');
                      } catch (e) {
                        _showErrorSnackBar(context, 'فشل تحديث المرحلة: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius / 2),
                      ),
                    ),
                    child:
                    const Text('حفظ', style: TextStyle(color: Colors.white)),
                  ),
                if (completed && isEngineer) // زر مشاركة التقرير للمهندس فقط عند اكتمال المرحلة
                  ElevatedButton(
                    onPressed: () => _showShareReportOptions(currentData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                      ),
                    ),
                    child: const Text('مشاركة التقرير', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // دالة تحديث المرحلة الفرعية
  // ----------------------------------------------------
  Future<void> _updateSubPhase(
      String phaseDocId, String subPhaseDocId, Map<String, dynamic> currentSubData) async {
    final nameController = TextEditingController(text: currentSubData['name'] ?? '');
    final noteController = TextEditingController(text: currentSubData['note'] ?? '');
    bool completed = currentSubData['completed'] ?? false;

    String? imageUrl = currentSubData['imageUrl'] as String?;
    String? image360Url = currentSubData['image360Url'] as String?;

    // تحديد ما إذا كان يمكن تحرير الحقول: المهندس لا يمكنه التعديل إذا كانت مكتملة، الإداري يمكنه دائمًا.
    bool canEdit = isAdmin || !(completed && isEngineer);

    // دالة لالتقاط الصورة ورفعها إلى خادم PHP (نفس الدالة المستخدمة للمرحلة الرئيسية)
    Future<void> pickAndUploadImage(bool is360Image, Function(VoidCallback) setDialogState) async {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        try {
          _showInfoSnackBar(context, 'جاري رفع الصورة...');

          var request = http.MultipartRequest('POST', Uri.parse(UPLOAD_URL));
          request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['status'] == 'success') {
              String uploadedImageUrl = responseData['url'];
              setDialogState(() {
                if (is360Image) {
                  image360Url = uploadedImageUrl;
                } else {
                  imageUrl = uploadedImageUrl;
                }
              });
              _showSuccessSnackBar(context, 'تم رفع الصورة بنجاح.');
            } else {
              _showErrorSnackBar(context, 'فشل الرفع: ${responseData['message']}');
            }
          } else {
            _showErrorSnackBar(context, 'خطأ في الخادم: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          _showErrorSnackBar(context, 'فشل رفع الصورة: $e');
        }
      } else {
        _showInfoSnackBar(context, 'لم يتم التقاط أي صورة.');
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: Text(
                'تعديل المرحلة الفرعية: ${nameController.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: _inputDecoration('اسم المرحلة الفرعية', Icons.label_important),
                      enabled: canEdit,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    TextField(
                      controller: noteController,
                      decoration: _inputDecoration('ملاحظات المرحلة الفرعية', Icons.notes),
                      maxLines: 3,
                      enabled: canEdit,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Row(
                      children: [
                        Checkbox(
                          value: completed,
                          onChanged: canEdit
                              ? (bool? value) {
                            setDialogState(() {
                              completed = value ?? false;
                            });
                          }
                              : null,
                          activeColor: AppConstants.successColor,
                        ),
                        Text(
                          'مكتملة',
                          style: TextStyle(
                              fontSize: 16,
                              color: canEdit
                                  ? AppConstants.textColor
                                  : AppConstants.secondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    if (canEdit)
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (innerContext) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                title: const Text('نوع الصورة'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.image),
                                      title: const Text('صورة عادية'),
                                      onTap: () {
                                        Navigator.pop(innerContext);
                                        pickAndUploadImage(false, setDialogState);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.threed_rotation),
                                      title: const Text('صورة 360°'),
                                      onTap: () {
                                        Navigator.pop(innerContext);
                                        pickAndUploadImage(true, setDialogState);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text(
                          'التقاط ورفع صورة',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentColor),
                      ),
                    const SizedBox(height: AppConstants.itemSpacing),

                    Text(
                      'الصور المرفوعة:',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textColor),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing / 2),
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('صورة عادية:'),
                          const SizedBox(height: 8),
                          _buildImageSection('', imageUrl), // Use the helper
                          if (canEdit)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_forever,
                                  color: AppConstants.deleteColor),
                              label: const Text('حذف الصورة'),
                              onPressed: () {
                                setDialogState(() {
                                  imageUrl = null;
                                });
                              },
                            ),
                          const SizedBox(height: AppConstants.itemSpacing / 2),
                        ],
                      ),
                    if (image360Url != null && image360Url!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('صورة 360°:'),
                          const SizedBox(height: 8),
                          _buildImageSection('', image360Url), // Use the helper
                          if (canEdit)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_forever,
                                  color: AppConstants.deleteColor),
                              label: const Text('حذف صورة 360°'),
                              onPressed: () {
                                setDialogState(() {
                                  image360Url = null;
                                });
                              },
                            ),
                          const SizedBox(height: AppConstants.itemSpacing / 2),
                        ],
                      ),
                    if ((imageUrl == null || imageUrl!.isEmpty) && (image360Url == null || image360Url!.isEmpty))
                      Text(
                        'لا توجد صور مرفوعة لهذه المرحلة الفرعية.',
                        style: TextStyle(
                            fontSize: 15,
                            color: AppConstants.secondaryTextColor
                                .withOpacity(0.7)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء',
                      style: TextStyle(color: AppConstants.secondaryTextColor)),
                ),
                if (canEdit)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('projects')
                            .doc(widget.projectId)
                            .collection('phases')
                            .doc(phaseDocId)
                            .collection('subPhases')
                            .doc(subPhaseDocId)
                            .update({
                          'name': nameController.text.trim(),
                          'note': noteController.text.trim(),
                          'completed': completed,
                          'imageUrl': imageUrl,
                          'image360Url': image360Url,
                        });

                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(context, 'تم تحديث المرحلة الفرعية بنجاح.');
                      } catch (e) {
                        _showErrorSnackBar(context, 'فشل تحديث المرحلة الفرعية: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius / 2),
                      ),
                    ),
                    child:
                    const Text('حفظ', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // دالة لإضافة مرحلة فرعية جديدة
  // ----------------------------------------------------
  Future<void> _addSubPhase(String phaseDocId) async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة مرحلة فرعية جديدة'),
            content: TextField(
              controller: nameController,
              decoration: _inputDecoration('اسم المرحلة الفرعية', Icons.add_box),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    _showErrorSnackBar(context, 'الرجاء إدخال اسم المرحلة الفرعية.');
                    return;
                  }
                  try {
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('phases')
                        .doc(phaseDocId)
                        .collection('subPhases')
                        .add({
                      'name': nameController.text.trim(),
                      'note': '',
                      'completed': false,
                      'imageUrl': null,
                      'image360Url': null,
                      'timestamp': FieldValue.serverTimestamp(), // لتحديد ترتيب المراحل الفرعية
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _showSuccessSnackBar(context, 'تمت إضافة المرحلة الفرعية بنجاح.');
                  } catch (e) {
                    _showErrorSnackBar(context, 'فشل إضافة المرحلة الفرعية: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor),
                child: const Text('إضافة', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------------------------------
  // دالة لحذف مرحلة فرعية
  // ----------------------------------------------------
  Future<void> _deleteSubPhase(String phaseDocId, String subPhaseDocId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد أنك تريد حذف هذه المرحلة الفرعية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deleteColor),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('phases')
            .doc(phaseDocId)
            .collection('subPhases')
            .doc(subPhaseDocId)
            .delete();
        _showSuccessSnackBar(context, 'تم حذف المرحلة الفرعية بنجاح.');
      } catch (e) {
        _showErrorSnackBar(context, 'فشل حذف المرحلة الفرعية: $e');
      }
    }
  }

  // ----------------------------------------------------
  // دالة لعرض خيارات مشاركة التقرير
  // ----------------------------------------------------
  void _showShareReportOptions(Map<String, dynamic> phaseData) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مشاركة تقرير المرحلة ${phaseData['number']}: ${phaseData['name']}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textColor,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.message, color: AppConstants.primaryColor),
                  title: const Text('مشاركة عبر الرسائل النصية'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareReportViaSMS(phaseData);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: AppConstants.primaryColor),
                  title: const Text('مشاركة عبر البريد الإلكتروني'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareReportViaEmail(phaseData);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded, color: AppConstants.successColor),
                  title: const Text('مشاركة عبر واتساب'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareReportViaWhatsApp(phaseData);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to generate report text
  String _generateReportText(Map<String, dynamic> phaseData) {
    String report = 'تقرير مرحلة المشروع:\n\n';
    report += 'اسم المشروع: (سيتم جلب اسم المشروع تلقائياً)\n'; // Placeholder for project name
    report += 'المرحلة: ${phaseData['number']} - ${phaseData['name']}\n';
    report += 'الحالة: مكتملة ✅\n';
    if (phaseData['note'] != null && phaseData['note'].isNotEmpty) {
      report += 'الملاحظات: ${phaseData['note']}\n';
    }
    if (phaseData['imageUrl'] != null && phaseData['imageUrl'].isNotEmpty) {
      report += 'رابط الصورة: ${phaseData['imageUrl']}\n';
    }
    if (phaseData['image360Url'] != null && phaseData['image360Url'].isNotEmpty) {
      report += 'رابط صورة 360°: ${phaseData['image360Url']}\n';
    }
    report += '\nللمزيد من التفاصيل، يرجى زيارة التطبيق.';
    return report;
  }

  Future<void> _shareReportViaSMS(Map<String, dynamic> phaseData) async {
    final String reportText = _generateReportText(phaseData);
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      queryParameters: <String, String>{
        'body': reportText,
      },
    );

    if (await canLaunchUrl(smsLaunchUri)) {
      await launchUrl(smsLaunchUri);
    } else {
      _showErrorSnackBar(context, 'لا يمكن فتح تطبيق الرسائل.');
    }
  }

  Future<void> _shareReportViaEmail(Map<String, dynamic> phaseData) async {
    final String reportText = _generateReportText(phaseData);
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: '', // Optionally pre-fill email address
      queryParameters: {
        'subject': 'تقرير مرحلة مشروع: ${phaseData['name']}',
        'body': reportText,
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showErrorSnackBar(context, 'لا يمكن فتح تطبيق البريد الإلكتروني.');
    }
  }

  Future<void> _shareReportViaWhatsApp(Map<String, dynamic> phaseData) async {
    final String reportText = _generateReportText(phaseData);
    final String encodedText = Uri.encodeComponent(reportText);
    final Uri whatsappLaunchUri = Uri.parse('whatsapp://send?text=$encodedText');

    try {
      if (await canLaunchUrl(whatsappLaunchUri)) {
        await launchUrl(whatsappLaunchUri);
      } else {
        // Fallback for web or if WhatsApp isn't installed
        final Uri webWhatsappUri = Uri.parse('https://wa.me/?text=$encodedText');
        if (await canLaunchUrl(webWhatsappUri)) {
          await launchUrl(webWhatsappUri);
        } else {
          _showErrorSnackBar(context, 'واتساب غير مثبت أو لا يمكن الوصول إليه.');
        }
      }
    } catch (e) {
      _showErrorSnackBar(context, 'فشل فتح واتساب: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // Set global text direction to RTL
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'تفاصيل المشروع',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: AppConstants.primaryColor,
          elevation: 4,
          centerTitle: true,
        ),
        body: FutureBuilder<DocumentSnapshot>(
          key: _projectFutureBuilderKey, // Use key to force rebuild
          future: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (projectSnapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${projectSnapshot.error}',
                  style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!projectSnapshot.hasData || !projectSnapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sentiment_dissatisfied, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Text(
                      'المشروع غير موجود أو تم حذفه.',
                      style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final projectData = projectSnapshot.data!.data() as Map<String, dynamic>;
            final projectName = projectData['name'] as String? ?? 'مشروع غير مسمى';
            final engineerName = projectData['engineerName'] as String? ?? 'غير محدد';
            final projectStatus = projectData['status'] as String? ?? 'غير محدد';
            final generalNotes = projectData['generalNotes'] as String? ?? '';
            final currentStageNumber = projectData['currentStage'] as int? ?? 0;
            final currentPhaseName = projectData['currentPhaseName'] as String? ?? 'غير محددة';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Summary Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    color: AppConstants.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            projectName,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(height: AppConstants.itemSpacing / 2),
                          _buildInfoRow(Icons.engineering, 'المهندس المسؤول:', engineerName),
                          _buildInfoRow(Icons.info_outline, 'حالة المشروع:', projectStatus,
                              valueColor: (projectStatus == 'نشط')
                                  ? AppConstants.successColor
                                  : (projectStatus == 'مكتمل')
                                  ? Colors.blue
                                  : AppConstants.warningColor),
                          _buildInfoRow(Icons.trending_up, 'المرحلة الحالية:', '$currentStageNumber - $currentPhaseName'),
                          if (generalNotes.isNotEmpty) ...[
                            const Divider(height: AppConstants.itemSpacing * 2, thickness: 1),
                            Text(
                              'ملاحظات عامة من المهندس:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textColor,
                              ),
                            ),
                            const SizedBox(height: AppConstants.itemSpacing / 2),
                            Text(
                              generalNotes,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppConstants.secondaryTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.itemSpacing * 1.5),

                  Text(
                    'مراحل المشروع:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('phases')
                        .orderBy('number')
                        .snapshots(),
                    builder: (context, phaseSnapshot) {
                      if (phaseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                      }
                      if (phaseSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'حدث خطأ في تحميل المراحل: ${phaseSnapshot.error}',
                            style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!phaseSnapshot.hasData || phaseSnapshot.data!.docs.isEmpty) {
                        // This case should ideally not happen if createDefaultPhasesForProject is called
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.construction, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                              const SizedBox(height: AppConstants.itemSpacing),
                              Text(
                                'لا توجد مراحل محددة لهذا المشروع. الرجاء التواصل مع الإدارة.',
                                style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final phases = phaseSnapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: phases.length,
                        itemBuilder: (context, index) {
                          final phase = phases[index];
                          final data = phase.data() as Map<String, dynamic>;
                          final int number = data['number'] as int? ?? (index + 1);
                          final String name = data['name'] as String? ?? 'مرحلة غير مسمى';
                          final String note = data['note'] as String? ?? '';
                          final bool completed = data['completed'] as bool? ?? false;
                          final bool hasSubPhases = data['hasSubPhases'] as bool? ?? false;
                          final String? imageUrl = data['imageUrl'] as String?;
                          final String? image360Url = data['image360Url'] as String?;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                            ),
                            child: ExpansionTile(
                              collapsedBackgroundColor: completed
                                  ? AppConstants.successColor.withOpacity(0.1)
                                  : AppConstants.warningColor.withOpacity(0.1),
                              backgroundColor: AppConstants.cardColor,
                              leading: CircleAvatar(
                                backgroundColor:
                                completed ? AppConstants.successColor : AppConstants.primaryColor,
                                child: Text(
                                  number.toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                'المرحلة $number: $name',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textColor,
                                ),
                              ),
                              subtitle: Text(
                                completed ? 'مكتملة ✅' : 'قيد التقدم ⏳',
                                style: TextStyle(
                                  color: completed ? AppConstants.successColor : AppConstants.warningColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: isAdmin || (isEngineer && !completed)
                                  ? IconButton(
                                icon: const Icon(Icons.edit, color: AppConstants.accentColor),
                                onPressed: () => _updatePhase(phase.id, data),
                              )
                                  : null, // No edit button if completed and engineer
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppConstants.padding, vertical: AppConstants.itemSpacing / 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (note.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'الملاحظات:',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppConstants.textColor),
                                            ),
                                            Text(
                                              note,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  color: AppConstants.secondaryTextColor),
                                            ),
                                            const SizedBox(height: AppConstants.itemSpacing),
                                          ],
                                        ),
                                      if (imageUrl != null && imageUrl.isNotEmpty)
                                        _buildImageSection('صورة عادية:', imageUrl),
                                      if (image360Url != null && image360Url.isNotEmpty)
                                        _buildImageSection('صورة 360°:', image360Url),
                                      if (note.isEmpty &&
                                          (imageUrl == null || imageUrl.isEmpty) &&
                                          (image360Url == null || image360Url.isEmpty))
                                        Text(
                                          'لا توجد تفاصيل إضافية لهذه المرحلة.',
                                          style: TextStyle(
                                              fontSize: 15,
                                              color: AppConstants.secondaryTextColor.withOpacity(0.7)),
                                        ),
                                      // Sub-phases section
                                      if (hasSubPhases)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(height: AppConstants.itemSpacing * 2, thickness: 1),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'المراحل الفرعية:',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppConstants.textColor),
                                                ),
                                                if (isAdmin || isEngineer) // Only engineer/admin can add sub-phases
                                                  ElevatedButton.icon(
                                                    onPressed: () => _addSubPhase(phase.id),
                                                    icon: const Icon(Icons.add, color: Colors.white),
                                                    label: const Text('إضافة فرعية', style: TextStyle(color: Colors.white)),
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppConstants.accentColor),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: AppConstants.itemSpacing),
                                            StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('projects')
                                                  .doc(widget.projectId)
                                                  .collection('phases')
                                                  .doc(phase.id)
                                                  .collection('subPhases')
                                                  .orderBy('timestamp')
                                                  .snapshots(),
                                              builder: (context, subPhaseSnapshot) {
                                                if (subPhaseSnapshot.connectionState == ConnectionState.waiting) {
                                                  return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                                                }
                                                if (subPhaseSnapshot.hasError) {
                                                  return Text('خطأ في تحميل المراحل الفرعية: ${subPhaseSnapshot.error}', style: TextStyle(color: AppConstants.errorColor));
                                                }
                                                if (!subPhaseSnapshot.hasData || subPhaseSnapshot.data!.docs.isEmpty) {
                                                  return Text(
                                                    'لا توجد مراحل فرعية.',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        color: AppConstants.secondaryTextColor.withOpacity(0.7)),
                                                  );
                                                }

                                                final subPhases = subPhaseSnapshot.data!.docs;
                                                return ListView.builder(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemCount: subPhases.length,
                                                  itemBuilder: (context, subIndex) {
                                                    final subPhase = subPhases[subIndex];
                                                    final subData = subPhase.data() as Map<String, dynamic>;
                                                    final String subName = subData['name'] as String? ?? 'مرحلة فرعية غير مسمى';
                                                    final bool subCompleted = subData['completed'] as bool? ?? false;

                                                    return ListTile(
                                                      leading: Icon(
                                                        subCompleted ? Icons.check_circle : Icons.radio_button_off,
                                                        color: subCompleted ? AppConstants.successColor : AppConstants.warningColor,
                                                      ),
                                                      title: Text(
                                                        subName,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: subCompleted ? AppConstants.successColor : AppConstants.textColor,
                                                          decoration: subCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                                                        ),
                                                      ),
                                                      trailing: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (isAdmin || (isEngineer && !subCompleted)) // Only engineer/admin can edit if not completed
                                                            IconButton(
                                                              icon: const Icon(Icons.edit, color: AppConstants.accentColor),
                                                              onPressed: () => _updateSubPhase(phase.id, subPhase.id, subData),
                                                            ),
                                                          if (isAdmin) // Only admin can delete sub-phases
                                                            IconButton(
                                                              icon: const Icon(Icons.delete, color: AppConstants.deleteColor),
                                                              onPressed: () => _deleteSubPhase(phase.id, subPhase.id),
                                                            ),
                                                        ],
                                                      ),
                                                      onTap: isAdmin || isEngineer
                                                          ? () => _updateSubPhase(phase.id, subPhase.id, subData)
                                                          : null,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}