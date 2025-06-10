import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/saudi_holidays.dart';
import '../../models/holiday.dart';
import 'dart:ui' as ui;

class AdminHolidaySettingsPage extends StatefulWidget {
  const AdminHolidaySettingsPage({super.key});

  @override
  State<AdminHolidaySettingsPage> createState() => _AdminHolidaySettingsPageState();
}

class _AdminHolidaySettingsPageState extends State<AdminHolidaySettingsPage> {
  final Set<int> _selectedWeeklyHolidays = {};
  final List<Holiday> _specialHolidays = [];

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
        final weeklyData = data['weeklyHolidays'];
        final weeklyList = (weeklyData is List ? weeklyData : [])
            .map((e) => e is int ? e : int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
        _selectedWeeklyHolidays
          ..clear()
          ..addAll(weeklyList);
        final loaded = (data['specialHolidays'] as List<dynamic>? ?? [])
            .map((d) {
          if (d is Map<String, dynamic>) {
            return Holiday.fromMap(d);
          } else if (d is Holiday) {
            return d;
          } else if (d is String) {
            final parsed = DateTime.tryParse(d);
            return parsed != null ? Holiday(name: 'عطلة', date: parsed) : null;
          }
          return null;
        })
            .whereType<Holiday>()
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
              .map((h) => h.toMap())
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
            final isSelected = _selectedWeeklyHolidays.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
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
              backgroundColor: AppConstants.cardColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppConstants.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                side: BorderSide(
                  color: isSelected ? AppConstants.primaryColor : AppConstants.textSecondary.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              checkmarkColor: Colors.white,
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
          runSpacing: 8,
          children: _specialHolidays.map((holiday) {
            final label = '${holiday.name} - '
                '${DateFormat('yyyy-MM-dd').format(holiday.date)}';
            return InputChip(
              label: Text(label),
              onDeleted: () => _confirmDeleteHoliday(holiday),
              deleteIconColor: AppConstants.errorColor,
              backgroundColor: AppConstants.backgroundColor,
              labelStyle: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                side: BorderSide(color: AppConstants.dividerColor, width: 1.0),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        ElevatedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppConstants.primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: AppConstants.textPrimary,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(foregroundColor: AppConstants.primaryColor),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                if (!_specialHolidays.any((h) => h.date.year == picked.year && h.date.month == picked.month && h.date.day == picked.day)) {
                  _specialHolidays.add(Holiday(name: 'عطلة', date: picked));
                }
              });
            }
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة تاريخ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteHoliday(Holiday holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          title: const Text(
            'تأكيد الحذف',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppConstants.textPrimary,
            ),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف العطلة "${holiday.name}" بتاريخ ${DateFormat('yyyy-MM-dd').format(holiday.date)}؟',
            style: const TextStyle(color: AppConstants.textSecondary),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall / 2),
              ),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall / 2),
                elevation: 2,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      setState(() {
        _specialHolidays.remove(holiday);
      });
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
        duration: const Duration(seconds: 3),
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
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppConstants.primaryColor),
              const SizedBox(height: AppConstants.itemSpacing),
              Text(
                'جاري تحميل الإعدادات...',
                style: TextStyle(fontSize: 16, color: AppConstants.textSecondary.withOpacity(0.7)),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4, // Slightly increased elevation for better presence
                shadowColor: AppConstants.primaryColor.withOpacity(0.15), // Stronger shadow
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
                      const SizedBox(height: AppConstants.itemSpacing * 1.5), // Increased spacing
                      _buildSpecialHolidaysSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingXLarge), // More spacing before button
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
                        horizontal: AppConstants.paddingXLarge, // Wider padding
                        vertical: AppConstants.paddingMedium),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius), // Slightly more rounded
                    ),
                    elevation: AppConstants.elevatedShadow[0].blurRadius, // Deeper shadow
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