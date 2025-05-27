import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // لتحديد دور المستخدم
import 'package:image_picker/image_picker.dart'; // لالتقاط الصور
import 'dart:io'; // للتعامل مع File
import 'package:http/http.dart' as http; // لرفع الصور
import 'dart:convert'; // لتحويل JSON
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
  static const Color warningColor = Colors.orange; // لون للتحذير

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  String? _currentUserRole;
  Key _projectFutureBuilderKey = UniqueKey(); // لتحديث واجهة المستخدم بعد التعديل
  static const String UPLOAD_URL = 'https://creditphoneqatar.com/eng-app/upload_image.php'; // URL الخاص بسكريبت PHP

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

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

  // ----------------------------------------------------
  // دالة تحديث المرحلة الرئيسية (خاصة بالمهندس)
  // ----------------------------------------------------
  Future<void> _updatePhase(
      String phaseDocId, Map<String, dynamic> currentData) async {
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    final noteController = TextEditingController(text: currentData['note'] ?? '');
    bool completed = currentData['completed'] ?? false;
    bool hasSubPhases = currentData['hasSubPhases'] ?? false; // لا يمكن للمهندس تغييرها
    final bool initialCompletedState = completed;
    final String initialPhaseName = currentData['name'] ?? '';

    String? imageUrl = currentData['imageUrl'] as String?;
    String? image360Url = currentData['image360Url'] as String?;
    final int phaseNumber = currentData['number'];

    // المهندس لا يمكنه التعديل إذا كانت المرحلة مكتملة
    bool canEngineerEdit = (_currentUserRole == 'engineer' && !completed);
    // الإداري يمكنه التعديل دائمًا (هذا الكود لصفحة المهندس فقط، لكن لضمان الشمولية في المنطق)
    bool isAdmin = (_currentUserRole == 'admin');

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
          // يمكن للمهندس التعديل فقط إذا كانت المرحلة غير مكتملة
          bool isEditable = canEngineerEdit || isAdmin; // isAdmin for future proofing if this dialog is ever used by admin
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: Text(
                'تعديل المرحلة $phaseNumber',
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
                    // اسم المرحلة (غير قابل للتعديل للمهندس)
                    TextField(
                      controller: nameController,
                      decoration: _inputDecoration('اسم المرحلة', Icons.label),
                      enabled: isAdmin, // فقط الإداري يمكنه تعديل الاسم
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // ملاحظات المرحلة
                    TextField(
                      controller: noteController,
                      decoration: _inputDecoration('ملاحظات المرحلة', Icons.notes),
                      maxLines: 3,
                      enabled: isEditable, // المهندس يعدل إذا لم تكتمل
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // حالة الاكتمال
                    Row(
                      children: [
                        Checkbox(
                          value: completed,
                          onChanged: isEditable // المهندس يعدل إذا لم تكتمل
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
                              color: isEditable
                                  ? AppConstants.textColor
                                  : AppConstants.secondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // هل تحتوي على مراحل فرعية؟ (غير قابل للتعديل للمهندس)
                    Row(
                      children: [
                        Checkbox(
                          value: hasSubPhases,
                          onChanged: isAdmin ? (bool? value) { /* Admin logic */ } : null, // فقط الإداري يمكنه تعديل هذه الخاصية
                          activeColor: AppConstants.accentColor,
                        ),
                        Text(
                          'تحتوي على مراحل فرعية',
                          style: TextStyle(
                              fontSize: 16,
                              color: isAdmin
                                  ? AppConstants.textColor
                                  : AppConstants.secondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    // زر التقاط ورفع الصورة
                    if (isEditable)
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

                    // عرض الصور الموجودة مع زر الحذف (يظهر للمهندس إذا كانت المرحلة غير مكتملة)
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
                          Image.network(
                            imageUrl!,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 100),
                          ),
                          if (isEditable) // زر الحذف يظهر للمهندس إذا كانت المرحلة غير مكتملة
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
                          Image.network(
                            image360Url!,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 100),
                          ),
                          if (isEditable) // زر الحذف يظهر للمهندس إذا كانت المرحلة غير مكتملة
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
                    if (imageUrl == null && image360Url == null)
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
                if (isEditable) // زر الحفظ يظهر فقط إذا كان يمكن التعديل
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('projects')
                            .doc(widget.projectId)
                            .collection('phases')
                            .doc(phaseDocId)
                            .update({
                          // 'name': nameController.text.trim(), // المهندس لا يعدل الاسم
                          'note': noteController.text.trim(),
                          'completed': completed,
                          // 'hasSubPhases': hasSubPhases, // المهندس لا يعدل هذه الخاصية
                          'imageUrl': imageUrl,
                          'image360Url': image360Url,
                        });

                        // إذا تغيرت حالة اكتمال المرحلة أو اسمها، قم بتحديث lastCompletedPhaseName
                        if (initialCompletedState != completed ||
                            initialPhaseName != nameController.text.trim()) {
                          await _updateProjectLastCompletedPhaseName();
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
                if (completed && _currentUserRole == 'engineer') // زر مشاركة التقرير للمهندس فقط عند اكتمال المرحلة
                  ElevatedButton(
                    onPressed: () {
                      final Map<String, dynamic> phaseDataWithId = Map<String, dynamic>.from(currentData);
                      phaseDataWithId['id'] = phaseDocId; // أضف الـ ID هنا
                      _showShareReportOptions(phaseDataWithId);
                    },
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
  // دالة تحديث المرحلة الفرعية (خاصة بالمهندس)
  // ----------------------------------------------------
  Future<void> _updateSubPhase(
      String phaseDocId, String subPhaseDocId, Map<String, dynamic> currentSubData) async {
    final nameController = TextEditingController(text: currentSubData['name'] ?? '');
    final noteController = TextEditingController(text: currentSubData['note'] ?? '');
    bool completed = currentSubData['completed'] ?? false;

    String? imageUrl = currentSubData['imageUrl'] as String?;
    String? image360Url = currentSubData['image360Url'] as String?;

    // المهندس لا يمكنه التعديل إذا كانت المرحلة الفرعية مكتملة
    bool canEngineerEditSubPhase = (_currentUserRole == 'engineer' && !completed);
    bool isAdmin = (_currentUserRole == 'admin');

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
          bool isEditable = canEngineerEditSubPhase || isAdmin;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: Text(
                'تعديل المرحلة الفرعية: ${currentSubData['name']}',
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
                      enabled: isAdmin, // فقط الإداري يمكنه تعديل الاسم
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    TextField(
                      controller: noteController,
                      decoration: _inputDecoration('ملاحظات المرحلة الفرعية', Icons.notes),
                      maxLines: 3,
                      enabled: isEditable,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Row(
                      children: [
                        Checkbox(
                          value: completed,
                          onChanged: isEditable
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
                              color: isEditable
                                  ? AppConstants.textColor
                                  : AppConstants.secondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    if (isEditable)
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
                          Image.network(
                            imageUrl!,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 100),
                          ),
                          if (isEditable)
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
                          Image.network(
                            image360Url!,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 100),
                          ),
                          if (isEditable)
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
                    if (imageUrl == null && image360Url == null)
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
                if (isEditable)
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
                          // 'name': nameController.text.trim(), // المهندس لا يعدل الاسم
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
  // دالة لتحديث اسم آخر مرحلة مكتملة في المشروع (لضمان التزامن)
  // ----------------------------------------------------
  Future<void> _updateProjectLastCompletedPhaseName() async {
    try {
      final projectPhases = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases')
          .orderBy('number', descending: true)
          .get();

      String lastCompletedPhaseName = 'لا توجد مراحل مكتملة بعد';
      for (var phase in projectPhases.docs) {
        final data = phase.data();
        if (data['completed'] == true) {
          lastCompletedPhaseName = data['name'] ?? 'مرحلة مكتملة';
          break; // وجدت آخر مرحلة مكتملة، لا حاجة للمتابعة
        }
      }

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'lastCompletedPhaseName': lastCompletedPhaseName});

      setState(() {
        _projectFutureBuilderKey = UniqueKey(); // لتحديث واجهة المستخدم
      });
    } catch (e) {
      _showErrorSnackBar(context, 'فشل تحديث اسم آخر مرحلة مكتملة: $e');
    }
  }

  // ----------------------------------------------------
  // دالة لعرض خيارات مشاركة التقرير (خاصة بالمهندس)
  // ----------------------------------------------------
  Future<void> _showShareReportOptions(Map<String, dynamic> phaseData) async {
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

    // يجب أن يكون phaseData يحتوي على id المرحلة لاستعلام المراحل الفرعية
    final String phaseId = phaseData['id'];

    final subPhasesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('phases')
        .doc(phaseId)
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

    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مشاركة التقرير'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('مشاركة عادية'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(reportText, subject: 'تقرير مشروع $projectName - مرحلة $phaseName');
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_android_rounded),
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
                leading: const Icon(Icons.email),
                title: const Text('مشاركة عبر البريد الإلكتروني'),
                onTap: () async {
                  Navigator.pop(context);
                  final emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: '', // يمكن وضع عنوان بريد إلكتروني هنا إذا كان ثابتًا
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
      ),
    );
  }

  // ----------------------------------------------------
  // دوال مساعدة
  // ----------------------------------------------------
  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppConstants.secondaryTextColor),
      prefixIcon: Icon(icon, color: AppConstants.primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.accentColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
      ),
      filled: true,
      fillColor: AppConstants.cardColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
      ),
    );
  }

  void _showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.warningColor,
      ),
    );
  }

  // ----------------------------------------------------
  // مكون مساعد لعرض معلومات المشروع الرئيسية
  // ----------------------------------------------------
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
              textDirection: TextDirection.rtl,
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

  // ----------------------------------------------------
  // مكون مساعد لعرض قسم الصور (يعرض من روابط URL)
  // ----------------------------------------------------
  Widget _buildImageSection(String title, String imageUrl) {
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
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    color: AppConstants.primaryColor,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 150,
                color: Colors.grey.shade200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
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

  // ----------------------------------------------------
  // مكون لعرض قائمة المراحل الفرعية
  // ----------------------------------------------------
  Widget _buildSubPhasesList(String phaseId, bool canEngineerEditMainPhase) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases')
          .doc(phaseId)
          .collection('subPhases')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return Text('خطأ في تحميل المراحل الفرعية: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text(
            'لا توجد مراحل فرعية بعد.',
            style: TextStyle(color: AppConstants.secondaryTextColor.withOpacity(0.7)),
          );
        }

        final subPhases = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subPhases.length,
          itemBuilder: (context, index) {
            final subPhase = subPhases[index];
            final subData = subPhase.data() as Map<String, dynamic>;
            final subName = subData['name'] as String? ?? 'مرحلة فرعية غير مسماة';
            final subCompleted = subData['completed'] as bool? ?? false;

            // المهندس يمكنه التعديل إذا كانت المرحلة الفرعية غير مكتملة
            bool canEngineerEditSubPhase = (_currentUserRole == 'engineer' && !subCompleted);

            return Card(
              color: subCompleted
                  ? AppConstants.successColor.withOpacity(0.05)
                  : AppConstants.warningColor.withOpacity(0.05),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              elevation: 1,
              child: ListTile(
                leading: Icon(
                  subCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: subCompleted ? AppConstants.successColor : AppConstants.warningColor,
                ),
                title: Text(
                  subName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textColor,
                    decoration: subCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                subtitle: Text(
                  subCompleted ? 'مكتملة' : 'غير مكتملة',
                  style: TextStyle(
                    color: subCompleted ? AppConstants.successColor : AppConstants.warningColor,
                  ),
                ),
                trailing: canEngineerEditSubPhase
                    ? IconButton(
                  icon: const Icon(Icons.edit, color: AppConstants.accentColor),
                  onPressed: () => _updateSubPhase(phaseId, subPhase.id, subData),
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
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
          key: _projectFutureBuilderKey,
          future: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (projectSnapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ في تحميل تفاصيل المشروع: ${projectSnapshot.error}',
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
                    Icon(Icons.folder_off, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
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
            final lastCompletedPhaseName = projectData['lastCompletedPhaseName'] as String? ?? 'لا توجد مراحل مكتملة بعد'; // استخدام الحقل الجديد
            final engineerName = projectData['engineerName'] as String? ?? 'غير معروف';
            final clientName = projectData['clientName'] as String? ?? 'غير معروف';
            final status = projectData['status'] as String? ?? 'غير محدد';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppConstants.padding),
                  child: Card(
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
                          // عرض اسم آخر مرحلة مكتملة
                          _buildInfoRow(
                              Icons.check_circle_outline, 'آخر مرحلة مكتملة:', lastCompletedPhaseName),
                          _buildInfoRow(Icons.engineering, 'المهندس المسؤول:', engineerName),
                          _buildInfoRow(Icons.person, 'العميل:', clientName),
                          _buildInfoRow(Icons.info_outline, 'الحالة:', status,
                              valueColor: (status == 'نشط')
                                  ? AppConstants.successColor
                                  : (status == 'مكتمل')
                                  ? Colors.blue
                                  : AppConstants.warningColor),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.padding),
                  child: Text(
                    'مراحل المشروع:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(height: AppConstants.itemSpacing),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('phases')
                        .orderBy('number') // التأكد من الترتيب حسب الرقم
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(color: AppConstants.primaryColor));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'حدث خطأ في تحميل المراحل: ${snapshot.error}',
                            style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                              const SizedBox(height: AppConstants.itemSpacing),
                              Text(
                                'لا توجد مراحل لهذا المشروع بعد.',
                                style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                              ),
                            ],
                          ),
                        );
                      }

                      final phases = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.padding / 2),
                        itemCount: phases.length,
                        itemBuilder: (context, index) {
                          final phase = phases[index];
                          final data = phase.data() as Map<String, dynamic>;
                          final number = data['number'] as int? ?? (index + 1);
                          final name = data['name'] as String? ?? 'المرحلة $number';
                          final note = data['note'] as String? ?? '';
                          final imageUrl = data['imageUrl'] as String?;
                          final image360Url = data['image360Url'] as String?;
                          final completed = data['completed'] as bool? ?? false;
                          final hasSubPhases = data['hasSubPhases'] as bool? ?? false;


                          // المهندس يمكنه التعديل فقط إذا كانت المرحلة غير مكتملة
                          bool canEngineerEditPhase = (_currentUserRole == 'engineer' && !completed);


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
                              backgroundColor: completed
                                  ? AppConstants.successColor.withOpacity(0.05)
                                  : AppConstants.warningColor.withOpacity(0.05),
                              leading: CircleAvatar(
                                backgroundColor: completed
                                    ? AppConstants.successColor
                                    : AppConstants.warningColor,
                                child: Text(
                                  number.toString(),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textColor,
                                ),
                              ),
                              subtitle: Text(
                                completed ? 'مكتملة ✅' : 'غير مكتملة ❌',
                                style: TextStyle(
                                  color: completed
                                      ? AppConstants.successColor
                                      : AppConstants.warningColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canEngineerEditPhase) // زر التعديل يظهر للمهندس إذا لم تكتمل المرحلة
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: AppConstants.primaryColor),
                                      onPressed: () {
                                        _updatePhase(phase.id, data);
                                      },
                                    ),
                                  if (completed && _currentUserRole == 'engineer') // زر المشاركة (للمهندس والمرحلة مكتملة)
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.teal),
                                      onPressed: () {
                                        final Map<String, dynamic> phaseDataWithId = Map<String, dynamic>.from(data);
                                        phaseDataWithId['id'] = phase.id; // أضف الـ ID هنا
                                        _showShareReportOptions(phaseDataWithId);
                                      },
                                    ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppConstants.padding,
                                      vertical: AppConstants.itemSpacing / 2),
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
                                              color: AppConstants.secondaryTextColor
                                                  .withOpacity(0.7)),
                                        ),
                                      // قسم المراحل الفرعية
                                      if (hasSubPhases)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(),
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
                                                // لا يوجد زر إضافة مرحلة فرعية للمهندس
                                              ],
                                            ),
                                            const SizedBox(height: AppConstants.itemSpacing / 2),
                                            _buildSubPhasesList(phase.id, canEngineerEditPhase),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}