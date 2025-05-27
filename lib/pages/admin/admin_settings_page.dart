// lib/pages/admin/admin_settings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling (use AppConstants from your existing files)
// For this example, I'll copy them to ensure self-containment, but ideally, you
// would import them from a shared constants file if you had one.
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final TextEditingController _defaultWorkingHoursController = TextEditingController();
  final TextEditingController _engineerHourlyRateController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _defaultWorkingHoursController.dispose();
    _engineerHourlyRateController.dispose();
    super.dispose();
  }

  // دالة لجلب الإعدادات الحالية من Firestore
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();

      if (settingsDoc.exists) {
        Map<String, dynamic> data = settingsDoc.data() as Map<String, dynamic>;
        _defaultWorkingHoursController.text = (data['defaultWorkingHours'] ?? 8.0).toString();
        _engineerHourlyRateController.text = (data['engineerHourlyRate'] ?? 50.0).toString();
      } else {
        // تعيين قيم افتراضية إذا لم يكن المستند موجودًا
        _defaultWorkingHoursController.text = '8.0';
        _engineerHourlyRateController.text = '50.0';
        // يمكنك هنا حفظ القيم الافتراضية في Firestore إذا أردت
        await FirebaseFirestore.instance.collection('settings').doc('app_settings').set({
          'defaultWorkingHours': 8.0,
          'engineerHourlyRate': 50.0,
        });
      }
    } catch (e) {
      _showErrorSnackBar(context, 'فشل تحميل الإعدادات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لحفظ الإعدادات في Firestore
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      double defaultWorkingHours = double.parse(_defaultWorkingHoursController.text);
      double engineerHourlyRate = double.parse(_engineerHourlyRateController.text);

      await FirebaseFirestore.instance.collection('settings').doc('app_settings').set(
        {
          'defaultWorkingHours': defaultWorkingHours,
          'engineerHourlyRate': engineerHourlyRate,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // استخدم merge للحفاظ على الحقول الأخرى إذا وجدت
      );

      _showSuccessSnackBar(context, 'تم حفظ الإعدادات بنجاح!');
    } catch (e) {
      _showErrorSnackBar(context, 'فشل حفظ الإعدادات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  // دالة مساعدة لعرض SnackBar للنجاح
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'الإعدادات العامة',
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : Padding(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات الحضور والأجور',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textColor,
                  ),
                ),
                const SizedBox(height: AppConstants.itemSpacing * 1.5),
                TextFormField(
                  controller: _defaultWorkingHoursController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                      'ساعات العمل الافتراضية (بالساعة)', Icons.access_time),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال ساعات العمل الافتراضية.';
                    }
                    if (double.tryParse(value) == null) {
                      return 'الرجاء إدخال رقم صالح.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                TextFormField(
                  controller: _engineerHourlyRateController,
                  keyboardType: TextInputType.number,
                  decoration:
                  _inputDecoration('سعر الساعة للمهندس (بالريال)', Icons.attach_money),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال سعر الساعة.';
                    }
                    if (double.tryParse(value) == null) {
                      return 'الرجاء إدخال رقم صالح.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.itemSpacing * 2),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'حفظ الإعدادات',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.padding * 1.5,
                          vertical: AppConstants.itemSpacing),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
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