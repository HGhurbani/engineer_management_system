// lib/pages/admin/admin_engineers_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AdminEngineersPage extends StatefulWidget {
  const AdminEngineersPage({super.key});

  @override
  State<AdminEngineersPage> createState() => _AdminEngineersPageState();
}

class _AdminEngineersPageState extends State<AdminEngineersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterEngineers(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final query = _searchQuery.toLowerCase();
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final email = data['email']?.toString().toLowerCase() ?? '';
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'البحث في المهندسين...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }
  /// Deletes an engineer from Firestore.
  ///
  /// IMPORTANT: Deleting a user from Firebase Authentication is a sensitive operation
  /// and typically requires admin privileges not directly available in client-side code
  /// for deleting *other* users. This function only deletes the user's record from
  /// Firestore. True deletion from Firebase Auth should be handled via a backend
  /// mechanism (e.g., Cloud Functions with Admin SDK) for security and proper execution.
  Future<void> _deleteEngineer(String uid, String email) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف المهندس $email؟ هذا الإجراء سيقوم فقط بإزالة بياناته من قاعدة بيانات التطبيق وليس من نظام المصادقة.'),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                ),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        _showFeedbackSnackBar(context, 'تم حذف المهندس $email من قاعدة البيانات.', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل حذف المهندس: $e', isError: true);
      }
    }
  }

  /// Displays the dialog for adding a new engineer.
  Future<void> _showAddEngineerDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
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
                'إضافة مهندس جديد',
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
                        labelText: 'الاسم الكامل للمهندس',
                        icon: Icons.engineering_outlined,
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
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: passwordController,
                        labelText: 'كلمة المرور',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value != null && value.length < 6) {
                            return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
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
                  onPressed: isLoading ? null : () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() => isLoading = true);

                    try {
                      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );

                      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
                        'uid': userCred.user!.uid,
                        'email': emailController.text.trim(),
                        'name': nameController.text.trim(),
                        'role': 'engineer', // Set role to 'engineer'
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تم إضافة المهندس بنجاح.', isError: false);
                    } on FirebaseAuthException catch (e) {
                      _showFeedbackSnackBar(context, _getFirebaseErrorMessage(e.code), isError: true);
                      Navigator.pop(dialogContext);
                    } catch (e) {
                      _showFeedbackSnackBar(context, 'فشل الإضافة: $e', isError: true);
                      Navigator.pop(dialogContext);
                    }
                  },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('إضافة مهندس', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Dialog for editing an existing engineer
  Future<void> _showEditEngineerDialog(DocumentSnapshot engineerDoc) async {
    final engineerData = engineerDoc.data() as Map<String, dynamic>;
    final String currentUid = engineerDoc.id;

    final nameController = TextEditingController(text: engineerData['name'] ?? '');
    final emailController = TextEditingController(text: engineerData['email'] ?? '');

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
              title: const Text('تعديل بيانات المهندس',
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
                        labelText: 'الاسم الكامل للمهندس',
                        icon: Icons.engineering_outlined,
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
                            });
                            Navigator.pop(dialogContext);
                            _showFeedbackSnackBar(
                                context, 'تم تحديث بيانات المهندس بنجاح.',
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'engineer')
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

                  final engineers = _filterEngineers(snapshot.data!.docs);
                  return _buildEngineersList(engineers);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  /// Builds the main application bar.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'إدارة المهندسين',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
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

  /// Builds the list of engineer cards.
  Widget _buildEngineersList(List<QueryDocumentSnapshot> engineers) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: engineers.length,
      itemBuilder: (context, index) {
        final engineer = engineers[index];
        final data = engineer.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'اسم غير متوفر';
        final email = data['email'] ?? 'بريد غير متوفر';
        final uid = engineer.id;

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
          elevation: 2,
          shadowColor: AppConstants.primaryColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppConstants.primaryLight.withOpacity(0.15),
                  // Changed icon for engineers
                  child: const Icon(Icons.engineering_outlined, size: 30, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: AppConstants.itemSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppConstants.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditEngineerDialog(engineer);
                        break;
                      case 'delete':
                        _deleteEngineer(uid, email);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(Icons.edit_outlined, color: AppConstants.infoColor),
                          SizedBox(width: 8),
                          Text('تعديل المهندس'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline, color: AppConstants.deleteColor),
                          SizedBox(width: 8),
                          Text('حذف المهندس'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the floating action button for adding new engineers.
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddEngineerDialog,
      backgroundColor: AppConstants.primaryColor,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'إضافة مهندس', // Changed label
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      tooltip: 'إضافة مهندس جديد',
    );
  }

  /// Builds a widget to display when there's an error fetching data.
  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.itemSpacing),
            const Text(
              'عذراً، حدث خطأ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 16, color: AppConstants.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a widget to display when there are no engineers.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Changed icon for engineers
          Icon(Icons.engineering_outlined, size: 100, color: AppConstants.textSecondary.withOpacity(0.5)),
          const SizedBox(height: AppConstants.itemSpacing),
          const Text(
            'لا يوجد مهندسون بعد', // Changed text
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'انقر على زر "إضافة مهندس" لبدء الإضافة.', // Changed text
            style: TextStyle(fontSize: 16, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Creates a consistently styled text field for dialogs.
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

  /// Shows a feedback SnackBar (for success or error).
  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Translates Firebase Auth error codes into Arabic.
  String _getFirebaseErrorMessage(String errorCode) {
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