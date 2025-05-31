// lib/pages/admin/add_project_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // For TextDirection

// يمكنك استخدام نفس AppConstants الموجودة في admin_projects_page.dart
// أو تعريفها هنا إذا كنت ستستخدمها بكثرة في هذه الصفحة فقط.
// للتبسيط، سأفترض أنك ستستوردها أو ستعرفها.
// import 'admin_projects_page.dart'; // افترض أن AppConstants موجودة هنا أو في ملف منفصل

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


class AddProjectPage extends StatefulWidget {
  final List<QueryDocumentSnapshot> availableEngineers;
  final List<QueryDocumentSnapshot> availableClients;

  const AddProjectPage({
    super.key,
    required this.availableEngineers,
    required this.availableClients,
  });

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<String> _selectedEngineerIds = [];
  String? _selectedClientId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // التحقق من اختيار مهندس واحد على الأقل إذا كانت قائمة المهندسين المتاحين غير فارغة
    if (_selectedEngineerIds.isEmpty && widget.availableEngineers.isNotEmpty) {
      _showFeedbackSnackBar('الرجاء اختيار مهندس واحد على الأقل.', isError: true);
      return;
    }
    // التحقق من اختيار عميل إذا كانت قائمة العملاء المتاحين غير فارغة
    if (_selectedClientId == null && widget.availableClients.isNotEmpty) {
      _showFeedbackSnackBar('الرجاء اختيار العميل.', isError: true);
      return;
    }


    setState(() => _isLoading = true);

    try {
      List<Map<String, String>> assignedEngineersList = [];
      List<String> engineerUidsList = [];

      if (_selectedEngineerIds.isNotEmpty) {
        for (String engineerId in _selectedEngineerIds) {
          final engineerDoc = widget.availableEngineers.firstWhere(
                (doc) => doc.id == engineerId,
          );
          final engineerData = engineerDoc.data() as Map<String, dynamic>;
          assignedEngineersList.add({
            'uid': engineerId,
            'name': engineerData['name'] ?? 'مهندس غير مسمى',
          });
          engineerUidsList.add(engineerId);
        }
      }

      final clientDoc = widget.availableClients.firstWhere((doc) => doc.id == _selectedClientId);
      final clientData = clientDoc.data() as Map<String, dynamic>;
      final clientName = clientData['name'] ?? 'عميل غير مسمى';

      await FirebaseFirestore.instance.collection('projects').add({
        'name': _nameController.text.trim(),
        'assignedEngineers': assignedEngineersList,
        'engineerUids': engineerUidsList,
        'clientId': _selectedClientId,
        'clientName': clientName,
        'currentStage': 0,
        'currentPhaseName': 'لا توجد مراحل بعد',
        'status': 'نشط',
        'createdAt': FieldValue.serverTimestamp(),
        'generalNotes': '',
      });

      _showFeedbackSnackBar('تم إضافة المشروع بنجاح.', isError: false);
      if (mounted) {
        Navigator.pop(context, true); // إرجاع true للإشارة إلى النجاح
      }
    } catch (e) {
      _showFeedbackSnackBar('فشل إضافة المشروع: $e', isError: true);
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
          title: const Text('إضافة مشروع جديد', style: TextStyle(color: Colors.white)),
          backgroundColor: AppConstants.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white), // لتلوين أيقونة الرجوع
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
          child: Form(
            key: _formKey,
            child: ListView( // استخدام ListView للسماح بالتمرير إذا كان المحتوى طويلاً
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المشروع',
                    prefixIcon: Icon(Icons.work_outline_rounded, color: AppConstants.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال اسم المشروع.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.itemSpacing * 1.5), // زيادة المسافة

                const Text(
                  'اختر المهندسين المسؤولين:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                if (widget.availableEngineers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
                    child: Text(
                      'لا يوجد مهندسون متاحون حالياً. يرجى إضافتهم أولاً من قسم إدارة المهندسين.',
                      style: TextStyle(color: AppConstants.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.25,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.textSecondary.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.availableEngineers.length,
                      itemBuilder: (ctx, index) {
                        final engineerDoc = widget.availableEngineers[index];
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
                            });
                          },
                          activeColor: AppConstants.primaryColor,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
                  ),
                // مدقق للمهندسين
                if (widget.availableEngineers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 0), // تقليل المسافة
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

                const SizedBox(height: AppConstants.itemSpacing * 1.5),

                if (widget.availableClients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
                    child: Text(
                      'لا يوجد عملاء متاحون حالياً. يرجى إضافتهم أولاً من قسم إدارة العملاء.',
                      style: TextStyle(color: AppConstants.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'اختر العميل',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppConstants.primaryColor),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.availableClients.map((doc) {
                      final user = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(user['name'] ?? 'عميل غير مسمى'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClientId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'الرجاء اختيار العميل.';
                      }
                      return null;
                    },
                    isExpanded: true,
                    menuMaxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),

                const SizedBox(height: AppConstants.paddingLarge * 1.5),
                ElevatedButton.icon(
                  onPressed: (_isLoading || (widget.availableEngineers.isEmpty || widget.availableClients.isEmpty)) ? null : _submitProject,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  label: _isLoading
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                      : const Text('إضافة المشروع', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    minimumSize: const Size(double.infinity, 50), // جعل الزر بعرض الشاشة
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium / 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}