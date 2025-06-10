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
  final TextEditingController _holidayNameController = TextEditingController();

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
  bool _isSaving = false; // New state for save operation

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _holidayNameController.dispose();
    super.dispose();
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
          }
          return null; // Handle potential malformed data gracefully
        })
            .whereType<Holiday>()
            .toList();
        _specialHolidays
          ..clear()
          ..addAll(loaded.isEmpty
              ? saudiOfficialHolidays(DateTime.now().year)
              : loaded);
      } else {
        // If no settings exist, initialize with Saudi official holidays
        _specialHolidays
          ..clear()
          ..addAll(saudiOfficialHolidays(DateTime.now().year));
      }
    } catch (e) {
      debugPrint('Error loading settings: $e'); // For debugging
      _showFeedbackSnackBar('فشل تحميل الإعدادات. يرجى المحاولة مرة أخرى.', isError: true);
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
      _isSaving = true; // Set saving state
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
      _showFeedbackSnackBar('تم حفظ الإعدادات بنجاح!');
    } catch (e) {
      debugPrint('Error saving settings: $e'); // For debugging
      _showFeedbackSnackBar('فشل حفظ الإعدادات. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false; // Reset saving state
        });
      }
    }
  }

  Widget _buildWeeklyHolidaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أيام العطل الأسبوعية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppConstants.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Wrap(
          spacing: AppConstants.paddingSmall,
          runSpacing: AppConstants.paddingSmall,
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
              selectedColor: AppConstants.primaryColor, // Use primary color for selected
              backgroundColor: AppConstants.cardColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppConstants.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                side: BorderSide(
                  color: isSelected ? AppConstants.primaryColor : AppConstants.dividerColor,
                  width: 1.0,
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
        const Text(
          'العطل الرسمية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppConstants.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        _specialHolidays.isEmpty
            ? Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
          child: Text(
            'لا توجد عطل رسمية مضافة حاليًا. يمكنك إضافة عطل جديدة باستخدام الزر أدناه.',
            style: TextStyle(color: AppConstants.textSecondary.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        )
            : Wrap(
          spacing: AppConstants.paddingSmall,
          runSpacing: AppConstants.paddingSmall,
          children: _specialHolidays.map((holiday) {
            final label = '${holiday.name} - '
                '${DateFormat('yyyy-MM-dd').format(holiday.date)}';
            return Chip(
              label: Text(label),
              onDeleted: () => _confirmDeleteHoliday(holiday),
              deleteIcon: const Icon(Icons.cancel, size: 18, color: AppConstants.errorColor),
              backgroundColor: AppConstants.backgroundColor,
              labelStyle: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                side: BorderSide(color: AppConstants.dividerColor, width: 1.0),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Compact chip size
            );
          }).toList(),
        ),
        const SizedBox(height: AppConstants.paddingMedium),
        Center(
          child: ElevatedButton.icon(
            onPressed: _showAddHolidayDialog,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text('إضافة عطلة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
              elevation: 3, // Slightly increased elevation
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddHolidayDialog() async {
    DateTime? selectedDate;
    _holidayNameController.clear(); // Clear previous input

    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          title: const Text(
            'إضافة عطلة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _holidayNameController,
                  decoration: InputDecoration(
                    labelText: 'اسم العطلة (اختياري)',
                    hintText: 'مثل: اليوم الوطني',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                      borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                ListTile(
                  title: Text(
                    selectedDate == null
                        ? 'اختر تاريخ العطلة'
                        : 'التاريخ المختار: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
                    style: const TextStyle(color: AppConstants.textPrimary),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: AppConstants.primaryColor),
                  onTap: () async {
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
                        selectedDate = picked;
                        // To update the dialog's date display immediately
                        (context as Element).markNeedsBuild();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: AppConstants.textSecondary),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDate != null) {
                  setState(() {
                    final newHolidayName = _holidayNameController.text.trim().isNotEmpty
                        ? _holidayNameController.text.trim()
                        : 'عطلة'; // Default name if empty
                    if (!_specialHolidays.any((h) =>
                    h.date.year == selectedDate!.year &&
                        h.date.month == selectedDate!.month &&
                        h.date.day == selectedDate!.day)) {
                      _specialHolidays.add(Holiday(name: newHolidayName, date: selectedDate!));
                      _specialHolidays.sort((a, b) => a.date.compareTo(b.date)); // Keep sorted
                    } else {
                      _showFeedbackSnackBar('هذا التاريخ مضاف بالفعل كعطلة.', isError: true);
                    }
                  });
                  Navigator.of(context).pop();
                } else {
                  _showFeedbackSnackBar('يرجى اختيار تاريخ للعطلة.', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
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
      _showFeedbackSnackBar('تم حذف العطلة بنجاح.');
    }
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
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
        // Optional: Add action to dismiss manually
        action: SnackBarAction(
          label: 'إغلاق',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          textColor: Colors.white.withOpacity(0.8),
        ),
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
                elevation: 6, // Increased elevation for better presence
                shadowColor: AppConstants.primaryColor.withOpacity(0.2), // Stronger shadow
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
                          Icon(Icons.settings_outlined, color: AppConstants.primaryColor, size: 28), // Changed icon
                          SizedBox(width: AppConstants.paddingSmall),
                          Text(
                            'تعديل إعدادات العطل', // More descriptive title
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
                      const SizedBox(height: AppConstants.itemSpacing * 2), // Increased spacing
                      _buildSpecialHolidaysSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingXLarge),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings, // Use _isSaving
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save_alt_rounded, color: Colors.white),
                  label: _isSaving
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
                        horizontal: AppConstants.paddingXLarge,
                        vertical: AppConstants.paddingMedium),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    elevation: 8, // Deeper shadow for save button
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