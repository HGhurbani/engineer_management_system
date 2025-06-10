// lib/pages/admin/admin_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker; // For date picker
import 'dart:typed_data'; // For Uint8List for signature image
import 'dart:ui' as ui;

import 'map_view_page.dart';



class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  DateTime _selectedDate = DateTime.now();
  String _selectedRole = 'engineer';
  String? _selectedUserId;
  List<DocumentSnapshot> _engineers = [];
  List<DocumentSnapshot> _employees = [];
  double _defaultWorkingHours = 10.0;
  double _engineerHourlyRate = 50.0;
  bool _isLoadingFilters = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingFilters = true);
    await Future.wait([
      _loadEngineers(),
      _loadEmployees(),
      _loadSettings(),
    ]);
    if (mounted) {
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _loadEngineers() async { //
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _engineers = snapshot.docs;
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة المهندسين: $e', isError: true);
      }
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _employees = snapshot.docs;
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة الموظفين: $e', isError: true);
      }
    }
  }

  Future<void> _loadSettings() async { //
    try {
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();

      if (settingsDoc.exists) {
        Map<String, dynamic> data = settingsDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
              _defaultWorkingHours = (data['defaultWorkingHours'] ?? 10.0).toDouble();
            _engineerHourlyRate = (data['engineerHourlyRate'] ?? 50.0).toDouble();
          });
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل إعدادات الحضور والأجور.', isError: true);
      }
    }
  }

  // ... (الكود السابق في admin_attendance_page.dart)

  Future<void> _selectDate(BuildContext context) async { //
    picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime.now().add(const Duration(days: 365)),
      onConfirm: (date) {
        if (mounted) {
          setState(() {
            _selectedDate = date;
          });
        }
      },
      currentTime: _selectedDate,
      locale: picker.LocaleType.ar,
      theme: picker.DatePickerTheme(
        headerColor: AppConstants.primaryColor, // <- تم تصحيح اسم المعامل هنا
        backgroundColor: AppConstants.cardColor,
        itemStyle: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        doneStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), // لون زر "تم" ليكون ظاهر على خلفية الرأس
        cancelStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16), // لون زر "إلغاء"
        itemHeight: 60.0,
        containerHeight: 220.0,
      ),
    );
  }

