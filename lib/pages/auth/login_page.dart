// lib/pages/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui; // For TextDirection

// AppConstants are mostly preserved from your original login page style
class AppConstants {
  static const Color primaryColor = Color(0xFF2E5BFF);
  static const Color primaryLight = Color(0xFF3B82F6); // Added for consistency
  static const Color accentColor = Color(0xFF64B5F6);
  static const Color surfaceColor = Color(0xFFF8FAFF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color focusBorderColor = Color(0xFF3B82F6);

  static const double padding = 24.0;
  static const double borderRadius = 12.0;
  static const double spacing = 20.0;
  // static const double cardElevation = 8.0; // Will be removed as per request

  static const String appName = 'منصة المهندس';

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2E5BFF), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  // Button specific colors for consistency
  static const Color adminButtonColor1 = Color(0xFFFF6B35);
  static const Color adminButtonColor2 = Color(0xFFFF8E53);
  static const Color engineerButtonColor1 = Color(0xFF4CAF50); // Example: Green for engineer
  static const Color engineerButtonColor2 = Color(0xFF81C784);
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  // Animations removed as per request

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    // AnimationController removed
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white, size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor : isSuccess ? AppConstants.successColor : AppConstants.primaryColor,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loginUser() async { //
    if (!_loginFormKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = userCredential.user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _error = 'معلومات المستخدم غير موجودة. يرجى التواصل مع الدعم.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      String role = userData['role'];
      String userName = userData['name'] ?? 'المستخدم';

      _showSnackBar('مرحباً $userName! تم تسجيل الدخول بنجاح', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      switch (role) {
        case 'admin': Navigator.pushReplacementNamed(context, '/admin'); break;
        case 'engineer': Navigator.pushReplacementNamed(context, '/engineer'); break;
        case 'client': Navigator.pushReplacementNamed(context, '/client'); break;
        default: if (mounted) setState(() => _error = 'نوع المستخدم غير معروف.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _getFirebaseErrorMessage(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginOrRegisterRoleBased({ // New generic function
    required String email,
    required String password,
    required String defaultName,
    required String role,
    required String successRoute,
    required String buttonLabelForError,
  }) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      UserCredential? userCredential;
      bool userExisted = true;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          userExisted = false; // User does not exist or wrong pass, try creating
        } else {
          throw e; // Re-throw other Firebase errors
        }
      }

      if (!userExisted) {
        try {
          userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
          if (userCredential.user != null) {
            await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
              'uid': userCredential.user!.uid, 'email': email, 'name': defaultName, 'role': role, 'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') { // Should not happen if signIn failed with user-not-found
            if (mounted) setState(() => _error = 'فشل تسجيل الدخول كـ $buttonLabelForError: الحساب موجود ببيانات أخرى.');
            return;
          }
          throw e; // Re-throw other creation errors
        }
      }

      if (userCredential?.user == null) {
        if (mounted) setState(() => _error = 'فشل تسجيل الدخول كـ $buttonLabelForError: لم يتم العثور على المستخدم أو إنشاؤه.');
        return;
      }

      // Verify role from Firestore, even if we just created it
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential!.user!.uid).get();
      if (!userDoc.exists || (userDoc.data() as Map<String,dynamic>)['role'] != role) {
        if (mounted) setState(() => _error = 'فشل تسجيل الدخول كـ $buttonLabelForError: الدور غير متطابق أو المستخدم غير مهيأ بشكل صحيح.');
        // Optionally sign out if role mismatch after creation for safety
        // await FirebaseAuth.instance.signOut();
        return;
      }

