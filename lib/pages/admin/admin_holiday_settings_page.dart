import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/saudi_holidays.dart';
import 'dart:ui' as ui;

class AdminHolidaySettingsPage extends StatefulWidget {
  const AdminHolidaySettingsPage({super.key});

  @override
  State<AdminHolidaySettingsPage> createState() => _AdminHolidaySettingsPageState();
}

class _AdminHolidaySettingsPageState extends State<AdminHolidaySettingsPage> {
  final Set<int> _selectedWeeklyHolidays = {};
  final List<DateTime> _specialHolidays = [];

  final Map<int, String> _weekDays = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _selectedWeeklyHolidays
          ..clear()
          ..addAll(List<int>.from(data['weeklyHolidays'] ?? []));
        final loaded = (data['specialHolidays'] as List<dynamic>? ?? [])
            .map((d) => DateTime.tryParse(d as String))
            .whereType<DateTime>()
            .toList();
        _specialHolidays
          ..clear()
          ..addAll(loaded.isEmpty
              ? saudiOfficialHolidays(DateTime.now().year)
              : loaded);
      } else {
        _specialHolidays
          ..clear()
          ..addAll(saudiOfficialHolidays(DateTime.now().year));
      }
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحميل الإعدادات: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance.collection('settings').doc('app_settings').set(
        {
          'weeklyHolidays': _selectedWeeklyHolidays.toList(),
          'specialHolidays': _specialHolidays
              .map((d) => DateFormat('yyyy-MM-dd').format(d))
              .toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _showFeedbackSnackBar(context, 'تم حفظ الإعدادات بنجاح!', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل حفظ الإعدادات: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        'إعدادات العطل',
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
                              children: const [
                                Icon(Icons.event_available, color: AppConstants.primaryColor, size: 28),
                                SizedBox(width: AppConstants.paddingSmall),
                                Text(
                                  'إعدادات العطل',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: AppConstants.paddingLarge, thickness: 0.5),
                            _buildWeeklyHolidaysSection(),
                            const SizedBox(height: AppConstants.itemSpacing),
                            _buildSpecialHolidaysSection(),
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
    );
  }
}
