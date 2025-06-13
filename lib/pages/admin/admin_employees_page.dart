// lib/pages/admin/admin_employees_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';


class AdminEmployeesPage extends StatefulWidget {
  const AdminEmployeesPage({super.key});

  @override
  State<AdminEmployeesPage> createState() => _AdminEmployeesPageState();
}

class _AdminEmployeesPageState extends State<AdminEmployeesPage> {
  final List<String> _positions = ['فني كهرباء', 'فني سباكة', 'عامل', 'مساعد', 'فني'];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _showAddEmployeeDialog() async { //
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? selectedPosition;

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
                'إضافة موظف جديد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                  fontSize: 22,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStyledTextField(
                        controller: nameController,
                        labelText: 'الاسم الكامل للموظف',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: emailController,
                        labelText: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'صيغة بريد إلكتروني غير صحيحة.';
                          }
                          return null;
                        },
                        isRequired: false,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: passwordController,
                        labelText: 'كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                        validator: (value) {
                          if (value != null && value.length < 6) {
                            return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
                          }
                          return null;
                        },
                        isRequired: false,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      DropdownButtonFormField<String>(
                        value: selectedPosition,
                        decoration: InputDecoration(
                          labelText: 'المهنة',
                          prefixIcon: const Icon(Icons.work_outline_rounded,
                              color: AppConstants.primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius / 1.5),
                          ),
                        ),
                        items: _positions
                            .map((pos) => DropdownMenuItem(
                                  value: pos,
                                  child: Text(pos),
                                ))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedPosition = val),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء اختيار المهنة';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
                ),
                const SizedBox(width: AppConstants.itemSpacing / 2),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isLoading = true);

                          try {
                            if (emailController.text.trim().isNotEmpty &&
                                passwordController.text.trim().isNotEmpty) {
                              final userCred = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                              );

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userCred.user!.uid)
                                .set({
                                'uid': userCred.user!.uid,
                                'email': emailController.text.trim(),
                                'name': nameController.text.trim(),
                                'position': selectedPosition,
                                'role': 'employee',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .add({
                                'name': nameController.text.trim(),
                                'position': selectedPosition,
                                'role': 'employee',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            Navigator.pop(dialogContext);
                            _showFeedbackSnackBar(context, 'تم إضافة الموظف بنجاح.',
                                isError: false);
                          } on FirebaseAuthException catch (e) {
                            _showFeedbackSnackBar(context,
                                _getFirebaseErrorMessage(e.code),
                                isError: true);
                            Navigator.pop(dialogContext);
                          } catch (e) {
                            _showFeedbackSnackBar(context, 'فشل الإضافة: $e',
                                isError: true);
                            Navigator.pop(dialogContext);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                      : const Text('إضافة الموظف', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Dialog for editing an employee
  Future<void> _showEditEmployeeDialog(DocumentSnapshot employeeDoc) async {
    final employeeData = employeeDoc.data() as Map<String, dynamic>;
    final String currentUid = employeeDoc.id;

    final nameController =
        TextEditingController(text: employeeData['name'] ?? '');
    final emailController =
        TextEditingController(text: employeeData['email'] ?? '');
    String? selectedPosition = employeeData['position'];

    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              title: const Text('تعديل بيانات الموظف',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                      fontSize: 22)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStyledTextField(
                        controller: nameController,
                        labelText: 'الاسم الكامل للموظف',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: emailController,
                        labelText: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'صيغة بريد إلكتروني غير صحيحة.';
                          }
                          return null;
                        },
                        isRequired: false,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      DropdownButtonFormField<String>(
                        value: selectedPosition,
                        decoration: InputDecoration(
                          labelText: 'المهنة',
                          prefixIcon: const Icon(Icons.work_outline_rounded,
                              color: AppConstants.primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius / 1.5),
                          ),
                        ),
                        items: _positions
                            .map((pos) => DropdownMenuItem(
                                  value: pos,
                                  child: Text(pos),
                                ))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedPosition = val),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء اختيار المهنة';
                          }
                          return null;
                        },
                      ),
                      // const SizedBox(height: AppConstants.itemSpacing),
                      // const Text(
                      //   'ملاحظة: لتغيير كلمة المرور الخاصة بالمصادقة يجب استخدام وحدة تحكم Firebase.',
                      //   style: TextStyle(
                      //       fontSize: 12,
                      //       color: AppConstants.textSecondary,
                      //       fontStyle: FontStyle.italic),
                      // ),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء',
                      style: TextStyle(color: AppConstants.textSecondary)),
                ),
                const SizedBox(width: AppConstants.itemSpacing / 2),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUid)
                                .update({
                              'name': nameController.text.trim(),
                              'email': emailController.text.trim(),
                              'position': selectedPosition,
                            });
                            Navigator.pop(dialogContext);
                            _showFeedbackSnackBar(
                                context, 'تم تحديث بيانات الموظف بنجاح.',
                                isError: false);
                          } catch (e) {
                            _showFeedbackSnackBar(
                                dialogContext, 'فشل تحديث البيانات: $e',
                                isError: true);
                          } finally {
                            if (mounted) setDialogState(() => isLoading = false);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save_alt_rounded, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white)),
                        )
                      : const Text('حفظ التعديلات',
                          style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius / 2)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteEmployee(String uid, String email) async { //
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف الموظف $email؟ هذا الإجراء سيقوم فقط بإزالة بياناته من قاعدة بيانات التطبيق وليس من نظام المصادقة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.deleteColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2))),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete(); //
        _showFeedbackSnackBar(context, 'تم حذف الموظف $email من قاعدة البيانات.', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل حذف الموظف: $e', isError: true);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'employee')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (snapshot.hasError) {
              return _buildErrorState('حدث خطأ: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }
            final employees = snapshot.data!.docs;
            return _buildEmployeesList(employees);
          },
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'إدارة الموظفين',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22),
      ),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 4,
      centerTitle: true,
    );
  }

  Widget _buildEmployeesList(List<QueryDocumentSnapshot> employees) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        final data = emp.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'اسم غير متوفر';
        final email = data['email'] ?? 'بريد غير متوفر';
        final position = data['position'] ?? 'غير محدد';
        final uid = emp.id;

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
          elevation: 2,
          shadowColor: AppConstants.primaryColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppConstants.primaryLight.withOpacity(0.15),
                  child: const Icon(Icons.badge_outlined, size: 30, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: AppConstants.itemSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        position,
                        style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppConstants.infoColor, size: 26),
                  onPressed: () => _showEditEmployeeDialog(emp),
                  tooltip: 'تعديل الموظف',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.deleteColor, size: 26),
                  onPressed: () => _deleteEmployee(uid, email), //
                  tooltip: 'حذف الموظف',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddEmployeeDialog, //
      backgroundColor: AppConstants.primaryColor,
      icon: const Icon(Icons.group_add_outlined, color: Colors.white),
      label: const Text(
        'إضافة موظف',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      tooltip: 'إضافة موظف جديد',
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 80, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.itemSpacing),
            const Text('عذراً، حدث خطأ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(errorMessage, style: const TextStyle(fontSize: 16, color: AppConstants.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_outlined, size: 100, color: AppConstants.textSecondary.withOpacity(0.5)),
          const SizedBox(height: AppConstants.itemSpacing),
          const Text('لا يوجد موظفون بعد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
          const SizedBox(height: 8),
          const Text('انقر على زر "إضافة موظف" لبدء الإضافة.', style: TextStyle(fontSize: 16, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'هذا الحقل مطلوب.';
        }
        if (validator != null && value != null && value.isNotEmpty) {
          return validator(value);
        }
        return null;
      },
    );
  }


  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getFirebaseErrorMessage(String errorCode) { //
    switch (errorCode) {
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً.';
      default:
        return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }
  }
}