// ... (بقية الكود في admin_attendance_page.dart)

  Map<String, dynamic> _calculateDailySummary(List<DocumentSnapshot> records) { //
    DateTime? checkInTime;
    DateTime? checkOutTime;
    double totalHours = 0.0;

    records.sort((a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp'] as Timestamp));

    for (var recordDoc in records) {
      final record = recordDoc.data() as Map<String, dynamic>;
      final type = record['type'] as String;
      final timestamp = (record['timestamp'] as Timestamp).toDate();

      if (type == 'check_in') {
        if (checkInTime == null) { // Take the first check-in if multiple
          checkInTime = timestamp;
        }
      } else if (type == 'check_out') {
        checkOutTime = timestamp; // Always take the latest check-out
        if (checkInTime != null) {
          totalHours += checkOutTime.difference(checkInTime).inMinutes / 60.0;
          checkInTime = null; // Reset for next pair, or if multiple check-outs, last one is used with first check-in.
        }
      }
    }
    // If there's a check-in without a subsequent check-out for the *last* pair
    if (checkInTime != null && checkOutTime != null && checkInTime.isAfter(checkOutTime)) {
      // This implies an open session, hours calculation up to now might be complex
      // For simplicity, this example assumes check-outs close sessions.
      // Or, if the last record is a check-in, it's an open session.
    }


    double overtimeHours = 0.0;
    double dailyPayment = 0.0;

    if (totalHours > _defaultWorkingHours) {
      overtimeHours = totalHours - _defaultWorkingHours;
      dailyPayment = (_defaultWorkingHours * _engineerHourlyRate) + (overtimeHours * _engineerHourlyRate * 1.5); // 1.5x for overtime
    } else {
      dailyPayment = totalHours * _engineerHourlyRate;
    }

    return {
      'totalHours': totalHours,
      'overtimeHours': overtimeHours,
      'dailyPayment': dailyPayment,
    };
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a', 'ar').format(dateTime); // Arabic AM/PM
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildFiltersSection(),
            Expanded(
              child: _isLoadingFilters
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : _buildAttendanceStream(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'متابعة الحضور والانصراف',
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

  Widget _buildFiltersSection() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Card(
        elevation: AppConstants.cardShadow[0].blurRadius,
        shadowColor: AppConstants.primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            children: [
              _buildStyledDropdown(
                hint: 'اختر النوع',
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'engineer', child: Text('مهندس')),
                  DropdownMenuItem(value: 'employee', child: Text('موظف')),
                ],
                onChanged: (value) {
                  if (mounted && value != null) {
                    setState(() {
                      _selectedRole = value;
                      _selectedUserId = null;
                    });
                  }
                },
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              _buildStyledDropdown(
                hint: _selectedRole == 'engineer' ? 'اختر المهندس' : 'اختر الموظف',
                value: _selectedUserId,
                items: (_selectedRole == 'engineer' ? _engineers : _employees).map((doc) {
                  final user = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(user['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  if (mounted) setState(() => _selectedUserId = value);
                },
                icon: _selectedRole == 'engineer' ? Icons.engineering_rounded : Icons.badge_rounded,
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              _buildStyledDatePicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: hint,
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
        fillColor: AppConstants.cardColor.withOpacity(0.5),
      ),
      isExpanded: true,
    );
  }

  Widget _buildStyledDatePicker() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تحديد التاريخ',
          labelStyle: const TextStyle(color: AppConstants.textSecondary),
          prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppConstants.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
            borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
            borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: AppConstants.cardColor.withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('EEEE, dd MMMM yyyy', 'ar').format(_selectedDate), // Format with day name
              style: const TextStyle(fontSize: 16, color: AppConstants.textPrimary, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppConstants.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStream() {
    if (_selectedUserId == null) {
      return _buildEmptyState('الرجاء اختيار المستخدم لعرض سجل الحضور.');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _selectedUserId)
          .where('timestamp', isGreaterThanOrEqualTo: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day))
          .where('timestamp', isLessThan: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1))
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ أثناء تحميل السجلات: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد سجلات حضور لهذا المستخدم في التاريخ المحدد.');
        }

        final attendanceRecords = snapshot.data!.docs;
        final dailySummary = _calculateDailySummary(attendanceRecords);

        return Column(
          children: [
            _buildDailySummaryCard(dailySummary),
            Expanded(child: _buildAttendanceRecordsList(attendanceRecords)),
          ],
        );
      },
    );
  }

  Widget _buildDailySummaryCard(Map<String, dynamic> summary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص اليوم (${DateFormat('dd MMMM', 'ar').format(_selectedDate)})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
            ),
            const Divider(height: AppConstants.itemSpacing),
            _buildSummaryRow('إجمالي ساعات العمل:', '${(summary['totalHours'] as double).toStringAsFixed(2)} ساعة'),
            _buildSummaryRow(
              'ساعات العمل الإضافي:',
              '${(summary['overtimeHours'] as double).toStringAsFixed(2)} ساعة',
              valueColor: (summary['overtimeHours'] as double) > 0 ? AppConstants.warningColor : AppConstants.textPrimary,
            ),
            _buildSummaryRow(
              'المبلغ المستحق:',
              '${(summary['dailyPayment'] as double).toStringAsFixed(2)} ر.ق', // Assuming QAR
              valueColor: AppConstants.successColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor ?? AppConstants.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildAttendanceRecordsList(List<DocumentSnapshot> records) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final recordDoc = records[index];
        final data = recordDoc.data() as Map<String, dynamic>;
        final type = data['type'] as String;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final isCheckIn = type == 'check_in';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.5, horizontal: AppConstants.paddingMedium),
          elevation: 1.5,
          shadowColor: AppConstants.primaryColor.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
          child: ListTile(
            leading: Icon(
              isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
              color: isCheckIn ? AppConstants.successColor : AppConstants.errorColor,
              size: 28,
            ),
            title: Text(
              isCheckIn ? 'تسجيل حضور' : 'تسجيل انصراف',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary, fontSize: 16),
            ),
            subtitle: Text(
              'الوقت: ${_formatTime(timestamp)}',
              style: const TextStyle(color: AppConstants.textSecondary, fontSize: 14),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: AppConstants.primaryLight),
              tooltip: 'عرض التفاصيل والتوقيع',
              onPressed: () => _showRecordDetailsDialog(data),
            ),
          ),
        );
      },
    );
  }

  void _showRecordDetailsDialog(Map<String, dynamic> recordData) { //
    final signatureBytes = recordData['signatureData'] as List<dynamic>?;
    final Uint8List? signatureImage = signatureBytes != null ? Uint8List.fromList(signatureBytes.cast<int>()) : null;
    final timestamp = (recordData['timestamp'] as Timestamp).toDate();
    final type = recordData['type'] as String;
    final location = recordData['location'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          title: Text(
            type == 'check_in' ? 'تفاصيل تسجيل الحضور' : 'تفاصيل تسجيل الانصراف',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor, fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(Icons.person_pin_circle_rounded, 'اسم المهندس:', recordData['userName'] ?? 'غير معروف'),
                _buildDetailRow(Icons.event_note_rounded, 'التاريخ:', DateFormat('EEEE, dd MMMM yyyy', 'ar').format(timestamp)),
                _buildDetailRow(Icons.access_time_filled_rounded, 'الوقت:', _formatTime(timestamp)),
                if (location != null) ...[
                  const Divider(height: AppConstants.itemSpacing),
                  _buildDetailRow(Icons.location_on_rounded, 'خط العرض:', location['latitude']?.toStringAsFixed(4) ?? 'غير متوفر'),
                  _buildDetailRow(Icons.location_on_rounded, 'خط الطول:', location['longitude']?.toStringAsFixed(4) ?? 'غير متوفر'),
                  _buildDetailRow(Icons.my_location_rounded, 'دقة الموقع:', '${location['accuracy']?.toStringAsFixed(1) ?? 'غير متوفرة'} متر'),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.map_rounded, color: AppConstants.primaryColor),
                  label: const Text('عرض على الخريطة', style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (location != null &&
                        location['latitude'] != null &&
                        location['longitude'] != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MapViewPage(
                            latitude: location['latitude'],
                            longitude: location['longitude'],
                          ),
                        ),
                      );
                    }
                  },
                ),
                if (signatureImage != null) ...[
                  const Divider(height: AppConstants.itemSpacing),
                  Text('التوقيع الرقمي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2 -1), // to prevent border overflow
                        child: Image.memory(signatureImage, height: 150, fit: BoxFit.contain,)),
                  ),
                ] else ...[
                  const Divider(height: AppConstants.itemSpacing),
                  const Text('لا يوجد توقيع رقمي متاح لهذا السجل.', style: TextStyle(color: AppConstants.textSecondary)),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: AppConstants.textSecondary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppConstants.primaryLight, size: 22),
          const SizedBox(width: AppConstants.paddingSmall),
          Text(label, style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: AppConstants.paddingSmall / 2),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15, color: AppConstants.textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.start),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 80, color: AppConstants.textSecondary.withOpacity(0.4)),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(
              message,
              style: const TextStyle(fontSize: 17, color: AppConstants.textSecondary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 80, color: AppConstants.errorColor),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.errorColor, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}