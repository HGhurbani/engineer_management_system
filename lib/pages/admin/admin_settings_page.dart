// lib/pages/admin/admin_settings_page.dart
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final TextEditingController _defaultWorkingHoursController = TextEditingController();
  final TextEditingController _engineerHourlyRateController = TextEditingController();
  final TextEditingController _workStartTimeController = TextEditingController();
  final TextEditingController _workEndTimeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true; // Start with loading true

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _defaultWorkingHoursController.dispose();
    _engineerHourlyRateController.dispose();
    _workStartTimeController.dispose();
    _workEndTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async { //
    if (!mounted) return;
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
        _workStartTimeController.text = data['workStartTime'] ?? '09:00';
        _workEndTimeController.text = data['workEndTime'] ?? '17:00';
      } else {
        _defaultWorkingHoursController.text = '8.0';
        _engineerHourlyRateController.text = '50.0';
        _workStartTimeController.text = '09:00';
        _workEndTimeController.text = '17:00';
        await FirebaseFirestore.instance.collection('settings').doc('app_settings').set({
          'defaultWorkingHours': 8.0,
          'engineerHourlyRate': 50.0,
          'workStartTime': '09:00',
          'workEndTime': '17:00',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل الإعدادات: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async { //
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      double defaultWorkingHours = double.parse(_defaultWorkingHoursController.text);
      double engineerHourlyRate = double.parse(_engineerHourlyRateController.text);
      String startTime = _workStartTimeController.text;
      String endTime = _workEndTimeController.text;

      await FirebaseFirestore.instance.collection('settings').doc('app_settings').set(
        {
          'defaultWorkingHours': defaultWorkingHours,
          'engineerHourlyRate': engineerHourlyRate,
          'workStartTime': startTime,
          'workEndTime': endTime,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        _showFeedbackSnackBar(context, 'تم حفظ الإعدادات بنجاح!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل حفظ الإعدادات: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppConstants.textSecondary),
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
        ),
        filled: true,
        fillColor: AppConstants.cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب.';
        }
        if (double.tryParse(value) == null) {
          return 'الرجاء إدخال رقم صالح.';
        }
        if (double.parse(value) <= 0) {
          return 'القيمة يجب أن تكون أكبر من صفر.';
        }
        return validator?.call(value);
      },
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppConstants.textSecondary),
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: AppConstants.cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      ),
      onTap: () async {
        final now = TimeOfDay.now();
        final picked = await showTimePicker(context: context, initialTime: now);
        if (picked != null) {
          controller.text = picked.format(context);
        }
      },
      validator: (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب.' : null,
    );
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'الإعدادات العامة',
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  shadowColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_applications_rounded, color: AppConstants.primaryColor, size: 28),
                            const SizedBox(width: AppConstants.paddingSmall),
                            const Text(
                              'إعدادات الحضور والأجور',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: AppConstants.paddingLarge, thickness: 0.5),
                        _buildStyledTextField(
                          controller: _defaultWorkingHoursController,
                          labelText: 'ساعات العمل الافتراضية (يومياً)',
                          icon: Icons.access_time_filled_rounded,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        _buildTimeField(
                          controller: _workStartTimeController,
                          labelText: 'بداية ساعات العمل',
                          icon: Icons.play_arrow_rounded,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        _buildTimeField(
                          controller: _workEndTimeController,
                          labelText: 'نهاية ساعات العمل',
                          icon: Icons.stop_rounded,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        _buildStyledTextField(
                          controller: _engineerHourlyRateController,
                          labelText: 'سعر الساعة للمهندس (بالريال السعودي)',
                          icon: Icons.price_change_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLarge),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveSettings,
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
                        : const Text(
                      'حفظ الإعدادات',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingLarge,
                          vertical: AppConstants.paddingMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                      ),
                      elevation: AppConstants.cardShadow[0].blurRadius,
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