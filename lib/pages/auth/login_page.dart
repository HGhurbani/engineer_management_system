import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// تحسين الألوان والقيم الثابتة لتكون أكثر راحة للعين
class AppConstants {
  static const Color primaryColor = Color(0xFF2E5BFF); // أزرق ناعم ومريح
  static const Color accentColor = Color(0xFF64B5F6); // أزرق فاتح للإضاءة
  static const Color surfaceColor = Color(0xFFF8FAFF); // خلفية ناعمة
  static const Color cardColor = Color(0xFFFFFFFF); // أبيض نقي للكروت
  static const Color textPrimary = Color(0xFF1A1D29); // نص رئيسي داكن
  static const Color textSecondary = Color(0xFF6B7280); // نص ثانوي رمادي
  static const Color errorColor = Color(0xFFEF4444); // أحمر ناعم للأخطاء
  static const Color successColor = Color(0xFF10B981); // أخضر للنجاح
  static const Color borderColor = Color(0xFFE5E7EB); // حدود ناعمة
  static const Color focusBorderColor = Color(0xFF3B82F6); // حدود التركيز

  static const double padding = 24.0;
  static const double borderRadius = 12.0;
  static const double spacing = 20.0;
  static const double cardElevation = 8.0;

  static const String appName = 'منصة المهندس';

  // تدرجات لونية جميلة
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
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // دالة إظهار رسائل التوجيه والنجاح
  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline :
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor :
        isSuccess ? AppConstants.successColor : AppConstants.primaryColor,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loginUser() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _error = 'معلومات المستخدم غير موجودة في قاعدة البيانات. يرجى التواصل مع الدعم.';
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      String role = userDoc['role'];
      String userName = userDoc['name'] ?? 'المستخدم';

      _showSnackBar('مرحباً $userName! تم تسجيل الدخول بنجاح', isSuccess: true);

      // تأخير بسيط لإظهار رسالة النجاح قبل التنقل
      await Future.delayed(const Duration(milliseconds: 1500));

