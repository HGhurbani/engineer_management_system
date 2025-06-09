import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class AdminAttendanceReportPage extends StatefulWidget {
  const AdminAttendanceReportPage({super.key});

  @override
  State<AdminAttendanceReportPage> createState() => _AdminAttendanceReportPageState();
}

class _AdminAttendanceReportPageState extends State<AdminAttendanceReportPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _userSummaries = {};
  double _defaultWorkingHours = 8.0;
  double _hourlyRate = 50.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSettings(),
      _fetchAttendanceSummaries(),
    ]);
  }

  Future<void> _loadSettings() async {
    try {
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();
      if (settingsDoc.exists) {
        Map<String, dynamic> data = settingsDoc.data() as Map<String, dynamic>;
        _defaultWorkingHours = (data['defaultWorkingHours'] ?? 8.0).toDouble();
        _hourlyRate = (data['engineerHourlyRate'] ?? 50.0).toDouble();
      }
    } catch (e) {
      // ignore error, use defaults
    }
  }

  Future<void> _fetchAttendanceSummaries() async {
    setState(() => _isLoading = true);
    try {
      DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      DateTime end = start.add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThan: end)
          .orderBy('timestamp')
          .get();

      Map<String, List<DocumentSnapshot>> grouped = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String?;
        if (userId == null) continue;
        grouped.putIfAbsent(userId, () => []).add(doc);
      }

      Map<String, Map<String, dynamic>> summaries = {};
      for (var entry in grouped.entries) {
        final userId = entry.key;
        final records = entry.value;
        final summary = _calculateDailySummary(records);
        if (summary['checkIn'] != null && summary['checkOut'] != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          final name = userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['name'] ?? '' : '';
          summaries[userId] = {
            'name': name,
            ...summary,
          };
        }
      }

      if (mounted) {
        setState(() {
          _userSummaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userSummaries = {};
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _calculateDailySummary(List<DocumentSnapshot> records) {
    DateTime? firstCheckIn;
    DateTime? lastCheckOut;
    DateTime? currentCheckIn;
    double totalHours = 0.0;

    records.sort((a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp'] as Timestamp));
    for (var recordDoc in records) {
      final record = recordDoc.data() as Map<String, dynamic>;
      final type = record['type'] as String;
      final timestamp = (record['timestamp'] as Timestamp).toDate();

      if (type == 'check_in') {
        currentCheckIn ??= timestamp;
        firstCheckIn ??= timestamp;
      } else if (type == 'check_out') {
        lastCheckOut = timestamp;
        if (currentCheckIn != null) {
          totalHours += lastCheckOut.difference(currentCheckIn).inMinutes / 60.0;
          currentCheckIn = null;
        }
      }
    }

    double overtimeHours = 0.0;
    double dailyPayment = 0.0;

    if (totalHours > _defaultWorkingHours) {
      overtimeHours = totalHours - _defaultWorkingHours;
      dailyPayment = (_defaultWorkingHours * _hourlyRate) + (overtimeHours * _hourlyRate * 1.5);
    } else {
      dailyPayment = totalHours * _hourlyRate;
    }

    return {
      'checkIn': firstCheckIn,
      'checkOut': lastCheckOut,
      'totalHours': totalHours,
      'dailyPayment': dailyPayment,
    };
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a', 'ar').format(dateTime);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchAttendanceSummaries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير الحضور اليومي'),
          backgroundColor: AppConstants.primaryColor,
        ),
        backgroundColor: AppConstants.backgroundColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تحديد التاريخ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                          ),
                          filled: true,
                          fillColor: AppConstants.cardColor,
                        ),
                        child: Text(
                          DateFormat('EEEE, dd MMMM yyyy', 'ar').format(_selectedDate),
                          style: const TextStyle(color: AppConstants.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                  : _userSummaries.isEmpty
                      ? const Center(child: Text('لا توجد سجلات لهذا اليوم'))
                      : ListView(
                          padding: const EdgeInsets.all(AppConstants.paddingMedium),
                          children: _userSummaries.values.map((summary) {
                            final name = summary['name'] ?? '';
                            final checkIn = summary['checkIn'] as DateTime?;
                            final checkOutTs = summary['checkOut'];
                            DateTime? checkOut;
                            if (checkOutTs is Timestamp) {
                              checkOut = checkOutTs.toDate();
                            } else if (checkOutTs is DateTime) {
                              checkOut = checkOutTs;
                            }
                            final totalHours = summary['totalHours'] as double;
                            final dailyPayment = summary['dailyPayment'] as double;

                            return Card(
                              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                              child: ListTile(
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (checkIn != null) Text('حضور: ${_formatTime(checkIn)}'),
                                    if (checkOut != null) Text('انصراف: ${_formatTime(checkOut)}'),
                                    Text('إجمالي الساعات: ${totalHours.toStringAsFixed(2)}'),
                                    Text('المبلغ المستحق: ${dailyPayment.toStringAsFixed(2)} ر.ق'),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
