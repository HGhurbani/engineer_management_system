import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_constants.dart';

class ChangePasswordPage extends StatefulWidget {
  final String role;
  const ChangePasswordPage({Key? key, required this.role}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _currentPasswordController.text.trim());
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تغيير كلمة المرور بنجاح'),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadius / 2)),
            margin: const EdgeInsets.all(AppConstants.paddingMedium),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      _showError('حدث خطأ غير متوقع.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'كلمة المرور الحالية غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور الجديدة ضعيفة جداً.';
      case 'requires-recent-login':
        return 'الرجاء تسجيل الدخول مجدداً ثم المحاولة.';
      default:
        return 'فشل تغيير كلمة المرور: $code';
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    required void Function() toggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off,
              color: AppConstants.textSecondary),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide:
              const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تغيير كلمة المرور',
              style: TextStyle(color: Colors.white)),
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
          centerTitle: true,
        ),
        backgroundColor: AppConstants.backgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                    controller: _currentPasswordController,
                    label: 'كلمة المرور الحالية',
                    icon: Icons.lock_outline,
                    obscure: _obscureCurrent,
                    toggle: () => setState(() => _obscureCurrent = !_obscureCurrent)),
                const SizedBox(height: AppConstants.itemSpacing),
                _buildTextField(
                    controller: _newPasswordController,
                    label: 'كلمة المرور الجديدة',
                    icon: Icons.lock_open_rounded,
                    obscure: _obscureNew,
                    toggle: () => setState(() => _obscureNew = !_obscureNew)),
                const SizedBox(height: AppConstants.itemSpacing),
                _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'تأكيد كلمة المرور الجديدة',
                    icon: Icons.lock,
                    obscure: _obscureConfirm,
                    toggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                const SizedBox(height: AppConstants.paddingLarge),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_newPasswordController.text.trim() !=
                              _confirmPasswordController.text.trim()) {
                            _showError('كلمتا المرور غير متطابقتين');
                            return;
                          }
                          _changePassword();
                        },
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save_alt_rounded, color: Colors.white),
                  label: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('حفظ التغيير',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingLarge,
                        vertical: AppConstants.paddingMedium),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.borderRadius / 1.5),
                    ),
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