      switch (role) {
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        case 'engineer':
          Navigator.pushReplacementNamed(context, '/engineer');
          break;
        case 'client':
          Navigator.pushReplacementNamed(context, '/client');
          break;
        default:
          setState(() {
            _error = 'نوع المستخدم غير معروف. يرجى التواصل مع الدعم.';
          });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'المستخدم غير موجود. يرجى التحقق من البريد الإلكتروني أو إنشاء حساب جديد.';
      case 'wrong-password':
        return 'كلمة المرور خاطئة. يرجى المحاولة مرة أخرى.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب. يرجى التواصل مع الدعم الفني.';
      case 'too-many-requests':
        return 'تم حظر الوصول مؤقتاً بسبب كثرة المحاولات. يرجى المحاولة خلال دقائق.';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
      case 'invalid-credential':
        return 'بيانات تسجيل الدخول غير صحيحة. يرجى التحقق من البيانات.';
      default:
        return 'حدث خطأ في المصادقة: $errorCode';
    }
  }

  Future<void> _createTestAdminAccount() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    const String testEmail = 'z@z.com';
    const String testPassword = '12345678';
    const String testName = 'مسؤول تجريبي';
    const String testRole = 'admin';

    try {
      UserCredential? userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        _showSnackBar('تم تسجيل الدخول بالحساب التجريبي بنجاح', isSuccess: true);
        await Future.delayed(const Duration(milliseconds: 1500));
        Navigator.pushReplacementNamed(context, '/admin');
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // المتابعة لإنشاء حساب جديد
        } else {
          setState(() {
            _error = 'فشل تسجيل الدخول التجريبي: ${_getFirebaseErrorMessage(e.code)}';
          });
          return;
        }
      }

      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );

      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'email': testEmail,
          'name': testName,
          'role': testRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _showSnackBar('تم إنشاء الحساب التجريبي وتسجيل الدخول بنجاح', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 1500));
      Navigator.pushReplacementNamed(context, '/admin');

    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = 'فشل إنشاء الحساب التجريبي: ${_getFirebaseErrorMessage(e.code)}';
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ غير متوقع عند إنشاء الحساب التجريبي.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showRegisterDialog() async {
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
              textDirection: TextDirection.rtl,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
                ),
                elevation: AppConstants.cardElevation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(AppConstants.padding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // رأس الحوار
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppConstants.primaryGradient,
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.person_add, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'إنشاء حساب جديد',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacing),

                        Form(
                          key: registerFormKey,
                          child: Column(
                            children: [
                              _buildEnhancedTextField(
                                controller: nameController,
                                label: 'الاسم الكامل',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال الاسم الكامل';
                                  }
                                  if (value.length < 2) {
                                    return 'الاسم يجب أن يكون حرفين على الأقل';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppConstants.spacing),

                              _buildEnhancedTextField(
                                controller: emailController,
                                label: 'البريد الإلكتروني',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال البريد الإلكتروني';
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                    return 'صيغة البريد الإلكتروني غير صحيحة';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppConstants.spacing),

                              _buildEnhancedTextField(
                                controller: passwordController,
                                label: 'كلمة المرور',
                                icon: Icons.lock_outline,
                                obscureText: obscureRegisterPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscureRegisterPassword ? Icons.visibility : Icons.visibility_off,
                                    color: AppConstants.textSecondary,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      obscureRegisterPassword = !obscureRegisterPassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'الرجاء إدخال كلمة المرور';
                                  }
                                  if (value.length < 6) {
                                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppConstants.spacing),

                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                  border: Border.all(color: AppConstants.borderColor),
                                  color: AppConstants.cardColor,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: selectedRole,
                                  decoration: InputDecoration(
                                    labelText: 'نوع المستخدم',
                                    prefixIcon: const Icon(Icons.category_outlined, color: AppConstants.primaryColor),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'client',
                                        child: Text('عميل', style: TextStyle(color: AppConstants.textPrimary))
                                    ),
                                    DropdownMenuItem(
                                        value: 'engineer',
                                        child: Text('مهندس', style: TextStyle(color: AppConstants.textPrimary))
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedRole = val;
                                      });
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء اختيار نوع المستخدم';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacing * 1.5),

                        // أزرار العمل
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                    side: const BorderSide(color: AppConstants.borderColor),
                                  ),
                                ),
                                child: const Text(
                                  'إلغاء',
                                  style: TextStyle(
                                    color: AppConstants.textSecondary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppConstants.primaryGradient,
                                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppConstants.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isRegistering ? null : () async {
                                    if (!registerFormKey.currentState!.validate()) return;

                                    setDialogState(() {
                                      isRegistering = true;
                                    });

                                    try {
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
                                        'role': selectedRole,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });

                                      Navigator.pop(context);
                                      _showSnackBar('تم إنشاء الحساب بنجاح! يمكنك الآن تسجيل الدخول', isSuccess: true);
                                    } on FirebaseAuthException catch (e) {
                                      Navigator.pop(context);
                                      _showSnackBar('فشل التسجيل: ${_getFirebaseErrorMessage(e.code)}', isError: true);
                                    } catch (e) {
                                      Navigator.pop(context);
                                      _showSnackBar('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى', isError: true);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                    ),
                                  ),
                                  child: isRegistering
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                      : const Text(
                                    'إنشاء الحساب',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(
          color: AppConstants.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppConstants.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppConstants.primaryColor, size: 22),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: const BorderSide(color: AppConstants.borderColor, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: const BorderSide(color: AppConstants.borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: const BorderSide(color: AppConstants.focusBorderColor, width: 2),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppConstants.backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.padding),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Card(
                        elevation: AppConstants.cardElevation,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(AppConstants.padding * 1.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Form(
                            key: _loginFormKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // شعار التطبيق
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: AppConstants.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppConstants.primaryColor.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.engineering,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spacing),

                                // عنوان التطبيق
                                const Text(
                                  AppConstants.appName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'مرحباً بك مرة أخرى',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppConstants.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spacing * 2),

                                // حقل البريد الإلكتروني
                                _buildEnhancedTextField(
                                  controller: _emailController,
                                  label: 'البريد الإلكتروني',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال البريد الإلكتروني';
                                    }
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                      return 'صيغة البريد الإلكتروني غير صحيحة';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppConstants.spacing),

                                // حقل كلمة المرور
                                _buildEnhancedTextField(
                                  controller: _passwordController,
                                  label: 'كلمة المرور',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                      color: AppConstants.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال كلمة المرور';
                                    }
                                    if (value.length < 6) {
                                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppConstants.spacing),

                                // رسالة الخطأ
                                if (_error != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: AppConstants.spacing),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppConstants.errorColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                      border: Border.all(
                                        color: AppConstants.errorColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: AppConstants.errorColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: AppConstants.errorColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // زر تسجيل الدخول
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: AppConstants.primaryGradient,
                                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppConstants.primaryColor.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _loginUser,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                        : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spacing),





                                // زر الحساب التجريبي
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B35).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: TextButton(
                                    onPressed: _isLoading ? null : _createTestAdminAccount,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'حساب مسؤول تجريبي',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),


                                // حقوق الطبع
                                const SizedBox(height: AppConstants.spacing * 1.5),
                                Text(
                                  '© 2025 ${AppConstants.appName}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppConstants.textSecondary.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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