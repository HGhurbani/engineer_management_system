// lib/pages/engineer/project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui; // For TextDirection

// Constants for consistent styling, aligned with the admin dashboard's style.
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color deleteColor = errorColor;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
        color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
  // URL for the PHP script to upload images
  static const String UPLOAD_URL = 'https://creditphoneqatar.com/eng-app/upload_image.php';
}

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  String? _currentUserRole;
  Key _projectFutureBuilderKey = UniqueKey();
  bool _isPageLoading = true;

  final GlobalKey<FormState> _updatePhaseFormKey = GlobalKey<FormState>(); //
  final GlobalKey<FormState> _updateSubPhaseFormKey = GlobalKey<FormState>(); //

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole().then((_) {
      if (mounted) {
        setState(() {
          _isPageLoading = false;
        });
      }
    });
  }

  Future<void> _fetchCurrentUserRole() async { //
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserRole = userDoc.data()?['role'] as String?;
        });
      }
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppConstants.textSecondary),
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: BorderSide(color: AppConstants.textSecondary.withOpacity(0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: enabled ? AppConstants.cardColor : AppConstants.backgroundColor.withOpacity(0.7),
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      ),
      validator: (value) {
        if (enabled && (value == null || value.isEmpty)) { // Only validate if enabled and empty
          if (labelText.contains("ملاحظات")) return null; // Notes can be empty
          return 'هذا الحقل مطلوب.';
        }
        return validator?.call(value);
      },
    );
  }

  Future<void> _sendNotification({ //
    required String projectId,
    required String projectName,
    required String phaseName,
    required String phaseDocId,
    required String notificationType,
    String? recipientUid,
  }) async {
    try {
      final notificationCollection = FirebaseFirestore.instance.collection('notifications');
      final currentUser = FirebaseAuth.instance.currentUser;
      String senderName = "النظام";
      if (currentUser != null) {
        final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        senderName = senderDoc.data()?['name'] ?? 'مهندس';
      }

      String title = '';
      String body = '';
      List<String> targetUserIds = [];

      switch (notificationType) {
        case 'phase_completed_admin':
          title = 'تحديث مشروع: مرحلة مكتملة';
          body = 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة بواسطة $senderName.';
          final adminsSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').get();
          for (var adminDoc in adminsSnapshot.docs) {
            targetUserIds.add(adminDoc.id);
          }
          break;
        case 'phase_completed_client':
          title = 'تحديث مشروع: مرحلة مكتملة';
          body = 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة. يمكنك الآن مراجعتها.';
          if (recipientUid != null) targetUserIds.add(recipientUid);
          break;
        case 'subphase_completed_admin':
          title = 'تحديث مشروع: مرحلة فرعية مكتملة';
          body = 'المرحلة الفرعية "$phaseName" في مشروع "$projectName" أصبحت مكتملة بواسطة $senderName.';
          final adminsSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').get();
          for (var adminDoc in adminsSnapshot.docs) {
            targetUserIds.add(adminDoc.id);
          }
          break;
        case 'subphase_completed_client':
          title = 'تحديث مشروع: مرحلة فرعية مكتملة';
          body = 'المرحلة الفرعية "$phaseName" في مشروع "$projectName" أصبحت مكتملة. يمكنك الآن مراجعتها.';
          if (recipientUid != null) targetUserIds.add(recipientUid);
          break;
      }

      for (String userId in targetUserIds) {
        await notificationCollection.add({
          'userId': userId, 'projectId': projectId, 'phaseDocId': phaseDocId, 'title': title, 'body': body,
          'type': notificationType, 'isRead': false, 'timestamp': FieldValue.serverTimestamp(), 'senderName': senderName,
        });
      }
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل إرسال الإشعار: $e', isError: true);
    }
  }

  Future<void> _updateProjectLastCompletedPhaseName() async { //
    try {
      final projectPhases = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').orderBy('number', descending: true).get();
      String lastCompletedPhaseName = 'لا توجد مراحل مكتملة بعد';
      for (var phase in projectPhases.docs) {
        final data = phase.data();
        if (data['completed'] == true) {
          lastCompletedPhaseName = data['name'] ?? 'مرحلة مكتملة';
          // No break, find the highest numbered completed phase by iterating through all
        }
      }
      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).update({'lastCompletedPhaseName': lastCompletedPhaseName});
      if (mounted) setState(() => _projectFutureBuilderKey = UniqueKey());
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل تحديث اسم آخر مرحلة مكتملة: $e', isError: true);
    }
  }

  Future<void> _updatePhase(String phaseDocId, Map<String, dynamic> currentData) async { //
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    final noteController = TextEditingController(text: currentData['note'] ?? '');
    bool completed = currentData['completed'] ?? false;
    bool hasSubPhases = currentData['hasSubPhases'] ?? false; // Engineer cannot change this
    final bool initialCompletedState = completed;
    final String initialPhaseName = currentData['name'] ?? '';

    String? imageUrl = currentData['imageUrl'] as String?;
    String? image360Url = currentData['image360Url'] as String?;
    final int? phaseNumber = currentData['number'] as int?;
    bool isLoadingDialog = false;

    bool canEngineerEdit = (_currentUserRole == 'engineer' && !completed); //

    Future<void> pickAndUploadImage(bool is360Image, Function(VoidCallback) setDialogState) async {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        try {
          if (mounted) _showFeedbackSnackBar(context, 'جاري رفع الصورة...', isError: false);
          var request = http.MultipartRequest('POST', Uri.parse(AppConstants.UPLOAD_URL));
          request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['status'] == 'success') {
              setDialogState(() {
                if (is360Image) image360Url = responseData['url']; else imageUrl = responseData['url'];
              });
              if (mounted) _showFeedbackSnackBar(context, 'تم رفع الصورة بنجاح.', isError: false);
            } else {
              if (mounted) _showFeedbackSnackBar(context, 'فشل الرفع: ${responseData['message']}', isError: true);
            }
          } else {
            if (mounted) _showFeedbackSnackBar(context, 'خطأ في الخادم: ${response.statusCode}', isError: true);
          }
        } catch (e) {
          if (mounted) _showFeedbackSnackBar(context, 'فشل رفع الصورة: $e', isError: true);
        }
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: !isLoadingDialog,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              title: Text('تحديث المرحلة ${phaseNumber ?? ""}: ${nameController.text}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor, fontSize: 20)),
              content: SingleChildScrollView(
                child: Form(
                  key: _updatePhaseFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStyledTextField(controller: nameController, labelText: 'اسم المرحلة', icon: Icons.label_important_outline, enabled: false), // Engineer cannot edit name
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(controller: noteController, labelText: 'ملاحظات المرحلة', icon: Icons.notes_rounded, maxLines: 3, enabled: canEngineerEdit),
                      const SizedBox(height: AppConstants.itemSpacing),
                      Row(children: [
                        Checkbox(value: completed, onChanged: canEngineerEdit ? (val) => setDialogState(() => completed = val ?? false) : null, activeColor: AppConstants.successColor),
                        Text('مكتملة', style: TextStyle(fontSize: 16, color: canEngineerEdit ? AppConstants.textPrimary : AppConstants.textSecondary)),
                        const Spacer(),
                        Checkbox(value: hasSubPhases, onChanged: null, activeColor: AppConstants.infoColor), // Engineer cannot edit this
                        const Text('بها مراحل فرعية', style: TextStyle(fontSize: 16, color: AppConstants.textSecondary)),
                      ]),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (canEngineerEdit)
                        ElevatedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (innerCtx) => AlertDialog(title: const Text('اختر نوع الصورة'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.image_outlined), title: const Text('صورة عادية'), onTap: (){Navigator.pop(innerCtx); pickAndUploadImage(false, setDialogState);}), ListTile(leading: const Icon(Icons.threed_rotation_outlined), title: const Text('صورة 360°'), onTap: (){Navigator.pop(innerCtx); pickAndUploadImage(true, setDialogState);})],))),
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                          label: const Text('التقاط ورفع صورة', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryLight, minimumSize: const Size(double.infinity, 45)),
                        ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (imageUrl != null || image360Url != null) const Text('الصور المرفوعة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                      if (imageUrl != null) _buildExistingImagePreview(imageUrl!, () => setDialogState(() => imageUrl = null), canEngineerEdit, "صورة عادية"),
                      if (image360Url != null) _buildExistingImagePreview(image360Url!, () => setDialogState(() => image360Url = null), canEngineerEdit, "صورة 360°"),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary))),
                if (completed && _currentUserRole == 'engineer') // Share button appears for engineer if phase is completed
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    label: const Text('مشاركة التقرير', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(dialogContext); // Close update dialog first
                      final Map<String, dynamic> phaseDataWithId = Map<String, dynamic>.from(currentData);
                      phaseDataWithId['id'] = phaseDocId;
                      _showShareReportOptionsDialog(phaseDataWithId);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall)),
                  ),
                ElevatedButton.icon(
                  onPressed: isLoadingDialog || !canEngineerEdit ? null : () async { // Save button active only if engineer can edit
                    if (!_updatePhaseFormKey.currentState!.validate()) return;
                    setDialogState(() => isLoadingDialog = true);
                    try {
                      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').doc(phaseDocId).update({
                        'name': nameController.text.trim(), // Name is not changed by engineer, but kept for consistency
                        'note': noteController.text.trim(),
                        'completed': completed,
                        // 'hasSubPhases': hasSubPhases, // Engineer cannot change
                        'imageUrl': imageUrl,
                        'image360Url': image360Url,
                        'lastUpdated': FieldValue.serverTimestamp(),
                      });
                      if (initialCompletedState != completed || initialPhaseName != nameController.text.trim()) {
                        await _updateProjectLastCompletedPhaseName(); //
                        if (completed) {
                          final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
                          final projectData = projectDoc.data();
                          final clientUid = projectData?['clientId'];
                          final projectName = projectData?['name'] ?? 'المشروع';
                          _sendNotification(projectId: widget.projectId, projectName: projectName, phaseName: nameController.text.trim(), phaseDocId: phaseDocId, notificationType: 'phase_completed_admin'); //
                          _sendNotification(projectId: widget.projectId, projectName: projectName, phaseName: nameController.text.trim(), phaseDocId: phaseDocId, notificationType: 'phase_completed_client', recipientUid: clientUid); //
                        }
                      }
                      Navigator.pop(dialogContext);
                      if(mounted) _showFeedbackSnackBar(context, 'تم تحديث المرحلة بنجاح.', isError: false);
                    } catch (e) {
                      if(mounted) _showFeedbackSnackBar(context, 'فشل تحديث المرحلة: $e', isError: true);
                    } finally {
                      if(mounted) setDialogState(() => isLoadingDialog = false);
                    }
                  },
                  icon: isLoadingDialog ? const SizedBox.shrink() : const Icon(Icons.save_alt_rounded, color: Colors.white),
                  label: isLoadingDialog ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('حفظ', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, disabledBackgroundColor: AppConstants.primaryColor.withOpacity(0.5)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExistingImagePreview(String url, VoidCallback onDelete, bool canEdit, String imageTypeLabel) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(imageTypeLabel, style: const TextStyle(fontWeight: FontWeight.w500, color: AppConstants.textSecondary)),
          const SizedBox(height: AppConstants.paddingSmall / 2),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                  child: Image.network(url, height: 100, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100, width: double.infinity,
                      color: AppConstants.backgroundColor,
                      child: const Icon(Icons.broken_image_outlined, color: AppConstants.textSecondary, size: 40),
                    ),
                  ),
                ),
              ),
              if (canEdit)
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.deleteColor), onPressed: onDelete, tooltip: 'حذف الصورة'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateSubPhase(String phaseDocId, String subPhaseDocId, Map<String, dynamic> currentSubData) async { //
    final nameController = TextEditingController(text: currentSubData['name'] ?? '');
    final noteController = TextEditingController(text: currentSubData['note'] ?? '');
    bool completed = currentSubData['completed'] ?? false;
    final bool initialCompletedState = completed;
    String? imageUrl = currentSubData['imageUrl'] as String?;
    String? image360Url = currentSubData['image360Url'] as String?;
    bool isLoadingDialog = false;

    bool canEngineerEditSubPhase = (_currentUserRole == 'engineer' && !completed); //

    Future<void> pickAndUploadImage(bool is360Image, Function(VoidCallback) setDialogState) async {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        try {
          if (mounted) _showFeedbackSnackBar(context, 'جاري رفع الصورة...', isError: false);
          var request = http.MultipartRequest('POST', Uri.parse(AppConstants.UPLOAD_URL));
          request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);
          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['status'] == 'success') {
              setDialogState(() {
                if (is360Image) image360Url = responseData['url']; else imageUrl = responseData['url'];
              });
              if (mounted) _showFeedbackSnackBar(context, 'تم رفع الصورة بنجاح.', isError: false);
            } else {
              if (mounted) _showFeedbackSnackBar(context, 'فشل الرفع: ${responseData['message']}', isError: true);
            }
          } else {
            if (mounted) _showFeedbackSnackBar(context, 'خطأ في الخادم: ${response.statusCode}', isError: true);
          }
        } catch (e) {
          if (mounted) _showFeedbackSnackBar(context, 'فشل رفع الصورة: $e', isError: true);
        }
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: !isLoadingDialog,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              title: Text('تحديث المرحلة الفرعية: ${nameController.text}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor, fontSize: 20)),
              content: SingleChildScrollView(
                child: Form(
                  key: _updateSubPhaseFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStyledTextField(controller: nameController, labelText: 'اسم المرحلة الفرعية', icon: Icons.label_outline, enabled: false), // Engineer cannot edit name
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(controller: noteController, labelText: 'ملاحظات المرحلة الفرعية', icon: Icons.comment_outlined, maxLines: 3, enabled: canEngineerEditSubPhase),
                      const SizedBox(height: AppConstants.itemSpacing),
                      Row(children: [
                        Checkbox(value: completed, onChanged: canEngineerEditSubPhase ? (val) => setDialogState(() => completed = val ?? false) : null, activeColor: AppConstants.successColor),
                        Text('مكتملة', style: TextStyle(fontSize: 16, color: canEngineerEditSubPhase ? AppConstants.textPrimary : AppConstants.textSecondary)),
                      ]),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (canEngineerEditSubPhase) ElevatedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (innerCtx) => AlertDialog(title: const Text('اختر نوع الصورة'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.image_outlined), title: const Text('صورة عادية'), onTap: (){Navigator.pop(innerCtx); pickAndUploadImage(false, setDialogState);}), ListTile(leading: const Icon(Icons.threed_rotation_outlined), title: const Text('صورة 360°'), onTap: (){Navigator.pop(innerCtx); pickAndUploadImage(true, setDialogState);})],))),
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                        label: const Text('التقاط ورفع صورة', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryLight, minimumSize: const Size(double.infinity, 45)),
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (imageUrl != null || image360Url != null) const Text('الصور المرفوعة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                      if (imageUrl != null) _buildExistingImagePreview(imageUrl!, () => setDialogState(() => imageUrl = null), canEngineerEditSubPhase, "صورة عادية"),
                      if (image360Url != null) _buildExistingImagePreview(image360Url!, () => setDialogState(() => image360Url = null), canEngineerEditSubPhase, "صورة 360°"),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary))),
                const SizedBox(width: AppConstants.paddingSmall),
                ElevatedButton.icon(
                  onPressed: isLoadingDialog || !canEngineerEditSubPhase ? null : () async {
                    if (!_updateSubPhaseFormKey.currentState!.validate()) return;
                    setDialogState(() => isLoadingDialog = true);
                    try {
                      await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').doc(phaseDocId).collection('subPhases').doc(subPhaseDocId).update({
                        // 'name': nameController.text.trim(), // Engineer cannot change name
                        'note': noteController.text.trim(), 'completed': completed, 'imageUrl': imageUrl, 'image360Url': image360Url, 'lastUpdated': FieldValue.serverTimestamp(),
                      });
                      if (initialCompletedState != completed && completed) {
                        final mainPhaseDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').doc(phaseDocId).get();
                        final mainPhaseData = mainPhaseDoc.data();
                        final mainPhaseName = mainPhaseData?['name'] ?? 'المرحلة الرئيسية';
                        final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
                        final projectData = projectDoc.data();
                        final projectName = projectData?['name'] ?? 'المشروع';
                        final clientUid = projectData?['clientId'];
                        _sendNotification(projectId: widget.projectId, projectName: projectName, phaseName: '$mainPhaseName > ${nameController.text.trim()}', phaseDocId: phaseDocId, notificationType: 'subphase_completed_admin'); //
                        _sendNotification(projectId: widget.projectId, projectName: projectName, phaseName: '$mainPhaseName > ${nameController.text.trim()}', phaseDocId: phaseDocId, notificationType: 'subphase_completed_client', recipientUid: clientUid); //
                      }
                      Navigator.pop(dialogContext);
                      if(mounted) _showFeedbackSnackBar(context, 'تم تحديث المرحلة الفرعية بنجاح.', isError: false);
                    } catch (e) {
                      if(mounted) _showFeedbackSnackBar(context, 'فشل تحديث المرحلة الفرعية: $e', isError: true);
                    } finally {
                      if(mounted) setDialogState(() => isLoadingDialog = false);
                    }
                  },
                  icon: isLoadingDialog ? const SizedBox.shrink() : const Icon(Icons.save_alt_rounded, color: Colors.white),
                  label: isLoadingDialog ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('حفظ', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, disabledBackgroundColor: AppConstants.primaryColor.withOpacity(0.5)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showShareReportOptionsDialog(Map<String, dynamic> phaseData) async { //
    final String phaseDocId = phaseData['id'] ?? ''; // Assuming 'id' is passed in phaseData
    final String phaseName = phaseData['name'] ?? 'المرحلة';
    final String note = phaseData['note'] ?? '';
    final String? imageUrl = phaseData['imageUrl'];
    final String? image360Url = phaseData['image360Url'];

    DocumentSnapshot projectSnapshot = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
    final String projectName = (projectSnapshot.data() as Map<String, dynamic>)['name'] ?? 'المشروع';

    String reportText = 'تقرير مرحلة "$phaseName" في مشروع "$projectName":\n';
    if (note.isNotEmpty) reportText += 'ملاحظات: $note\n';
    if (imageUrl != null && imageUrl.isNotEmpty) reportText += 'صورة عادية: $imageUrl\n';
    if (image360Url != null && image360Url.isNotEmpty) reportText += 'صورة 360°: $image360Url\n';

    final subPhasesSnapshot = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').doc(phaseDocId).collection('subPhases').orderBy('timestamp').get();
    if (subPhasesSnapshot.docs.isNotEmpty) {
      reportText += '\nالمراحل الفرعية:\n';
      for (var subPhase in subPhasesSnapshot.docs) {
        final subData = subPhase.data();
        reportText += '- ${subData['name']} (${subData['completed'] ? 'مكتملة' : 'غير مكتملة'})\n';
        if (subData['note'] != null && subData['note'].isNotEmpty) reportText += '  ملاحظة: ${subData['note']}\n';
        if (subData['imageUrl'] != null && subData['imageUrl'].isNotEmpty) reportText += '  صورة: ${subData['imageUrl']}\n';
        if (subData['image360Url'] != null && subData['image360Url'].isNotEmpty) reportText += '  صورة 360°: ${subData['image360Url']}\n';
      }
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.borderRadius))),
      builder: (context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مشاركة تقرير المرحلة "$phaseName"', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                const Divider(height: AppConstants.itemSpacing),
                _buildShareTile(Icons.share_rounded, 'مشاركة عادية (نص)', () {
                  Navigator.pop(context); Share.share(reportText, subject: 'تقرير مشروع $projectName - مرحلة $phaseName');
                }),
                _buildShareTile(Icons.message_rounded, 'مشاركة عبر واتساب', () async {
                  Navigator.pop(context);
                  final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(reportText)}";
                  if (await canLaunchUrl(Uri.parse(whatsappUrl))) await launchUrl(Uri.parse(whatsappUrl));
                  else if(mounted) _showFeedbackSnackBar(context, 'واتساب غير مثبت.', isError: true);
                }),
                _buildShareTile(Icons.email_rounded, 'مشاركة عبر البريد', () async {
                  Navigator.pop(context);
                  final emailLaunchUri = Uri(scheme: 'mailto', queryParameters: {'subject': 'تقرير مشروع $projectName - مرحلة $phaseName', 'body': reportText});
                  if (await canLaunchUrl(emailLaunchUri)) await launchUrl(emailLaunchUri);
                  else if(mounted) _showFeedbackSnackBar(context, 'لا يمكن فتح تطبيق البريد.', isError: true);
                }),
                const SizedBox(height: AppConstants.paddingSmall),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppConstants.primaryColor),
      title: Text(title, style: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
      hoverColor: AppConstants.primaryColor.withOpacity(0.05),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('تفاصيل المشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22)),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      elevation: 3,
      centerTitle: true,
    );
  }

  Widget _buildProjectSummaryCard(Map<String, dynamic> projectData) {
    final projectName = projectData['name'] ?? 'مشروع غير مسمى';
    final engineerName = projectData['engineerName'] ?? 'غير محدد'; // This will be the current engineer
    final clientName = projectData['clientName'] ?? 'غير محدد';
    final projectStatus = projectData['status'] ?? 'غير محدد';
    final lastCompletedPhaseName = projectData['lastCompletedPhaseName'] ?? 'لا توجد مراحل مكتملة بعد'; //
    // Note: 'currentStage' from project document might be different from 'lastCompletedPhaseName' if project is ongoing.
    // We'll use lastCompletedPhaseName as it's specific to engineer's view of progress.

    IconData statusIcon;
    Color statusColor;
    switch (projectStatus) {
      case 'نشط': statusIcon = Icons.construction_rounded; statusColor = AppConstants.infoColor; break;
      case 'مكتمل': statusIcon = Icons.check_circle_outline_rounded; statusColor = AppConstants.successColor; break;
      case 'معلق': statusIcon = Icons.pause_circle_outline_rounded; statusColor = AppConstants.warningColor; break;
      default: statusIcon = Icons.help_outline_rounded; statusColor = AppConstants.textSecondary;
    }

    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingLarge),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
            const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
            _buildDetailRow(Icons.engineering_rounded, 'المهندس المسؤول:', engineerName),
            _buildDetailRow(Icons.person_rounded, 'العميل:', clientName),
            _buildDetailRow(Icons.playlist_add_check_circle_outlined, 'آخر مرحلة مكتملة:', lastCompletedPhaseName),
            _buildDetailRow(statusIcon, 'حالة المشروع:', projectStatus, valueColor: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Text('$label ', style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesSectionHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppConstants.paddingSmall),
      child: Text('مراحل المشروع:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
    );
  }

  Widget _buildPhaseExpansionTile(QueryDocumentSnapshot phase) {
    final data = phase.data() as Map<String, dynamic>;
    final int number = data['number'] ?? 0;
    final String name = data['name'] ?? 'مرحلة غير مسمى';
    final String note = data['note'] ?? '';
    final bool completed = data['completed'] ?? false;
    final bool hasSubPhases = data['hasSubPhases'] ?? false; //
    final String? imageUrl = data['imageUrl'];
    final String? image360Url = data['image360Url'];

    bool canEngineerEditThisPhase = (_currentUserRole == 'engineer' && !completed); //
    bool canShare = completed && _currentUserRole == 'engineer';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
      elevation: 1.5,
      shadowColor: AppConstants.primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
      child: ExpansionTile(
        collapsedBackgroundColor: completed ? AppConstants.successColor.withOpacity(0.05) : AppConstants.cardColor,
        backgroundColor: AppConstants.cardColor,
        leading: CircleAvatar(
          backgroundColor: completed ? AppConstants.successColor : AppConstants.primaryColor,
          child: Text(number.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text('المرحلة $number: $name', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
        subtitle: Text(completed ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: completed ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEngineerEditThisPhase) IconButton(icon: const Icon(Icons.edit_note_rounded, color: AppConstants.primaryLight), tooltip: 'تحديث المرحلة', onPressed: () => _updatePhase(phase.id, data)),
            if (canShare) IconButton(icon: const Icon(Icons.share_rounded, color: Colors.teal), tooltip: 'مشاركة التقرير', onPressed: () {
              final Map<String, dynamic> phaseDataWithId = Map<String, dynamic>.from(data);
              phaseDataWithId['id'] = phase.id;
              _showShareReportOptionsDialog(phaseDataWithId);
            }),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium).copyWith(top: AppConstants.paddingSmall),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.isNotEmpty) ...[
                  const Text('الملاحظات:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  const SizedBox(height: AppConstants.paddingSmall / 2),
                  ExpandableText(note, valueColor: AppConstants.textSecondary),
                  const SizedBox(height: AppConstants.itemSpacing),
                ],
                if (imageUrl != null) _buildImageSectionDisplay('صورة عادية:', imageUrl),
                if (image360Url != null) _buildImageSectionDisplay('صورة 360°:', image360Url),
                if (note.isEmpty && imageUrl == null && image360Url == null && !hasSubPhases)
                  const Text('لا توجد تفاصيل إضافية لهذه المرحلة.', style: TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                if (hasSubPhases) _buildSubPhasesSection(phase.id, name, canEngineerEditThisPhase),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSectionDisplay(String title, String? imageUrl) { // Simplified for display only
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
        const SizedBox(height: AppConstants.paddingSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
          child: Image.network(
            imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 180, alignment: Alignment.center, child: const CircularProgressIndicator(color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => Container(height: 180, width: double.infinity, color: AppConstants.backgroundColor, child: const Icon(Icons.broken_image_outlined, color: AppConstants.textSecondary, size: 50)),
          ),
        ),
        const SizedBox(height: AppConstants.itemSpacing),
      ],
    );
  }

  Widget _buildSubPhasesSection(String phaseId, String mainPhaseName, bool canParentPhaseBeEditedByEngineer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppConstants.itemSpacing * 1.5, thickness: 0.5),
        const Text('المراحل الفرعية:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
        const SizedBox(height: AppConstants.paddingSmall),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').doc(phaseId).collection('subPhases').orderBy('timestamp').snapshots(),
          builder: (context, subPhaseSnapshot) {
            if (subPhaseSnapshot.connectionState == ConnectionState.waiting) return const Center(child: SizedBox(height:30, width:30, child: CircularProgressIndicator(strokeWidth: 2,color: AppConstants.primaryColor)));
            if (subPhaseSnapshot.hasError) return Text('خطأ: ${subPhaseSnapshot.error}', style: const TextStyle(color: AppConstants.errorColor));
            if (!subPhaseSnapshot.hasData || subPhaseSnapshot.data!.docs.isEmpty) return const Text('لا توجد مراحل فرعية مضافة.', style: TextStyle(color: AppConstants.textSecondary));

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subPhaseSnapshot.data!.docs.length,
              itemBuilder: (context, subIndex) {
                final subPhase = subPhaseSnapshot.data!.docs[subIndex];
                final subData = subPhase.data() as Map<String, dynamic>;
                final String subName = subData['name'] ?? 'مرحلة فرعية غير مسمى';
                final bool subCompleted = subData['completed'] ?? false;
                // Engineer can edit sub-phase if the sub-phase itself is not completed AND the parent phase is also editable by them (not completed)
                bool canEngineerEditThisSubPhase = (_currentUserRole == 'engineer' && !subCompleted && canParentPhaseBeEditedByEngineer);


                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall / 2, vertical: AppConstants.paddingSmall/4),
                  leading: Icon(subCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: subCompleted ? AppConstants.successColor : AppConstants.warningColor, size: 22),
                  title: Text(subName, style: TextStyle(fontWeight: FontWeight.w500, color: AppConstants.textPrimary, fontSize: 15, decoration: subCompleted ? TextDecoration.lineThrough : null)),
                  trailing: canEngineerEditThisSubPhase
                      ? IconButton(icon: const Icon(Icons.edit_rounded, color: AppConstants.primaryLight, size: 20), tooltip: 'تحديث المرحلة الفرعية', onPressed: () => _updateSubPhase(phaseId, subPhase.id, subData))
                      : null,
                  onTap: canEngineerEditThisSubPhase ? () => _updateSubPhase(phaseId, subPhase.id, subData) : null,
                );
              },
            );
          },
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isPageLoading || _currentUserRole == null) {
      return Scaffold(appBar: _buildAppBar(), body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)));
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: FutureBuilder<DocumentSnapshot>(
          key: _projectFutureBuilderKey,
          future: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            if (projectSnapshot.hasError) return Center(child: Text('خطأ: ${projectSnapshot.error}', style: const TextStyle(color: AppConstants.errorColor)));
            if (!projectSnapshot.hasData || !projectSnapshot.data!.exists) return const Center(child: Text('المشروع غير موجود.', style: TextStyle(color: AppConstants.textSecondary, fontSize: 18)));

            final projectData = projectSnapshot.data!.data() as Map<String, dynamic>;
            return RefreshIndicator(
              onRefresh: () async {
                if (mounted) {
                  setState(() { // Force re-fetch of project data and then sub-collections
                    _projectFutureBuilderKey = UniqueKey();
                  });
                }
              },
              color: AppConstants.primaryColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProjectSummaryCard(projectData),
                    const SizedBox(height: AppConstants.itemSpacing),
                    _buildPhasesSectionHeader(),
                    const SizedBox(height: AppConstants.paddingSmall),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).collection('phases').orderBy('number').snapshots(),
                      builder: (context, phaseSnapshot) {
                        if (phaseSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                        if (phaseSnapshot.hasError) return Text('خطأ تحميل المراحل: ${phaseSnapshot.error}', style: const TextStyle(color: AppConstants.errorColor));
                        if (!phaseSnapshot.hasData || phaseSnapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(AppConstants.paddingMedium), child: Text('لا توجد مراحل مضافة لهذا المشروع بعد.', style: TextStyle(fontSize: 16, color: AppConstants.textSecondary))));

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: phaseSnapshot.data!.docs.length,
                          itemBuilder: (context, index) => _buildPhaseExpansionTile(phaseSnapshot.data!.docs[index]),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Helper widget for expandable text (same as in admin_project_details_page)
class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final Color? valueColor;

  const ExpandableText(this.text, {super.key, this.trimLines = 2, this.valueColor});

  @override
  ExpandableTextState createState() => ExpandableTextState();
}

class ExpandableTextState extends State<ExpandableText> {
  bool _readMore = true;
  void _onTapLink() {
    setState(() => _readMore = !_readMore);
  }

  @override
  Widget build(BuildContext context) {
    TextSpan link = TextSpan(
        text: _readMore ? " عرض المزيد" : " عرض أقل",
        style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w600, fontSize: 14),
        recognizer: TapGestureRecognizer()..onTap = _onTapLink
    );
    Widget result = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        assert(constraints.hasBoundedWidth);
        final double maxWidth = constraints.maxWidth;
        final text = TextSpan(text: widget.text, style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5));
        TextPainter textPainter = TextPainter(
          text: link,
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          maxLines: widget.trimLines,
          ellipsis: '...',
        );
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final linkSize = textPainter.size;
        textPainter.text = text;
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final textSize = textPainter.size;
        int endIndex = textPainter.getPositionForOffset(Offset(textSize.width - linkSize.width, textSize.height)).offset;
        TextSpan textSpan;
        if (textPainter.didExceedMaxLines) {
          textSpan = TextSpan(
            text: _readMore && widget.text.length > endIndex ? widget.text.substring(0, endIndex) + "..." : widget.text,
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5),
            children: <TextSpan>[link],
          );
        } else {
          textSpan = TextSpan(text: widget.text, style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5));
        }
        return RichText(
          softWrap: true,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          text: textSpan,
        );
      },
    );
    return result;
  }
}