import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling and text
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // Deep Blue for professionalism
  static const Color accentColor = Color(0xFF42A5F5); // Lighter Blue for highlights
  static const Color textColor = Color(0xFF333333); // Darker text for readability
  static const Color errorColor = Color(0xFFE53935); // Red for errors

  static const double padding = 24.0;
  static const double borderRadius = 16.0; // Slightly larger for modern feel
  static const double spacing = 16.0;

  static const String appName = 'منصة المهندس'; // App name reflecting engineers
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
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        await FirebaseAuth.instance.signOut(); // تسجيل الخروج لتجنب حالة غير مستقرة
        return; // توقف عن تنفيذ الدالة
      }

      String role = userDoc['role'];

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
        return 'المستخدم غير موجود. يرجى التحقق من البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة المرور خاطئة. يرجى المحاولة مرة أخرى.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب. يرجى التواصل مع الدعم.';
      case 'too-many-requests':
        return 'تم حظر الوصول مؤقتًا بسبب كثرة المحاولات الفاشلة. حاول لاحقًا.';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
      case 'invalid-credential': // أضف هذه الحالة
        return 'بيانات تسجيل الدخول غير صحيحة أو غير موجودة.';
      default:
        return 'حدث خطأ في المصادقة: $errorCode';
    }
  }

  // دالة جديدة لإنشاء حساب المسؤول التجريبي
  Future<void> _createTestAdminAccount() async {
    print('Attempting to create/login test admin account...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    const String testEmail = 'z@z.com';
    const String testPassword = '12345678';
    const String testName = 'Admin Test User';
    const String testRole = 'admin';

    try {
      print('Trying to sign in with existing test admin account...');
      UserCredential? userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        print('Successfully signed in with test admin account: ${userCredential.user?.uid}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحساب التجريبي z@z.com موجود بالفعل وتم تسجيل الدخول به.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
        Navigator.pushReplacementNamed(context, '/admin');
        return; // توقف هنا
      } on FirebaseAuthException catch (e) {
        print('FirebaseAuthException during sign-in attempt: ${e.code}');
        // **التغيير هنا: أضف 'invalid-credential' و 'wrong-password' للسماح بإنشاء حساب جديد**
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          print('Account not found, wrong password, or invalid credentials. Proceeding to create new account.');
        } else {
          setState(() {
            _error = 'فشل تسجيل الدخول التجريبي: ${_getFirebaseErrorMessage(e.code)}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_error!),
              backgroundColor: AppConstants.errorColor,
            ),
          );
          print('Exiting due to unexpected sign-in error: ${e.code}');
          return;
        }
      }

      // إذا لم يتم تسجيل الدخول، قم بإنشاء الحساب
      print('Attempting to create new account for test admin...');
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      print('Successfully created user in Firebase Auth: ${userCredential.user?.uid}');

      // بعد إنشاء المستخدم، تأكد من إضافة بياناته إلى Firestore
      if (userCredential.user != null) {
        print('Attempting to write user data to Firestore...');
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
        print('Successfully wrote user data to Firestore for UID: ${userCredential.user!.uid}');
      } else {
        print('UserCredential.user is null after creation, cannot write to Firestore.');
        setState(() {
          _error = 'فشل إنشاء المستخدم في Firebase Authentication.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء حساب المسؤول التجريبي z@z.com بنجاح وتسجيل الدخول.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/admin');
      print('Navigating to /admin');

    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during create/login: ${e.code} - ${e.message}');
      setState(() {
        _error = 'فشل إنشاء/تسجيل دخول حساب المسؤول التجريبي: ${_getFirebaseErrorMessage(e.code)}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } catch (e) {
      print('Unexpected error during create/login: $e');
      setState(() {
        _error = 'حدث خطأ غير متوقع عند إنشاء/تسجيل دخول حساب المسؤول التجريبي: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('Finished _createTestAdminAccount execution. isLoading: $_isLoading');
    }
  }


  Future<void> _showRegisterDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'client';
    final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();
    bool isRegistering = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                title: const Text(
                  'إنشاء حساب جديد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                    fontSize: 20,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: registerFormKey,
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
                        const SizedBox(height: AppConstants.spacing),
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
                        const SizedBox(height: AppConstants.spacing),
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
                        const SizedBox(height: AppConstants.spacing),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: _inputDecoration('نوع المستخدم', Icons.category_outlined),
                          items: const [
                            DropdownMenuItem(value: 'client', child: Text('عميل', style: TextStyle(color: AppConstants.textColor))),
                            DropdownMenuItem(value: 'engineer', child: Text('مهندس', style: TextStyle(color: AppConstants.textColor))),
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
                              return 'الرجاء اختيار نوع المستخدم.';
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: AppConstants.textColor, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isRegistering
                        ? null
                        : () async {
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

                        Navigator.pop(context); // Close the dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إنشاء الحساب بنجاح، يمكنك تسجيل الدخول.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        Navigator.pop(context); // Close the dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('فشل التسجيل: ${_getFirebaseErrorMessage(e.code)}'),
                            backgroundColor: AppConstants.errorColor,
                          ),
                        );
                      } catch (e) {
                        Navigator.pop(context); // Close the dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('فشل التسجيل: $e'),
                            backgroundColor: AppConstants.errorColor,
                          ),
                        );
                      } finally {
                        setDialogState(() {
                          isRegistering = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: isRegistering
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'إنشاء',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppConstants.textColor),
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
      fillColor: Colors.white.withOpacity(0.95), // Slightly more opaque
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.blueGrey[50], // Lighter background
        appBar: AppBar(
          title: const Text(
            'تسجيل الدخول',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          backgroundColor: AppConstants.primaryColor,
          elevation: 4, // Subtle shadow for depth
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.padding),
            child: Form(
              key: _loginFormKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo/Icon for Engineers
                  const Icon(
                    Icons.engineering, // Icon for engineers
                    size: 120, // Larger icon
                    color: AppConstants.primaryColor,
                  ),
                  const SizedBox(height: AppConstants.spacing * 2.5), // More spacing

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('البريد الإلكتروني', Icons.person),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال البريد الإلكتروني.';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'صيغة بريد إلكتروني غير صحيحة.';
                      }
                      return null;
                    },
                    style: const TextStyle(color: AppConstants.textColor),
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecoration('كلمة المرور', Icons.lock),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال كلمة المرور.';
                      }
                      if (value.length < 6) {
                        return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
                      }
                      return null;
                    },
                    style: const TextStyle(color: AppConstants.textColor),
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  // Error Message
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spacing),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppConstants.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Login Button
                  _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                      strokeWidth: 4,
                    ),
                  )
                      : ElevatedButton(
                    onPressed: _loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18), // Taller button
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
                      elevation: 5, // Button shadow
                    ),
                    child: const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 20, // Larger text
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  // Register Button
                  TextButton(
                    onPressed: _showRegisterDialog,
                    child: const Text(
                      'ليس لديك حساب؟ إنشاء حساب جديد',
                      style: TextStyle(
                        color: AppConstants.accentColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  // --- زر إنشاء حساب المسؤول التجريبي ---
                  const SizedBox(height: AppConstants.spacing),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createTestAdminAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange, // لون مميز لزر الاختبار
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'إنشاء/دخول مسؤول تجريبي (z@z.com)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // ------------------------------------

                  // Optional: Forgot Password
                  // TextButton(
                  //   onPressed: () {
                  //     // Navigate to Forgot Password screen
                  //   },
                  //   child: const Text(
                  //     'نسيت كلمة المرور؟',
                  //     style: TextStyle(
                  //       color: AppConstants.accentColor,
                  //       fontSize: 15,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}