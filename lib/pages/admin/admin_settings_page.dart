// lib/pages/admin/admin_settings_page.dart
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui; // For TextDirection


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

  final Set<int> _selectedWeeklyHolidays = {};
  final List<DateTime> _specialHolidays = [];

  // Controllers for adding new admin
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();

  final Map<int, String> _weekDays = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };

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
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
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
        _defaultWorkingHoursController.text = (data['defaultWorkingHours'] ?? 10.0).toString();
        _engineerHourlyRateController.text = (data['engineerHourlyRate'] ?? 50.0).toString();
        _workStartTimeController.text = data['workStartTime'] ?? '06:30';
        _workEndTimeController.text = data['workEndTime'] ?? '16:30';
        _selectedWeeklyHolidays
          ..clear()
          ..addAll(List<int>.from(data['weeklyHolidays'] ?? []));
        _specialHolidays
          ..clear()
          ..addAll((data['specialHolidays'] as List<dynamic>? ?? [])
              .map((d) => DateTime.tryParse(d as String) ?? DateTime.now()));
      } else {
        _defaultWorkingHoursController.text = '10.0';
        _engineerHourlyRateController.text = '50.0';
        _workStartTimeController.text = '06:30';
        _workEndTimeController.text = '16:30';
        await FirebaseFirestore.instance.collection('settings').doc('app_settings').set({
          'defaultWorkingHours': 10.0,
          'engineerHourlyRate': 50.0,
          'workStartTime': '06:30',
          'workEndTime': '16:30',
          'weeklyHolidays': [],
          'specialHolidays': [],
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
          'weeklyHolidays': _selectedWeeklyHolidays.toList(),
          'specialHolidays': _specialHolidays
              .map((d) => DateFormat('yyyy-MM-dd').format(d))
              .toList(),
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

  Widget _buildWeeklyHolidaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('أيام العطل الأسبوعية',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
        const SizedBox(height: AppConstants.paddingSmall),
        Wrap(
          spacing: 8,
          children: _weekDays.entries.map((entry) {
            return FilterChip(
              label: Text(entry.value),
              selected: _selectedWeeklyHolidays.contains(entry.key),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWeeklyHolidays.add(entry.key);
                  } else {
                    _selectedWeeklyHolidays.remove(entry.key);
                  }
                });
              },
              selectedColor: AppConstants.primaryLight,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpecialHolidaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('العطل الرسمية',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
        const SizedBox(height: AppConstants.paddingSmall),
        Wrap(
          spacing: 8,
          children: _specialHolidays.map((date) {
            final label = DateFormat('yyyy-MM-dd').format(date);
            return InputChip(
              label: Text(label),
              onDeleted: () {
                setState(() {
                  _specialHolidays.remove(date);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        ElevatedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() {
                if (!_specialHolidays.any((d) => d.year == picked.year && d.month == picked.month && d.day == picked.day)) {
                  _specialHolidays.add(picked);
                }
              });
            }
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة تاريخ', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
        ),
      ],
    );
  }

  Future<void> _showAddAdminDialog() async {
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: const Text(
                'إضافة مسؤول جديد',
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
                        controller: _adminNameController,
                        labelText: 'الاسم الكامل',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: _adminEmailController,
                        labelText: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null &&
                              !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'صيغة بريد إلكتروني غير صحيحة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: _adminPasswordController,
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
                  child: const Text('إلغاء',
                      style: TextStyle(color: AppConstants.textSecondary)),
                ),
                const SizedBox(width: AppConstants.itemSpacing / 2),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() => isLoading = true);
                          try {
                            final userCred = await FirebaseAuth.instance
                                .createUserWithEmailAndPassword(
                              email: _adminEmailController.text.trim(),
                              password: _adminPasswordController.text.trim(),
                            );

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userCred.user!.uid)
                                .set({
                              'uid': userCred.user!.uid,
                              'email': _adminEmailController.text.trim(),
                              'name': _adminNameController.text.trim(),
                              'role': 'admin',
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            Navigator.pop(dialogContext);
                            _showFeedbackSnackBar(
                                context, 'تم إضافة المسؤول بنجاح.',
                                isError: false);
                          } on FirebaseAuthException catch (e) {
                            _showFeedbackSnackBar(
                                context, _getFirebaseErrorMessage(e.code),
                                isError: true);
                            Navigator.pop(dialogContext);
                          } catch (e) {
                            _showFeedbackSnackBar(
                                context, 'فشل الإضافة: $e',
                                isError: true);
                            Navigator.pop(dialogContext);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('إضافة المسؤول',
                          style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.infoColor,
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
      textDirection: ui.TextDirection.rtl,
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
                const SizedBox(height: AppConstants.paddingLarge),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _showAddAdminDialog,
                    icon: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white),
                    label: const Text(
                      'إضافة آدمن',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.infoColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingLarge,
                          vertical: AppConstants.paddingMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius / 1.5),
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