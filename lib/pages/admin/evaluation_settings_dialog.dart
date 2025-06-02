// lib/pages/admin/evaluation_settings_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/evaluation_models.dart'; // استيراد النماذج

class EvaluationSettingsDialog extends StatefulWidget {
  final EvaluationSettings currentSettings;

  const EvaluationSettingsDialog({super.key, required this.currentSettings});

  @override
  State<EvaluationSettingsDialog> createState() => _EvaluationSettingsDialogState();
}

class _EvaluationSettingsDialogState extends State<EvaluationSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _workingHoursWeightController;
  late TextEditingController _tasksCompletedWeightController;
  late TextEditingController _activityRateWeightController;
  late TextEditingController _productivityWeightController;
  late bool _enableMonthlyEvaluation;
  late bool _enableYearlyEvaluation;
  late bool _sendNotifications;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _workingHoursWeightController = TextEditingController(text: widget.currentSettings.workingHoursWeight.toStringAsFixed(0));
    _tasksCompletedWeightController = TextEditingController(text: widget.currentSettings.tasksCompletedWeight.toStringAsFixed(0));
    _activityRateWeightController = TextEditingController(text: widget.currentSettings.activityRateWeight.toStringAsFixed(0));
    _productivityWeightController = TextEditingController(text: widget.currentSettings.productivityWeight.toStringAsFixed(0));
    _enableMonthlyEvaluation = widget.currentSettings.enableMonthlyEvaluation;
    _enableYearlyEvaluation = widget.currentSettings.enableYearlyEvaluation;
    _sendNotifications = widget.currentSettings.sendNotifications;
  }

  @override
  void dispose() {
    _workingHoursWeightController.dispose();
    _tasksCompletedWeightController.dispose();
    _activityRateWeightController.dispose();
    _productivityWeightController.dispose();
    super.dispose();
  }

  void _showFeedbackSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // التحقق من أن مجموع الأوزان = 100
    double totalWeight = double.parse(_workingHoursWeightController.text) +
        double.parse(_tasksCompletedWeightController.text) +
        double.parse(_activityRateWeightController.text) +
        double.parse(_productivityWeightController.text);

    if (totalWeight != 100) {
      _showFeedbackSnackBar('يجب أن يكون مجموع الأوزان 100%. المجموع الحالي: ${totalWeight.toStringAsFixed(0)}%', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final newSettings = EvaluationSettings(
        workingHoursWeight: double.parse(_workingHoursWeightController.text),
        tasksCompletedWeight: double.parse(_tasksCompletedWeightController.text),
        activityRateWeight: double.parse(_activityRateWeightController.text),
        productivityWeight: double.parse(_productivityWeightController.text),
        enableMonthlyEvaluation: _enableMonthlyEvaluation,
        enableYearlyEvaluation: _enableYearlyEvaluation,
        sendNotifications: _sendNotifications,
      );

      await FirebaseFirestore.instance.collection('evaluation_settings').doc('weights').set(
        newSettings.toFirestore(),
        SetOptions(merge: true),
      );

      if (mounted) {
        Navigator.pop(context, true); // إغلاق وإرسال إشارة نجاح
        _showFeedbackSnackBar('تم حفظ إعدادات التقييم بنجاح.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar('فشل حفظ الإعدادات: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildWeightTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label (%)',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'مطلوب';
        }
        final num? parsed = num.tryParse(value);
        if (parsed == null || parsed < 0 || parsed > 100) {
          return 'أدخل قيمة بين 0 و 100';
        }
        return null;
      },
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      title: const Text('إعدادات التقييم', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تحديد أوزان المعايير (يجب أن يكون المجموع 100%):', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
              const SizedBox(height: AppConstants.itemSpacing),
              _buildWeightTextField(_workingHoursWeightController, 'ساعات العمل'),
              const SizedBox(height: AppConstants.itemSpacing / 2),
              _buildWeightTextField(_tasksCompletedWeightController, 'المهام المكتملة'),
              const SizedBox(height: AppConstants.itemSpacing / 2),
              _buildWeightTextField(_activityRateWeightController, 'معدل النشاط'),
              const SizedBox(height: AppConstants.itemSpacing / 2),
              _buildWeightTextField(_productivityWeightController, 'الإنتاجية العامة'),
              const SizedBox(height: AppConstants.itemSpacing),
              SwitchListTile(
                title: const Text('تفعيل التقييم الشهري التلقائي', style: TextStyle(color: AppConstants.textPrimary)),
                value: _enableMonthlyEvaluation,
                onChanged: (bool value) {
                  setState(() {
                    _enableMonthlyEvaluation = value;
                  });
                },
                activeColor: AppConstants.primaryColor,
              ),
              SwitchListTile(
                title: const Text('تفعيل التقييم السنوي التلقائي', style: TextStyle(color: AppConstants.textPrimary)),
                value: _enableYearlyEvaluation,
                onChanged: (bool value) {
                  setState(() {
                    _enableYearlyEvaluation = value;
                  });
                },
                activeColor: AppConstants.primaryColor,
              ),
              SwitchListTile(
                title: const Text('إرسال إشعارات بالتقييم', style: TextStyle(color: AppConstants.textPrimary)),
                value: _sendNotifications,
                onChanged: (bool value) {
                  setState(() {
                    _sendNotifications = value;
                  });
                },
                activeColor: AppConstants.primaryColor,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveSettings,
          icon: _isSaving
              ? const SizedBox.shrink()
              : const Icon(Icons.save_alt_rounded, color: Colors.white),
          label: _isSaving
              ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          )
              : const Text('حفظ', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
          ),
        ),
      ],
    );
  }
}