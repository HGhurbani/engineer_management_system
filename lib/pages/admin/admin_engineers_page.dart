import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Constants for consistent styling and text (يمكنك وضعها في ملف منفصل)
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color deleteColor = Colors.redAccent; // لون لزر الحذف

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class AdminEngineersPage extends StatefulWidget {
  const AdminEngineersPage({super.key});

  @override
  State<AdminEngineersPage> createState() => _AdminEngineersPageState();
}

class _AdminEngineersPageState extends State<AdminEngineersPage> {
  // دالة لحذف المهندس من Firestore و Firebase Auth
  Future<void> _deleteEngineer(String uid, String email) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف المهندس $email؟'),
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

    if (confirm == true) {
      try {
        // حذف المستند من Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();

        // يجب عليك أيضاً حذف المستخدم من Firebase Authentication.
        // هذا يتطلب صلاحيات Admin SDK إذا كنت تحذف من جانب الخادم،
        // أو قد يكون صعباً إذا كنت تحذف من جانب العميل بسبب قيود الأمان (خاصة إذا لم يكن المستخدم الحالي هو المستخدم المحذوف).
        // مثال على محاولة حذف المستخدم من العميل (قد تفشل إذا لم يكن لديك صلاحيات كافية):
        // User? userToDelete = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: "tempPassword"); // هذا ليس عملياً
        // if (userToDelete != null) await userToDelete.delete();
        // **الأفضل: قم بتنفيذ حذف المستخدم من Firebase Auth باستخدام Cloud Functions أو Admin SDK على الخادم.**

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف المهندس $email بنجاح.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف المهندس: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  // دالة لعرض نافذة إضافة مهندس جديد
  Future<void> _addEngineerDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
    bool isLoading = false; // حالة تحميل داخل الـ dialog

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
                        decoration: _inputDecoration('الاسم الكامل', Icons.person_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال الاسم.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('البريد الإلكتروني', Icons.email_outlined),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني.';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'صيغة بريد إلكتروني غير صحيحة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: _inputDecoration('كلمة المرور', Icons.lock_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال كلمة المرور.';
                          }
                          if (value.length < 6) {
                            return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
                          }
                          return null;
                        },
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

                    setDialogState(() {
                      isLoading = true;
                    });

                    try {
                      // إنشاء المستخدم في Firebase Authentication
                      final userCred = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );

                      // إضافة بيانات المستخدم إلى Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userCred.user!.uid)
                          .set({
                        'uid': userCred.user!.uid,
                        'email': emailController.text.trim(),
                        'name': nameController.text.trim(),
                        'role': 'engineer',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(dialogContext); // إغلاق الـ dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إضافة المهندس بنجاح.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } on FirebaseAuthException catch (e) {
                      setDialogState(() {
                        isLoading = false; // توقف التحميل عند الخطأ
                      });
                      _showErrorSnackBar(context, _getFirebaseErrorMessage(e.code));
                    } catch (e) {
                      setDialogState(() {
                        isLoading = false; // توقف التحميل عند الخطأ
                      });
                      _showErrorSnackBar(context, 'فشل الإضافة: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
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

  // دالة مساعدة لإنشاء InputDecoration موحد
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

  // دالة مساعدة لعرض SnackBar للأخطاء
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  // دالة مساعدة للحصول على رسائل خطأ Firebase
  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً.';
      default:
        return 'حدث خطأ: $errorCode';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'إدارة المهندسين',
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
        body: StreamBuilder<QuerySnapshot>(
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
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
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
                    Icon(Icons.engineering, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Text(
                      'لا يوجد مهندسون مسجلون حتى الآن.',
                      style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                    ),
                  ],
                ),
              );
            }

            final engineers = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(AppConstants.padding / 2),
              itemCount: engineers.length,
              itemBuilder: (context, index) {
                final eng = engineers[index];
                final data = eng.data() as Map<String, dynamic>; // Cast to Map<String, dynamic>
                final name = data['name'] as String? ?? 'اسم غير متوفر';
                final email = data['email'] as String? ?? 'بريد غير متوفر';
                final uid = eng.id; // UID هو معرف المستند

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: AppConstants.accentColor.withOpacity(0.2),
                      child: Icon(Icons.person, color: AppConstants.primaryColor),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.secondaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // يمكنك إضافة زر للتعديل هنا
                        // IconButton(
                        //   icon: const Icon(Icons.edit, color: Colors.blue),
                        //   onPressed: () {
                        //     // TODO: Implement edit functionality
                        //   },
                        // ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppConstants.deleteColor),
                          onPressed: () async {
                            await _deleteEngineer(uid, email);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      // يمكنك الانتقال إلى صفحة تفاصيل المهندس
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تفاصيل المهندس: $name')),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addEngineerDialog(context),
          backgroundColor: AppConstants.primaryColor,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'إضافة مهندس',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          tooltip: 'إضافة مهندس جديد',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat, // لتوسيط الزر
      ),
    );
  }
}