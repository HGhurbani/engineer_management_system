// lib/pages/admin/admin_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'; // For date picker
import 'dart:typed_data'; // For Uint8List for signature image
import 'dart:ui' as ui;

// Assuming AppConstants are defined elsewhere or copied here for self-containment
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح
  static const Color warningColor = Color(0xFFFFA000); // لون للتحذير

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedEngineerId;
  List<DocumentSnapshot> _engineers = [];
  double _defaultWorkingHours = 8.0; // Default from settings
  double _engineerHourlyRate = 50.0; // Default from settings

  @override
  void initState() {
    super.initState();
    _loadEngineers();
    _loadSettings();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Load all engineers for the search dropdown
  Future<void> _loadEngineers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();
      setState(() {
        _engineers = snapshot.docs;
      });
    } catch (e) {
      _showErrorSnackBar(context, 'فشل تحميل قائمة المهندسين: $e');
    }
  }

  // Load settings (default working hours, hourly rate)
  Future<void> _loadSettings() async {
    try {
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();

      if (settingsDoc.exists) {
        Map<String, dynamic> data = settingsDoc.data() as Map<String, dynamic>;
        setState(() {
          _defaultWorkingHours = (data['defaultWorkingHours'] ?? 8.0).toDouble();
          _engineerHourlyRate = (data['engineerHourlyRate'] ?? 50.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading settings: $e'); // For debugging
      _showErrorSnackBar(context, 'فشل تحميل إعدادات الحضور والأجور: $e');
    }
  }

  // Handle search text changes (for real-time filtering if needed, though dropdown is primary)
  void _onSearchChanged() {
    // You might want to implement real-time filtering here if the dropdown isn't exclusive.
    // For now, it will primarily work with dropdown selection.
    setState(() {}); // Rebuild to update results based on selected engineer/date
  }

  // Function to pick a date
  Future<void> _selectDate(BuildContext context) async {
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime.now().add(const Duration(days: 365)),
      onConfirm: (date) {
        setState(() {
          _selectedDate = date;
        });
      },
      currentTime: _selectedDate,
      locale: LocaleType.ar, // For Arabic locale
    );
  }

  // Calculate working hours and payment for a given day
  Map<String, dynamic> _calculateDailySummary(List<DocumentSnapshot> records) {
    DateTime? checkInTime;
    DateTime? checkOutTime;
    double totalHours = 0.0;

    // Sort records by timestamp to ensure correct check-in/out pairing
    records.sort((a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp'] as Timestamp));

    for (var record in records) {
      final type = record['type'] as String;
      final timestamp = (record['timestamp'] as Timestamp).toDate();

      if (type == 'check_in') {
        checkInTime = timestamp;
      } else if (type == 'check_out' && checkInTime != null) {
        checkOutTime = timestamp;
        totalHours += checkOutTime.difference(checkInTime).inMinutes / 60.0;
        checkInTime = null; // Reset for next pair
      }
    }

    // Handle case where engineer checked in but not out on the same day
    if (checkInTime != null && checkOutTime == null) {
      // If there's an active check-in, we can't calculate full hours for the day yet.
      // Or, you might decide to calculate hours up to current time.
      // For simplicity, we'll just indicate an ongoing session.
    }

    // Calculate overtime and total payment
    double overtimeHours = 0.0;
    double dailyPayment = 0.0;

    if (totalHours > _defaultWorkingHours) {
      overtimeHours = totalHours - _defaultWorkingHours;
      // You might have a different rate for overtime, for simplicity, using same hourly rate.
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

  // Helper to format time
  String _formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  // Helper for snackbars
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!mounted) return;
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
      textDirection: ui.TextDirection.rtl, // Correct usage of TextDirection enum
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'الحضور والإنصراف للمهندسين',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          backgroundColor: AppConstants.primaryColor,
          elevation: 4,
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.padding),
              child: Column(
                children: [
                  // Engineer Dropdown Search
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration(
                        'اسم المهندس', Icons.engineering_outlined),
                    hint: const Text('اختر مهندسًا'),
                    value: _selectedEngineerId,
                    items: _engineers.map((engineer) {
                      final name = (engineer.data() as Map<String, dynamic>)['name'] as String? ?? 'اسم غير متوفر';
                      return DropdownMenuItem<String>(
                        value: engineer.id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedEngineerId = val;
                      });
                    },
                    isExpanded: true,
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),
                  // Date Picker
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: _inputDecoration(
                          'تحديد التاريخ', Icons.calendar_today),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate),
                            style: TextStyle(
                                fontSize: 16, color: AppConstants.textColor),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _selectedEngineerId == null
                    ? null // Don't fetch if no engineer is selected
                    : FirebaseFirestore.instance
                    .collection('attendance')
                    .where('userId', isEqualTo: _selectedEngineerId)
                    .where('timestamp', isGreaterThanOrEqualTo: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day))
                    .where('timestamp', isLessThan: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1))
                    .orderBy('timestamp', descending: false) // Order by timestamp to get check-in/out sequence
                    .snapshots(),
                builder: (context, snapshot) {
                  if (_selectedEngineerId == null) {
                    return Center(
                      child: Text(
                        'الرجاء اختيار مهندس لعرض سجل الحضور.',
                        style: TextStyle(fontSize: 16, color: AppConstants.secondaryTextColor),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ: ${snapshot.error}',
                        style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                          const SizedBox(height: AppConstants.itemSpacing),
                          Text(
                            'لا توجد سجلات حضور لهذا المهندس في التاريخ المحدد.',
                            style: TextStyle(fontSize: 16, color: AppConstants.secondaryTextColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final attendanceRecords = snapshot.data!.docs;
                  final dailySummary = _calculateDailySummary(attendanceRecords);
                  final totalHours = dailySummary['totalHours'] as double;
                  final overtimeHours = dailySummary['overtimeHours'] as double;
                  final dailyPayment = dailySummary['dailyPayment'] as double;

                  return Column(
                    children: [
                      // Daily Summary Card
                      Card(
                        margin: const EdgeInsets.all(AppConstants.padding),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppConstants.padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ملخص اليوم (${DateFormat('yyyy-MM-dd').format(_selectedDate)})',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.primaryColor),
                              ),
                              const Divider(),
                              _buildSummaryRow(
                                  'إجمالي ساعات العمل:', '${totalHours.toStringAsFixed(2)} ساعة'),
                              _buildSummaryRow('ساعات العمل الإضافي:',
                                  '${overtimeHours.toStringAsFixed(2)} ساعة',
                                  valueColor: overtimeHours > 0 ? AppConstants.warningColor : null),
                              _buildSummaryRow(
                                  'المبلغ المستحق:', '${dailyPayment.toStringAsFixed(2)} ريال',
                                  valueColor: AppConstants.successColor),
                            ],
                          ),
                        ),
                      ),
                      // Attendance Records List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.padding / 2),
                          itemCount: attendanceRecords.length,
                          itemBuilder: (context, index) {
                            final record = attendanceRecords[index];
                            final data = record.data() as Map<String, dynamic>;
                            final type = data['type'] as String;
                            final timestamp = (data['timestamp'] as Timestamp).toDate();
                            final location = data['location'] as Map<String, dynamic>?;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  type == 'check_in' ? Icons.login : Icons.logout,
                                  color: type == 'check_in' ? AppConstants.successColor : AppConstants.errorColor,
                                  size: 30,
                                ),
                                title: Text(
                                  type == 'check_in' ? 'تسجيل حضور' : 'تسجيل انصراف',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الوقت: ${_formatTime(timestamp)}',
                                      style: TextStyle(color: AppConstants.secondaryTextColor),
                                    ),
                                    if (location != null)
                                      Text(
                                        'الموقع: Lat ${location['latitude'].toStringAsFixed(4)}, Lng ${location['longitude'].toStringAsFixed(4)}',
                                        style: TextStyle(color: AppConstants.secondaryTextColor.withOpacity(0.7), fontSize: 12),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.info_outline, color: AppConstants.accentColor),
                                  onPressed: () {
                                    // Optionally show more details or signature
                                    _showRecordDetails(data);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build summary rows
  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Text(
    label,
    style: TextStyle(fontSize: 16, color: AppConstants.textColor),
    ),
    Text(
    value,
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: valueColor ?? AppConstants.secondaryTextColor,
    ),
    ),
    ],),
    );
  }

  // Function to show attendance record details including signature
  void _showRecordDetails(Map<String, dynamic> recordData) {
    final signatureData = recordData['signatureData'] as List<dynamic>?;
    final timestamp = (recordData['timestamp'] as Timestamp).toDate();
    final type = recordData['type'] as String;
    final location = recordData['location'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            type == 'check_in' ? 'تفاصيل تسجيل الحضور' : 'تفاصيل تسجيل الانصراف',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow(Icons.person, 'اسم المهندس:', recordData['userName'] ?? 'غير معروف'),
                _buildInfoRow(Icons.event, 'التاريخ:', DateFormat('yyyy-MM-dd').format(timestamp)),
                _buildInfoRow(Icons.access_time, 'الوقت:', _formatTime(timestamp)),
                _buildInfoRow(Icons.location_on, 'خط العرض:', location?['latitude'].toStringAsFixed(4) ?? 'غير متوفر'),
                _buildInfoRow(Icons.location_on, 'خط الطول:', location?['longitude'].toStringAsFixed(4) ?? 'غير متوفر'),
                _buildInfoRow(Icons.my_location, 'الدقة:', '${location?['accuracy'].toStringAsFixed(2) ?? 'غير متوفر'} متر'),
                const SizedBox(height: AppConstants.itemSpacing),
                if (signatureData != null && signatureData.isNotEmpty)
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التوقيع الرقمي:',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textColor),
                        ),
                        const SizedBox(height: 8),
                        // Display signature image from bytes
                        Image.memory(
                          Uint8List.fromList(signatureData.cast<int>()),
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ]
                  )
                else
                  Text(
                    'لا يوجد توقيع رقمي.',
                    style: TextStyle(color: AppConstants.secondaryTextColor.withOpacity(0.7)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(color: AppConstants.secondaryTextColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              textDirection: ui.TextDirection.rtl, // Correct usage
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                  ),
                  TextSpan(
                    text: ' $value',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppConstants.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for input decoration (copied for consistency)
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
}