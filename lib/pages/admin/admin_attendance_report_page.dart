import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:engineer_management_system/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import '../../utils/pdf_styles.dart';
import '../../utils/report_storage.dart';

class AdminAttendanceReportPage extends StatefulWidget {
  const AdminAttendanceReportPage({super.key});

  @override
  State<AdminAttendanceReportPage> createState() => _AdminAttendanceReportPageState();
}

class _AdminAttendanceReportPageState extends State<AdminAttendanceReportPage>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _userSummaries = {};
  double _defaultWorkingHours = 10.0;
  double _hourlyRate = 50.0;
  pw.Font? _arabicFont;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Statistics
  double _totalHours = 0.0;
  double _totalPayment = 0.0;
  int _presentCount = 0;
  double _averageHours = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _loadArabicFont();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
        _defaultWorkingHours = (data['defaultWorkingHours'] ?? 10.0).toDouble();
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
          final userData = userDoc.data() as Map<String, dynamic>? ?? {};
          final name = userData['name'] ?? '';
          final position = userData['position'] ?? 'فني';
          final profileImage = userData['profileImage'];

          summaries[userId] = {
            'name': name,
            'position': position,
            'profileImage': profileImage,
            ...summary,
          };
        }
      }

      _calculateStatistics(summaries);

      if (mounted) {
        setState(() {
          _userSummaries = summaries;
          _isLoading = false;
        });
        _startAnimations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userSummaries = {};
          _isLoading = false;
        });
        _showErrorSnackBar('حدث خطأ في تحميل البيانات');
      }
    }
  }

  void _calculateStatistics(Map<String, Map<String, dynamic>> summaries) {
    _totalHours = 0.0;
    _totalPayment = 0.0;
    _presentCount = summaries.length;

    for (var summary in summaries.values) {
      _totalHours += summary['totalHours'] as double;
      _totalPayment += summary['dailyPayment'] as double;
    }

    _averageHours = _presentCount > 0 ? _totalHours / _presentCount : 0.0;
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
      'overtimeHours': overtimeHours,
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchAttendanceSummaries();
    }
  }

  Widget _buildStatisticsCards() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildStatCard('الموظفين الحاضرين', _presentCount.toString(), Icons.people, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('إجمالي الساعات', _totalHours.toStringAsFixed(1), Icons.access_time, Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('متوسط الساعات', _averageHours.toStringAsFixed(1), Icons.trending_up, Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('إجمالي المبلغ', '${_totalPayment.toStringAsFixed(0)} ر.ق', Icons.monetization_on, Colors.purple)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التاريخ المحدد',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'ar').format(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_left, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> summary, int index) {
    final name = summary['name'] ?? '';
    final position = summary['position'] ?? 'مهندس';
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
    final overtimeHours = summary['overtimeHours'] as double? ?? 0.0;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(
            bottom: AppConstants.itemSpacing,
            top: index == 0 ? AppConstants.paddingSmall : 0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showEmployeeDetails(summary),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'avatar_$name',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppConstants.primaryColor, AppConstants.primaryColor.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: summary['profileImage'] != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                summary['profileImage'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultAvatar(name),
                              ),
                            )
                                : _buildDefaultAvatar(name),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                position,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (overtimeHours > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'إضافي',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildTimeInfo('الحضور', checkIn != null ? _formatTime(checkIn) : '--', Icons.login, Colors.green),
                              const SizedBox(width: 20),
                              _buildTimeInfo('الانصراف', checkOut != null ? _formatTime(checkOut) : '--', Icons.logout, Colors.red),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildTimeInfo('إجمالي الساعات', '${totalHours.toStringAsFixed(1)} س', Icons.access_time, Colors.blue),
                              const SizedBox(width: 20),
                              _buildTimeInfo('المبلغ المستحق', '${dailyPayment.toStringAsFixed(0)} ر.ق', Icons.monetization_on, Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '؟',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeDetails(Map<String, dynamic> summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'avatar_${summary['name']}',
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppConstants.primaryColor, AppConstants.primaryColor.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: summary['profileImage'] != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.network(
                                summary['profileImage'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultAvatar(summary['name']),
                              ),
                            )
                                : _buildDefaultAvatar(summary['name']),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                summary['position'] ?? 'مهندس',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'تفاصيل اليوم',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Add more detailed information here
                    _buildDetailRow('وقت الحضور', summary['checkIn'] != null ? _formatTime(summary['checkIn']) : '--'),
                    _buildDetailRow('وقت الانصراف', summary['checkOut'] != null ? _formatTime(summary['checkOut']) : '--'),
                    _buildDetailRow('إجمالي الساعات', '${(summary['totalHours'] as double).toStringAsFixed(2)} ساعة'),
                    _buildDetailRow('الساعات الإضافية', '${(summary['overtimeHours'] as double? ?? 0.0).toStringAsFixed(2)} ساعة'),
                    _buildDetailRow('المبلغ المستحق', '${(summary['dailyPayment'] as double).toStringAsFixed(2)} ر.ق'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadArabicFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      // ignore: avoid_print
      print('Error loading Arabic font: $e');
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppConstants.primaryColor),
              const SizedBox(width: 20),
              Text(message, style: const TextStyle(fontFamily: 'NotoSansArabic')),
            ],
          ),
        );
      },
    );
  }

  void _hideLoadingDialog(BuildContext context) {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message,
      {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Future<void> _saveOrSharePdf(
      Uint8List pdfBytes, String fileName, String subject, String text) async {
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(path)], subject: subject, text: text);
    }
  }

  void _openPdfPreview(
      Uint8List pdfBytes, String fileName, String text, String? link,
      {String? imageUrl}) {
    Navigator.of(context).pushNamed('/pdf_preview', arguments: {
      'bytes': pdfBytes,
      'fileName': fileName,
      'text': text,
      'link': link,
      'image': imageUrl,
    });
  }

  Future<void> _generateAttendancePdf() async {
    if (_arabicFont == null) {
      await _loadArabicFont();
      if (_arabicFont == null) {
        _showFeedbackSnackBar(context, 'فشل تحميل الخط العربي.', isError: true);
        return;
      }
    }

    _showLoadingDialog(context, 'جاري إنشاء التقرير...');

    pw.Font? emojiFont;
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmoji();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading NotoColorEmoji font: $e');
    }
    final List<pw.Font> commonFontFallback = emojiFont != null ? [emojiFont] : [];

    final ByteData logoData = await rootBundle.load('assets/images/app_logo.png');
    final pw.MemoryImage appLogo = pw.MemoryImage(logoData.buffer.asUint8List());

    final pdf = pw.Document();
    final fileName = 'attendance_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';
    final token = generateReportToken();
    final qrLink = buildReportDownloadUrl(fileName, token);
    final pw.TextStyle headerStyle = pw.TextStyle(
        font: _arabicFont,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        fontFallback: commonFontFallback);
    final pw.TextStyle regularStyle = pw.TextStyle(
        font: _arabicFont, fontSize: 11, fontFallback: commonFontFallback);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 1000000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: _arabicFont,
            bold: _arabicFont,
            italic: _arabicFont,
            boldItalic: _arabicFont,
            fontFallback: commonFontFallback,
          ),
          margin: PdfStyles.pageMargins,
        ),
        header: (context) => PdfStyles.buildHeader(
          font: _arabicFont!,
          logo: appLogo,
          headerText: AppConstants.attendanceReportHeader,
          now: _selectedDate,
          projectName: 'غير محدد',
          clientName: 'غير محدد',
        ),
        build: (context) {
          final headers = [
            'الموظف',
            'الوظيفة',
            'الحضور',
            'الانصراف',
            'الساعات',
            'الإضافي',
            'المبلغ'
          ];

          final dataRows = <List<String>>[];

          for (final summary in _userSummaries.values) {
            final DateTime? checkIn = summary['checkIn'] as DateTime?;
            DateTime? checkOut;
            final co = summary['checkOut'];
            if (co is Timestamp) {
              checkOut = co.toDate();
            } else if (co is DateTime) {
              checkOut = co;
            }
            final totalHours = summary['totalHours'] as double;
            final overtime = summary['overtimeHours'] as double? ?? 0.0;
            final payment = summary['dailyPayment'] as double;

            dataRows.add([
              summary['name'] ?? '',
              summary['position'] ?? '',
              checkIn != null ? DateFormat('HH:mm').format(checkIn) : '--',
              checkOut != null ? DateFormat('HH:mm').format(checkOut) : '--',
              totalHours.toStringAsFixed(1),
              overtime.toStringAsFixed(1),
              payment.toStringAsFixed(0),
            ]);
          }

          final summaryWidgets = [
            pw.SizedBox(height: 10),
            pw.Text('إجمالي الموظفين الحاضرين: $_presentCount',
                style: regularStyle),
            pw.Text('إجمالي الساعات: ${_totalHours.toStringAsFixed(1)}',
                style: regularStyle),
            pw.Text('إجمالي المبلغ: ${_totalPayment.toStringAsFixed(0)} ر.ق',
                style: regularStyle),
          ];

          return [
            PdfStyles.buildTable(
              font: _arabicFont!,
              headers: headers,
              data: dataRows,
              isRtl: true,
            ),
            ...summaryWidgets
          ];
        },
        footer: (context) => PdfStyles.buildFooter(
            context,
            font: _arabicFont!,
            fontFallback: commonFontFallback,
            qrData: qrLink,
            generatedByText: 'المسؤول: ${FirebaseAuth.instance.currentUser?.displayName ?? ''}'),
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      final link = await uploadReportPdf(pdfBytes, fileName, token);

      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, 'تم إنشاء التقرير بنجاح.', isError: false);

      _openPdfPreview(
          pdfBytes,
          fileName,
          'يرجى الاطلاع على التقرير المرفق.',
          link);
    } catch (e) {
      _hideLoadingDialog(context);
      _showFeedbackSnackBar(
          context, 'فشل إنشاء أو مشاركة التقرير: $e', isError: true);
      // ignore: avoid_print
      print('Error generating attendance PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            AppConstants.attendanceReportHeader,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
              tooltip: 'تصدير PDF',
              onPressed: _userSummaries.isEmpty ? null : _generateAttendancePdf,
            ),
          ],
          backgroundColor: AppConstants.primaryColor,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
          ),
        ),
        backgroundColor: AppConstants.backgroundColor,
        body: RefreshIndicator(
          onRefresh: _fetchAttendanceSummaries,
          color: AppConstants.primaryColor,
          child: Column(
            children: [
              _buildDateSelector(),
              if (!_isLoading && _userSummaries.isNotEmpty) _buildStatisticsCards(),
              Expanded(
                child: _isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppConstants.primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'جاري تحميل البيانات...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
                    : _userSummaries.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد سجلات حضور لهذا اليوم',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جرب تحديد تاريخ آخر',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
                  children: _userSummaries.values
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) => _buildEmployeeCard(entry.value, entry.key))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}