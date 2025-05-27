// lib/pages/admin/admin_project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Import Firebase Auth

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
// تم تعديلها للحصول على الدور الفعلي من Firebase
// bool isEngineer = true; // اجعلها true للاختبار كمهندس، و false كإداري
// bool isAdmin = true; // اجعلها true إذا كان المستخدم إداريًا

// Define the three default Electromechanical phases (THIS IS NO LONGER USED FOR INITIAL CREATION)
// const List<Map<String, dynamic>> defaultElectromechanicalPhases = [
//   {'number': 1, 'name': 'مرحلة أعمال التصميم'},
//   {'number': 2, 'name': 'مرحلة أعمال التركيب والتنفيذ'},
//   {'number': 3, 'name': 'مرحلة الاختبار والتسليم'},
// ];

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

  String? _currentUserRole; // NEW: To store the current user's role

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole(); // NEW: Fetch user role on init
  }

  // NEW: Fetch the current user's role
  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _currentUserRole = userDoc.data()?['role'] as String?;
        });
      }
    }
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
  // NEW: Function to send notifications
  // ----------------------------------------------------------------------
  Future<void> _sendNotification({
    required String projectId,
    required String projectName,
    required String phaseName,
    required String phaseDocId, // Added phaseDocId for direct navigation
    required String notificationType, // 'engineer_assignment', 'phase_completed_admin', 'phase_completed_client'
    String? recipientUid, // Engineer or Client UID
    String? adminUid, // Admin UID (if relevant for sending to admin)
    String? clientUid, // Client UID (if relevant for sending to client)
  }) async {
    try {
      final notificationCollection = FirebaseFirestore.instance.collection('notifications');

      // Get current user (admin who assigns/completes)
      final currentUser = FirebaseAuth.instance.currentUser;
      String senderName = "النظام";
      if (currentUser != null) {
        final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        senderName = senderDoc.data()?['name'] ?? 'مسؤول';
      }

      String title = '';
      String body = '';
      List<String> targetUserIds = [];

      switch (notificationType) {
        case 'engineer_assignment':
          title = 'مرحلة جديدة في مشروعك';
          body = 'تم تعيين المرحلة "$phaseName" في مشروع "$projectName" إليك.';
          if (recipientUid != null) targetUserIds.add(recipientUid);
          break;
        case 'phase_completed_admin':
          title = 'تحديث مشروع: مرحلة مكتملة';
          body = 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة.';
          // Get all admins to notify
          final adminsSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').get();
          for (var adminDoc in adminsSnapshot.docs) {
            targetUserIds.add(adminDoc.id);
          }
          break;
        case 'phase_completed_client':
          title = 'تحديث مشروع: مرحلة مكتملة';
          body = 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة. يمكنك الآن مراجعتها.';
          if (recipientUid != null) targetUserIds.add(recipientUid); // Send to specific client
          break;
        default:
          return; // Do nothing for unknown types
      }

      for (String userId in targetUserIds) {
        await notificationCollection.add({
          'userId': userId,
          'projectId': projectId,
          'phaseDocId': phaseDocId, // Store phase document ID
          'title': title,
          'body': body,
          'type': notificationType,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'senderName': senderName, // Who initiated the action
        });
      }
      print('Notification sent: $notificationType to $targetUserIds');
    } catch (e) {
      print('Error sending notification: $e');
      _showErrorSnackBar(context, 'فشل إرسال الإشعار: $e');
    }
  }

  // ----------------------------------------------------------------------
  // Function to update project's currentStage and currentPhaseName
  // This needs to be called after any phase update that changes completion status.
  // ----------------------------------------------------------------------
  Future<void> _updateProjectCurrentPhaseStatus() async {
    try {
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
      final phasesSnapshot = await projectRef.collection('phases').orderBy('number').get();

      int? nextStageNumber;
      String? nextPhaseName;
      bool allPhasesCompleted = true;

      // Find the first non-completed phase
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
        // Handle case where there are no phases at all (e.g., brand new project)
        if (phasesSnapshot.docs.isNotEmpty) {
          final lastPhase = phasesSnapshot.docs.last.data();
          nextStageNumber = lastPhase['number'] as int?;
          nextPhaseName = lastPhase['name'] as String?;
        } else {
          // No phases at all, revert to initial state
          nextStageNumber = 0;
          nextPhaseName = 'لا توجد مراحل بعد';
        }
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
        // Fallback for cases where no phases are found (should be covered by allPhasesCompleted check)
        // or if somehow phases exist but no valid number/name
        await projectRef.update({
          'currentStage': 0, // Fallback to 0 if no phases found
          'currentPhaseName': 'لا توجد مراحل بعد',
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
  // دالة تحديث المرحلة الرئيسية (MODIFIED for Admin adding/editing)
  // ----------------------------------------------------
  Future<void> _updatePhase(
      String phaseDocId, Map<String, dynamic> currentData) async {
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    final noteController = TextEditingController(text: currentData['note'] ?? '');
    bool completed = currentData['completed'] ?? false;
    bool hasSubPhases = currentData['hasSubPhases'] ?? false;
    final bool initialCompletedState = completed;
    final String initialPhaseName = currentData['name'] ?? ''; // To check if name changed

    String? imageUrl = currentData['imageUrl'] as String?;
    String? image360Url = currentData['image360Url'] as String?;
    final int? phaseNumber = currentData['number'] as int?; // Can be null if phase not numbered yet

    // Determine editability based on current user role
    bool isAdminUser = _currentUserRole == 'admin';
    bool isEngineerUser = _currentUserRole == 'engineer';

    // Admin can edit everything. Engineer can only edit notes and images if phase is not completed.
    bool canEditGeneral = isAdminUser || (isEngineerUser && !completed);
    bool canEditName = isAdminUser; // Only admin can change phase name
    bool canEditHasSubPhases = isAdminUser; // Only admin can change this property


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
                'تعديل المرحلة ${phaseNumber != null ? '$phaseNumber: ' : ''}${nameController.text}',
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
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration('اسم المرحلة', Icons.label),
                      enabled: canEditName, // Only admin can edit name
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم المرحلة.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // ملاحظات المرحلة
                    TextFormField(
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
                    // هل تحتوي على مراحل فرعية؟
                    Row(
                      children: [
                        Checkbox(
                          value: hasSubPhases,
                          onChanged: canEditHasSubPhases // Only admin can change this property
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
                              color: canEditHasSubPhases
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
                      if (nameController.text.trim().isEmpty) { // Validate name
                        _showErrorSnackBar(context, 'اسم المرحلة لا يمكن أن يكون فارغًا.');
                        return;
                      }
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
                          'lastUpdated': FieldValue.serverTimestamp(), // Track last update
                        });

                        // إذا تغيرت حالة اكتمال المرحلة، قم بتحديث currentStage للمشروع
                        // وإرسال الإشعارات
                        if (initialCompletedState != completed) {
                          await _updateProjectCurrentPhaseStatus();
                          if (completed) {
                            // Fetch project details to get client ID and engineer ID
                            final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
                            final projectData = projectDoc.data();
                            final clientUid = projectData?['clientId'];
                            final engineerUid = projectData?['engineerId'];
                            final projectName = projectData?['name'] ?? 'المشروع';

                            // Notify Admin
                            _sendNotification(
                              projectId: widget.projectId,
                              projectName: projectName,
                              phaseName: nameController.text.trim(),
                              phaseDocId: phaseDocId,
                              notificationType: 'phase_completed_admin',
                            );
                            // Notify Engineer (if different from current user)
                            if (isEngineerUser && FirebaseAuth.instance.currentUser?.uid != engineerUid) {
                              _sendNotification(
                                projectId: widget.projectId,
                                projectName: projectName,
                                phaseName: nameController.text.trim(),
                                phaseDocId: phaseDocId,
                                notificationType: 'phase_completed_engineer_by_admin', // Specific type for engineer notification
                                recipientUid: engineerUid,
                              );
                            }
                            // Notify Client
                            _sendNotification(
                              projectId: widget.projectId,
                              projectName: projectName,
                              phaseName: nameController.text.trim(),
                              phaseDocId: phaseDocId,
                              notificationType: 'phase_completed_client',
                              recipientUid: clientUid,
                            );
                          }
                        }

                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(context, 'تم تحديث المرحلة ${phaseNumber != null ? '$phaseNumber: ' : ''}${nameController.text} بنجاح.');
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
                if (completed && isEngineerUser) // زر مشاركة التقرير للمهندس فقط عند اكتمال المرحلة
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
  // دالة لإضافة مرحلة رئيسية جديدة (NEW FUNCTION)
  // ----------------------------------------------------
  Future<void> _addPhase() async {
    final nameController = TextEditingController();
    bool hasSubPhases = false; // Default to false
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
    bool isLoading = false;

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
              title: const Text(
                'إضافة مرحلة جديدة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration('اسم المرحلة', Icons.label),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال اسم المرحلة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      Row(
                        children: [
                          Checkbox(
                            value: hasSubPhases,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                hasSubPhases = value ?? false;
                              });
                            },
                            activeColor: AppConstants.accentColor,
                          ),
                          const Text(
                            'تحتوي على مراحل فرعية',
                            style: TextStyle(fontSize: 16, color: AppConstants.textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء', style: TextStyle(color: AppConstants.secondaryTextColor)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setDialogState(() { isLoading = true; });

                    try {
                      // Get the highest current phase number to assign the next one
                      final phasesSnapshot = await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(widget.projectId)
                          .collection('phases')
                          .orderBy('number', descending: true)
                          .limit(1)
                          .get();

                      int nextNumber = 1;
                      if (phasesSnapshot.docs.isNotEmpty) {
                        nextNumber = (phasesSnapshot.docs.first.data()['number'] as int? ?? 0) + 1;
                      }

                      final newPhaseRef = await FirebaseFirestore.instance
                          .collection('projects')
                          .doc(widget.projectId)
                          .collection('phases')
                          .add({
                        'name': nameController.text.trim(),
                        'number': nextNumber, // Assign calculated number
                        'note': '',
                        'imageUrl': null,
                        'image360Url': null,
                        'completed': false,
                        'hasSubPhases': hasSubPhases,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      // Update project's currentStage and currentPhaseName if this is the first phase
                      await _updateProjectCurrentPhaseStatus();

                      // Send notification to engineer about new phase assignment
                      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
                      final projectData = projectDoc.data();
                      final engineerUid = projectData?['engineerId'];
                      final projectName = projectData?['name'] ?? 'المشروع';

                      if (engineerUid != null) {
                        _sendNotification(
                          projectId: widget.projectId,
                          projectName: projectName,
                          phaseName: nameController.text.trim(),
                          phaseDocId: newPhaseRef.id,
                          notificationType: 'engineer_assignment',
                          recipientUid: engineerUid,
                        );
                      }

                      Navigator.pop(dialogContext);
                      _showSuccessSnackBar(context, 'تم إضافة المرحلة "${nameController.text.trim()}" بنجاح.');
                    } catch (e) {
                      setDialogState(() { isLoading = false; });
                      _showErrorSnackBar(context, 'فشل إضافة المرحلة: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('إضافة', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // دالة لحذف مرحلة رئيسية (NEW FUNCTION)
  // ----------------------------------------------------
  Future<void> _deletePhase(String phaseId, String phaseName) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد أنك تريد حذف المرحلة "$phaseName" وكل مراحلها الفرعية؟'),
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
        // Delete all sub-phases first
        final subPhasesSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('phases')
            .doc(phaseId)
            .collection('subPhases')
            .get();
        for (var doc in subPhasesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Then delete the main phase document
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('phases')
            .doc(phaseId)
            .delete();

        // Update project's currentStage and currentPhaseName after deletion
        await _updateProjectCurrentPhaseStatus();

        _showSuccessSnackBar(context, 'تم حذف المرحلة "$phaseName" بنجاح.');
      } catch (e) {
        _showErrorSnackBar(context, 'فشل حذف المرحلة: $e');
      }
    }
  }

  // ----------------------------------------------------
  // دالة تحديث المرحلة الفرعية (MODIFIED)
  // ----------------------------------------------------
  Future<void> _updateSubPhase(
      String phaseDocId, String subPhaseDocId, Map<String, dynamic> currentSubData) async {
    final nameController = TextEditingController(text: currentSubData['name'] ?? '');
    final noteController = TextEditingController(text: currentSubData['note'] ?? '');
    bool completed = currentSubData['completed'] ?? false;
    final bool initialCompletedState = completed; // Track initial state for notifications

    String? imageUrl = currentSubData['imageUrl'] as String?;
    String? image360Url = currentSubData['image360Url'] as String?;

    // Determine editability based on current user role
    bool isAdminUser = _currentUserRole == 'admin';
    bool isEngineerUser = _currentUserRole == 'engineer';

    // Admin can edit everything. Engineer can only edit notes and images if sub-phase is not completed.
    bool canEdit = isAdminUser || (isEngineerUser && !completed);


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
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration('اسم المرحلة الفرعية', Icons.label_important),
                      enabled: isAdminUser, // Only admin can edit name
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم المرحلة الفرعية.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    TextFormField(
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
                      if (nameController.text.trim().isEmpty) { // Validate name
                        _showErrorSnackBar(context, 'اسم المرحلة الفرعية لا يمكن أن يكون فارغًا.');
                        return;
                      }
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
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });

                        // Send notifications if sub-phase just became completed
                        if (initialCompletedState != completed && completed) {
                          // Fetch main phase and project details
                          final mainPhaseDoc = await FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection('phases')
                              .doc(phaseDocId)
                              .get();
                          final mainPhaseData = mainPhaseDoc.data();
                          final mainPhaseName = mainPhaseData?['name'] ?? 'المرحلة الرئيسية';

                          final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
                          final projectData = projectDoc.data();
                          final projectName = projectData?['name'] ?? 'المشروع';
                          final clientUid = projectData?['clientId'];
                          final engineerUid = projectData?['engineerId'];

                          // Notify Admin
                          _sendNotification(
                            projectId: widget.projectId,
                            projectName: projectName,
                            phaseName: '$mainPhaseName > ${nameController.text.trim()}', // Include sub-phase name
                            phaseDocId: phaseDocId, // Link to main phase for context
                            notificationType: 'subphase_completed_admin',
                          );
                          // Notify Engineer (if different from current user)
                          if (isEngineerUser && FirebaseAuth.instance.currentUser?.uid != engineerUid) {
                            _sendNotification(
                              projectId: widget.projectId,
                              projectName: projectName,
                              phaseName: '$mainPhaseName > ${nameController.text.trim()}',
                              phaseDocId: phaseDocId,
                              notificationType: 'subphase_completed_engineer_by_admin',
                              recipientUid: engineerUid,
                            );
                          }
                          // Notify Client
                          _sendNotification(
                            projectId: widget.projectId,
                            projectName: projectName,
                            phaseName: '$mainPhaseName > ${nameController.text.trim()}',
                            phaseDocId: phaseDocId,
                            notificationType: 'subphase_completed_client',
                            recipientUid: clientUid,
                          );
                        }

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
  Future<void> _addSubPhase(String phaseDocId, String mainPhaseName) async {
    final nameController = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: const Text('إضافة مرحلة فرعية جديدة'),
                  content: Form(
                    key: _formKey,
                    // قم بتغيير TextField هنا إلى TextFormField
                    child: TextFormField( // <--- هنا التعديل
                      controller: nameController,
                      decoration: _inputDecoration('اسم المرحلة الفرعية', Icons.add_box),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم المرحلة الفرعية.';
                        }
                        return null;
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setDialogState(() { isLoading = true; });

                        try {
                          final newSubPhaseRef = await FirebaseFirestore.instance
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
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          // Notify engineer about new sub-phase assignment
                          final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
                          final projectData = projectDoc.data();
                          final engineerUid = projectData?['engineerId'];
                          final projectName = projectData?['name'] ?? 'المشروع';

                          if (engineerUid != null) {
                            _sendNotification(
                              projectId: widget.projectId,
                              projectName: projectName,
                              phaseName: '$mainPhaseName > ${nameController.text.trim()}',
                              phaseDocId: phaseDocId,
                              notificationType: 'engineer_subphase_assignment',
                              recipientUid: engineerUid,
                            );
                          }


                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          _showSuccessSnackBar(context, 'تمت إضافة المرحلة الفرعية بنجاح.');
                        } catch (e) {
                          setDialogState(() { isLoading = false; });
                          _showErrorSnackBar(context, 'فشل إضافة المرحلة الفرعية: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor),
                      child: isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text('إضافة', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  // ----------------------------------------------------
  // دالة لحذف مرحلة فرعية
  // ----------------------------------------------------
  Future<void> _deleteSubPhase(String phaseDocId, String subPhaseDocId, String subPhaseName) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد أنك تريد حذف المرحلة الفرعية "$subPhaseName"؟'),
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
        _showSuccessSnackBar(context, 'تم حذف المرحلة الفرعية "$subPhaseName" بنجاح.');
      } catch (e) {
        _showErrorSnackBar(context, 'فشل حذف المرحلة الفرعية: $e');
      }
    }
  }

  // ----------------------------------------------------
  // دالة لعرض خيارات مشاركة التقرير
  // ----------------------------------------------------
  Future<void> _showShareReportOptions(Map<String, dynamic> phaseData) async {
    final String phaseDocId = phaseData['id']; // Assumed to be passed with ID
    final String projectName = (await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get()).data()?['name'] ?? 'المشروع';
    final String phaseName = phaseData['name'] ?? 'المرحلة';
    final String note = phaseData['note'] ?? '';
    final String? imageUrl = phaseData['imageUrl'];
    final String? image360Url = phaseData['image360Url'];

    String reportText = 'تقرير مرحلة "$phaseName" في مشروع "$projectName":\n';
    if (note.isNotEmpty) {
      reportText += 'ملاحظات: $note\n';
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      reportText += 'صورة عادية: $imageUrl\n';
    }
    if (image360Url != null && image360Url.isNotEmpty) {
      reportText += 'صورة 360°: $image360Url\n';
    }

    final subPhasesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('phases')
        .doc(phaseDocId)
        .collection('subPhases')
        .orderBy('timestamp')
        .get();

    if (subPhasesSnapshot.docs.isNotEmpty) {
      reportText += '\nالمراحل الفرعية:\n';
      for (var subPhase in subPhasesSnapshot.docs) {
        final subData = subPhase.data();
        reportText += '- ${subData['name']} (${subData['completed'] ? 'مكتملة' : 'غير مكتملة'})\n';
        if (subData['note'] != null && subData['note'].isNotEmpty) {
          reportText += '  ملاحظة: ${subData['note']}\n';
        }
        if (subData['imageUrl'] != null && subData['imageUrl'].isNotEmpty) {
          reportText += '  صورة: ${subData['imageUrl']}\n';
        }
        if (subData['image360Url'] != null && subData['image360Url'].isNotEmpty) {
          reportText += '  صورة 360°: ${subData['image360Url']}\n';
        }
      }
    }

    await showModalBottomSheet(
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
                  'مشاركة تقرير المرحلة $phaseName',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textColor,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.share, color: AppConstants.primaryColor),
                  title: const Text('مشاركة عادية (نص)'),
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(reportText, subject: 'تقرير مشروع $projectName - مرحلة $phaseName');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded, color: AppConstants.successColor),
                  title: const Text('مشاركة عبر واتساب'),
                  onTap: () async {
                    Navigator.pop(context);
                    final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(reportText)}";
                    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                      await launchUrl(Uri.parse(whatsappUrl));
                    } else {
                      _showErrorSnackBar(context, 'واتساب غير مثبت أو لا يمكن فتحه.');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: AppConstants.primaryColor),
                  title: const Text('مشاركة عبر البريد الإلكتروني'),
                  onTap: () async {
                    Navigator.pop(context);
                    final emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: '',
                      queryParameters: {
                        'subject': 'تقرير مشروع $projectName - مرحلة $phaseName',
                        'body': reportText,
                      },
                    );
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(emailLaunchUri);
                    } else {
                      _showErrorSnackBar(context, 'لا يمكن فتح تطبيق البريد الإلكتروني.');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    bool isAdminUser = _currentUserRole == 'admin';
    bool isEngineerUser = _currentUserRole == 'engineer';

    if (_currentUserRole == null) {
      return const Center(child: CircularProgressIndicator()); // Show loading while fetching role
    }

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
            final clientName = projectData['clientName'] as String? ?? 'غير محدد'; // Fetch client name
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
                          _buildInfoRow(Icons.person, 'العميل:', clientName), // Display client name
                          _buildInfoRow(Icons.info_outline, 'حالة المشروع:', projectStatus,
                              valueColor: (projectStatus == 'نشط')
                                  ? AppConstants.successColor
                                  : (projectStatus == 'مكتمل')
                                  ? Colors.blue
                                  : AppConstants.warningColor),
                          _buildInfoRow(Icons.trending_up, 'المرحلة الحالية:',
                              currentStageNumber == 0
                                  ? currentPhaseName // "لا توجد مراحل بعد"
                                  : '$currentStageNumber - $currentPhaseName'), // Display current phase name
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'مراحل المشروع:',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (isAdminUser) // Only admin can add main phases
                        ElevatedButton.icon(
                          onPressed: _addPhase,
                          icon: const Icon(Icons.add_box, color: Colors.white),
                          label: const Text('إضافة مرحلة', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('phases')
                        .orderBy('number') // Order by the 'number' field (assigned by admin)
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.construction, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                              const SizedBox(height: AppConstants.itemSpacing),
                              Text(
                                'لا توجد مراحل محددة لهذا المشروع. الرجاء إضافة مراحل.',
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
                          final int number = data['number'] as int? ?? (index + 1); // Use assigned number
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAdminUser || (isEngineerUser && !completed)) // Admin can edit always, engineer if not completed
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: AppConstants.accentColor),
                                      onPressed: () => _updatePhase(phase.id, data),
                                    ),
                                  if (isAdminUser) // Only admin can delete main phases
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppConstants.deleteColor),
                                      onPressed: () => _deletePhase(phase.id, name),
                                    ),
                                  if (completed && isEngineerUser) // Share button for engineer if completed
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.teal),
                                      onPressed: () {
                                        final Map<String, dynamic> phaseDataWithId = Map<String, dynamic>.from(data);
                                        phaseDataWithId['id'] = phase.id; // Add ID for sub-phase fetching in report
                                        _showShareReportOptions(phaseDataWithId);
                                      },
                                    ),
                                ],
                              ),
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
                                          (image360Url == null || image360Url.isEmpty) &&
                                          !hasSubPhases)
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
                                                      color: AppConstants.primaryColor),
                                                ),
                                                if (isAdminUser || isEngineerUser) // Engineer/Admin can add sub-phases
                                                  ElevatedButton.icon(
                                                    onPressed: () => _addSubPhase(phase.id, name),
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
                                                          if (isAdminUser || (isEngineerUser && !subCompleted)) // Admin can edit, engineer if not completed
                                                            IconButton(
                                                              icon: const Icon(Icons.edit, color: AppConstants.accentColor),
                                                              onPressed: () => _updateSubPhase(phase.id, subPhase.id, subData),
                                                            ),
                                                          if (isAdminUser) // Only admin can delete sub-phases
                                                            IconButton(
                                                              icon: const Icon(Icons.delete, color: AppConstants.deleteColor),
                                                              onPressed: () => _deleteSubPhase(phase.id, subPhase.id, subName),
                                                            ),
                                                        ],
                                                      ),
                                                      onTap: isAdminUser || (isEngineerUser && !subCompleted)
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