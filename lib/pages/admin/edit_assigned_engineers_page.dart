// lib/pages/admin/edit_assigned_engineers_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // For TextDirection

// افترض أن AppConstants معرفة في مكان ما ويمكن استيرادها
// أو قم بنسخها هنا كما فعلنا سابقًا
// import 'admin_projects_page.dart'; // أو أي ملف يحتوي على AppConstants

// --- نسخ AppConstants هنا مؤقتًا ---
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;
}
// --- نهاية نسخ AppConstants ---


class EditAssignedEngineersPage extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<Map<String, dynamic>> currentlyAssignedEngineers; // قائمة بالكائنات {uid, name}
  final List<QueryDocumentSnapshot> allAvailableEngineers;

  const EditAssignedEngineersPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.currentlyAssignedEngineers,
    required this.allAvailableEngineers,
  });

  @override
  State<EditAssignedEngineersPage> createState() => _EditAssignedEngineersPageState();
}

class _EditAssignedEngineersPageState extends State<EditAssignedEngineersPage> {
  late List<String> _selectedEngineerIds;
  final _formKey = GlobalKey<FormState>(); // مفتاح للـ FormField
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // تهيئة قائمة المهندسين المختارين مبدئيًا بناءً على المعينين حاليًا
    _selectedEngineerIds = widget.currentlyAssignedEngineers
        .map((eng) => eng['uid'].toString())
        .toList();
  }

  void _showFeedbackSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (widget.allAvailableEngineers.isNotEmpty && _selectedEngineerIds.isEmpty) {
      _showFeedbackSnackBar('الرجاء اختيار مهندس واحد على الأقل.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    List<Map<String, String>> updatedAssignedEngineersList = [];
    List<String> updatedEngineerUidsList = [];

    if (_selectedEngineerIds.isNotEmpty) {
      for (String engineerId in _selectedEngineerIds) {
        final engineerDoc = widget.allAvailableEngineers.firstWhere(
              (doc) => doc.id == engineerId,
        );
        final engineerData = engineerDoc.data() as Map<String, dynamic>;
        updatedAssignedEngineersList.add({
          'uid': engineerId,
          'name': engineerData['name'] ?? 'مهندس غير مسمى',
        });
        updatedEngineerUidsList.add(engineerId);
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'assignedEngineers': updatedAssignedEngineersList,
        'engineerUids': updatedEngineerUidsList,
      });

      _showFeedbackSnackBar('تم تحديث قائمة المهندسين بنجاح.', isError: false);
      if (mounted) {
        Navigator.pop(context, true); // إرجاع true للإشارة إلى أن التحديث تم
      }
    } catch (e) {
      _showFeedbackSnackBar('فشل تحديث قائمة المهندسين: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تعديل مهندسي مشروع: ${widget.projectName}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppConstants.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.primaryColor, AppConstants.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر المهندسين المسؤولين عن المشروع:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              if (widget.allAvailableEngineers.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'لا يوجد مهندسون متاحون في النظام حالياً.',
                      style: TextStyle(color: AppConstants.textSecondary, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Form( // Form يحيط بـ ListView و FormField
                    key: _formKey,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppConstants.textSecondary.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                            ),
                            child: ListView.builder(
                              itemCount: widget.allAvailableEngineers.length,
                              itemBuilder: (context, index) {
                                final engineerDoc = widget.allAvailableEngineers[index];
                                final engineer = engineerDoc.data() as Map<String, dynamic>;
                                final engineerId = engineerDoc.id;
                                final engineerName = engineer['name'] ?? 'مهندس غير مسمى';
                                final bool isSelected = _selectedEngineerIds.contains(engineerId);

                                return CheckboxListTile(
                                  title: Text(engineerName, style: const TextStyle(color: AppConstants.textPrimary)),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        if (!_selectedEngineerIds.contains(engineerId)) {
                                          _selectedEngineerIds.add(engineerId);
                                        }
                                      } else {
                                        _selectedEngineerIds.remove(engineerId);
                                      }
                                      // تحديث FormField يدويًا للتحقق من الصحة عند كل تغيير
                                      _formKey.currentState?.validate();
                                    });
                                  },
                                  activeColor: AppConstants.primaryColor,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        ),
                        // مدقق للمهندسين
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: FormField<List<String>>(
                            initialValue: _selectedEngineerIds,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء اختيار مهندس واحد على الأقل.';
                              }
                              return null;
                            },
                            builder: (FormFieldState<List<String>> fieldState) {
                              return fieldState.hasError
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 5.0),
                                child: Text(
                                  fieldState.errorText!,
                                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                                ),
                              )
                                  : const SizedBox.shrink();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppConstants.paddingLarge),
              ElevatedButton.icon(
                onPressed: _isLoading || widget.allAvailableEngineers.isEmpty ? null : _saveChanges,
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save_alt_rounded, color: Colors.white),
                label: _isLoading
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
                    : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  disabledBackgroundColor: AppConstants.textSecondary.withOpacity(0.5),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium / 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}