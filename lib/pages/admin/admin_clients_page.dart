// lib/pages/admin/admin_clients_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Constants for consistent styling, aligned with the admin dashboard's style.
class AppConstants {
  // Primary colors
  static const Color primaryColor = Color(0xFF2563EB); // Modern blue
  static const Color primaryLight = Color(0xFF3B82F6); // Lighter blue

  // Status and feedback colors
  static const Color successColor = Color(0xFF10B981); // Emerald green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color infoColor = Color(0xFF3B82F6); // Blue

  // UI element colors
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC); // Soft background
  static const Color deleteColor = errorColor;

  // Text colors
  static const Color textPrimary = Color(0xFF1F2937); // Dark gray
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray

  // Spacing and dimensions
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;

  // Shadows for depth
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}

class AdminClientsPage extends StatefulWidget {
  const AdminClientsPage({super.key});

  @override
  State<AdminClientsPage> createState() => _AdminClientsPageState();
}

class _AdminClientsPageState extends State<AdminClientsPage> {
  /// Deletes a client from Firestore.
  ///
  /// Note: Deleting from Firebase Auth requires admin privileges and is best handled
  /// via a backend function (e.g., Cloud Functions) for security reasons.
  Future<void> _deleteClient(String uid, String email) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف العميل $email؟ هذا الإجراء لا يمكن التراجع عنه.'),
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
        _showFeedbackSnackBar(context, 'تم حذف العميل $email بنجاح.', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل حذف العميل: $e', isError: true);
      }
    }
  }

  /// Displays the dialog for adding a new client.
  Future<void> _showAddClientDialog() async {
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
                'إضافة عميل جديد',
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
                        labelText: 'الاسم الكامل',
                        icon: Icons.person_outline,
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
                        'role': 'client',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تم إضافة العميل بنجاح.', isError: false);
                    } on FirebaseAuthException catch (e) {
                      _showFeedbackSnackBar(context, _getFirebaseErrorMessage(e.code), isError: true);
                      Navigator.pop(dialogContext); // Close dialog on error
                    } catch (e) {
                      _showFeedbackSnackBar(context, 'فشل الإضافة: $e', isError: true);
                      Navigator.pop(dialogContext); // Close dialog on error
                    }
                  },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.person_add_alt_1, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('إضافة العميل', style: TextStyle(color: Colors.white)),
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
              .where('role', isEqualTo: 'client')
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

            final clients = snapshot.data!.docs;
            return _buildClientsList(clients);
          },
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  /// Builds the main application bar.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'إدارة العملاء',
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

  /// Builds the list of client cards.
  Widget _buildClientsList(List<QueryDocumentSnapshot> clients) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final data = client.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'اسم غير متوفر';
        final email = data['email'] ?? 'بريد غير متوفر';
        final uid = client.id;

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
                  child: const Icon(Icons.person_outline, size: 30, color: AppConstants.primaryColor),
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
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppConstants.deleteColor),
                  onPressed: () => _deleteClient(uid, email),
                  tooltip: 'حذف العميل',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the floating action button for adding new clients.
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddClientDialog,
      backgroundColor: AppConstants.primaryColor,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'إضافة عميل',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      tooltip: 'إضافة عميل جديد',
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
            Text(
              'عذراً، حدث خطأ',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
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

  /// Builds a widget to display when there are no clients.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 100, color: AppConstants.textSecondary.withOpacity(0.5)),
          const SizedBox(height: AppConstants.itemSpacing),
          const Text(
            'لا يوجد عملاء بعد',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'انقر على زر "إضافة عميل" لبدء الإضافة.',
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
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب.';
        }
        if (validator != null) {
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