      String userName = (userDoc.data() as Map<String,dynamic>)['name'] ?? defaultName;
      _showSnackBar('مرحباً $userName! تم تسجيل الدخول كـ $buttonLabelForError بنجاح', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pushReplacementNamed(context, successRoute);

    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = 'فشل تسجيل الدخول كـ $buttonLabelForError: ${_getFirebaseErrorMessage(e.code)}');
    } catch (e) {
      if (mounted) setState(() => _error = 'حدث خطأ غير متوقع عند تسجيل الدخول كـ $buttonLabelForError.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _loginAsAdmin() async { // Uses the generic function
    await _loginOrRegisterRoleBased(
        email: 'z@z.com',
        password: '12345678',
        defaultName: 'مسؤول النظام',
        role: 'admin',
        successRoute: '/admin',
        buttonLabelForError: 'مسؤول'
    );
  }

  Future<void> _loginAsEngineer() async { // Uses the generic function
    await _loginOrRegisterRoleBased(
        email: 'eng@eng.com',
        password: '12345678',
        defaultName: 'مهندس النظام',
        role: 'engineer',
        successRoute: '/engineer',
        buttonLabelForError: 'مهندس'
    );
  }


  String _getFirebaseErrorMessage(String errorCode) { //
    switch (errorCode) {
      case 'user-not-found': return 'المستخدم غير موجود. يرجى التحقق من البريد الإلكتروني.';
      case 'wrong-password': return 'كلمة المرور خاطئة. يرجى المحاولة مرة أخرى.';
      case 'invalid-email': return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-disabled': return 'تم تعطيل هذا الحساب. يرجى التواصل مع الدعم الفني.';
      case 'too-many-requests': return 'تم حظر الوصول مؤقتاً بسبب كثرة المحاولات. يرجى المحاولة خلال دقائق.';
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
      case 'invalid-credential': return 'بيانات تسجيل الدخول غير صحيحة.';
      default: return 'حدث خطأ في المصادقة: $errorCode';
    }
  }

  Future<void> _showRegisterDialog() async { //
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'client';
    final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();
    bool isRegistering = false;
    bool obscureRegisterPassword = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5)),
                elevation: 5, // cardElevation removed, so using a fixed value for dialog
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(AppConstants.padding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
                    gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(gradient: AppConstants.primaryGradient, borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24), SizedBox(width: 8), Text('إنشاء حساب جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))]),
                        ),
                        const SizedBox(height: AppConstants.spacing),
                        Form(
                          key: registerFormKey,
                          child: Column(
                            children: [
                              _buildEnhancedTextField(controller: nameController, label: 'الاسم الكامل', icon: Icons.person_outline_rounded, validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال الاسم الكامل' : (value.length < 2 ? 'الاسم يجب أن يكون حرفين على الأقل' : null)),
                              const SizedBox(height: AppConstants.spacing),
                              _buildEnhancedTextField(controller: emailController, label: 'البريد الإلكتروني', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال البريد الإلكتروني' : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value) ? 'صيغة البريد الإلكتروني غير صحيحة' : null)),
                              const SizedBox(height: AppConstants.spacing),
                              _buildEnhancedTextField(controller: passwordController, label: 'كلمة المرور', icon: Icons.lock_outline_rounded, obscureText: obscureRegisterPassword, suffixIcon: IconButton(icon: Icon(obscureRegisterPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: AppConstants.textSecondary), onPressed: () => setDialogState(() => obscureRegisterPassword = !obscureRegisterPassword)), validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال كلمة المرور' : (value.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null)),
                              const SizedBox(height: AppConstants.spacing),
                              Container(
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppConstants.borderRadius), border: Border.all(color: AppConstants.borderColor), color: AppConstants.cardColor),
                                child: DropdownButtonFormField<String>(
                                  value: selectedRole,
                                  decoration: InputDecoration(labelText: 'نوع المستخدم', prefixIcon: const Icon(Icons.category_outlined, color: AppConstants.primaryColor), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                                  items: const [
                                    DropdownMenuItem(value: 'client', child: Text('عميل', style: TextStyle(color: AppConstants.textPrimary))),
                                    DropdownMenuItem(value: 'engineer', child: Text('مهندس', style: TextStyle(color: AppConstants.textPrimary))),
                                  ],
                                  onChanged: (val) { if (val != null) setDialogState(() => selectedRole = val); },
                                  validator: (value) => (value == null || value.isEmpty) ? 'الرجاء اختيار نوع المستخدم' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacing * 1.5),
                        Row(
                          children: [
                            Expanded(child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius), side: const BorderSide(color: AppConstants.borderColor))), child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)))),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(gradient: AppConstants.primaryGradient, borderRadius: BorderRadius.circular(AppConstants.borderRadius), boxShadow: [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                                child: ElevatedButton(
                                  onPressed: isRegistering ? null : () async {
                                    if (!registerFormKey.currentState!.validate()) return;
                                    setDialogState(() => isRegistering = true);
                                    try {
                                      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
                                      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({'uid': userCred.user!.uid, 'email': emailController.text.trim(), 'name': nameController.text.trim(), 'role': selectedRole, 'createdAt': FieldValue.serverTimestamp()});
                                      Navigator.pop(context);
                                      _showSnackBar('تم إنشاء الحساب بنجاح! يمكنك الآن تسجيل الدخول.', isSuccess: true);
                                    } on FirebaseAuthException catch (e) {
                                      Navigator.pop(context); _showSnackBar('فشل التسجيل: ${_getFirebaseErrorMessage(e.code)}', isError: true);
                                    } catch (e) {
                                      Navigator.pop(context); _showSnackBar('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.', isError: true);
                                    } finally {
                                      if(mounted) setDialogState(() => isRegistering = false);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius))),
                                  child: isRegistering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('إنشاء الحساب', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEnhancedTextField({ //
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container( // Container for shadow is kept as it's per field, not for the whole form
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(color: AppConstants.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
          prefixIcon: Icon(icon, color: AppConstants.primaryColor, size: 22),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius), borderSide: const BorderSide(color: AppConstants.borderColor, width: 1)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius), borderSide: const BorderSide(color: AppConstants.borderColor, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius), borderSide: const BorderSide(color: AppConstants.focusBorderColor, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius), borderSide: const BorderSide(color: AppConstants.errorColor, width: 1)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius), borderSide: const BorderSide(color: AppConstants.errorColor, width: 1.5)),
          filled: true,
          fillColor: AppConstants.cardColor, // Kept fill color for fields
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        ),
      ),
    );
  }

  Widget _buildRoleLoginButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [BoxShadow(color: color1.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: _isLoading ? const SizedBox.shrink() : Icon(icon, color: Colors.white, size: 20),
        label: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16), // Increased padding for better touch target
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          minimumSize: const Size(double.infinity, 50), // Ensure buttons take full width available in their part of Row/Column
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppConstants.backgroundGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.padding),
                // Removed FadeTransition and SlideTransition
                // Removed outer Card/Container that grouped form elements
                child: Form(
                  key: _loginFormKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: AppConstants.primaryGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                        child: const Icon(Icons.engineering_rounded, size: 60, color: Colors.white),
                      ),
                      const SizedBox(height: AppConstants.spacing),
                      const Text(AppConstants.appName, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('مرحباً بك مرة أخرى', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppConstants.textSecondary)),
                      const SizedBox(height: AppConstants.spacing * 1.5), // Adjusted spacing
                      _buildEnhancedTextField(controller: _emailController, label: 'البريد الإلكتروني', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال البريد الإلكتروني' : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value) ? 'صيغة البريد الإلكتروني غير صحيحة' : null)),
                      const SizedBox(height: AppConstants.spacing),
                      _buildEnhancedTextField(controller: _passwordController, label: 'كلمة المرور', icon: Icons.lock_outline_rounded, obscureText: _obscurePassword, suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: AppConstants.textSecondary), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال كلمة المرور' : (value.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null)),
                      const SizedBox(height: AppConstants.spacing),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppConstants.spacing / 2), // Reduced bottom margin
                          padding: const EdgeInsets.all(AppConstants.padding / 1.5), // Reduced padding
                          decoration: BoxDecoration(color: AppConstants.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(AppConstants.borderRadius), border: Border.all(color: AppConstants.errorColor.withOpacity(0.3), width: 1)),
                          child: Row(children: [const Icon(Icons.error_outline_rounded, color: AppConstants.errorColor, size: 20), const SizedBox(width: 12), Expanded(child: Text(_error!, style: const TextStyle(color: AppConstants.errorColor, fontSize: 14, fontWeight: FontWeight.w500)))]),
                        ),

                      // Main Login Button
                      Container(
                        decoration: BoxDecoration(gradient: AppConstants.primaryGradient, borderRadius: BorderRadius.circular(AppConstants.borderRadius), boxShadow: [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _loginUser,
                          icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                          label: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)), minimumSize: const Size(double.infinity, 50)),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacing * 0.75), // Spacing before role login buttons

                      // Role-based login buttons in a Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleLoginButton(
                              label: 'دخول كمسؤول', // Updated label
                              icon: Icons.admin_panel_settings_rounded,
                              onPressed: _loginAsAdmin, // Updated function call
                              color1: AppConstants.adminButtonColor1, // Using specific colors from AppConstants
                              color2: AppConstants.adminButtonColor2,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacing / 2), // Spacing between buttons
                          Expanded(
                            child: _buildRoleLoginButton(
                              label: 'دخول كمهندس',
                              icon: Icons.engineering_rounded,
                              onPressed: _loginAsEngineer,
                              color1: AppConstants.engineerButtonColor1, // Using specific colors
                              color2: AppConstants.engineerButtonColor2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppConstants.spacing * 1.5),
                      Text('© ${DateTime.now().year} ${AppConstants.appName}', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textSecondary.withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}