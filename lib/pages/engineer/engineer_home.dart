// lib/pages/engineer/engineer_home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:ui' as ui; // For TextDirection

// Constants for consistent styling, aligned with the admin dashboard's style.
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
        color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
}

class EngineerHome extends StatefulWidget {
  const EngineerHome({super.key});

  @override
  State<EngineerHome> createState() => _EngineerHomeState();
}

class _EngineerHomeState extends State<EngineerHome> with TickerProviderStateMixin {
  final String? _currentEngineerUid = FirebaseAuth.instance.currentUser?.uid; //
  String? _engineerName;
  bool _isCheckedIn = false; //
  DateTime? _lastCheckTime; //
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    if (_currentEngineerUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logout();
      });
    } else {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchEngineerData(); //
    await _checkCurrentAttendanceStatus(); //
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  Future<void> _fetchEngineerData() async { //
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentEngineerUid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _engineerName = userDoc.data()?['name'] as String?;
        });
      }
    } catch (e) {
      print('Error fetching engineer name: $e');
    }
  }

  Future<void> _checkCurrentAttendanceStatus() async { //
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _currentEngineerUid)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        final lastRecord = attendanceQuery.docs.first.data();
        if (mounted) {
          setState(() {
            _isCheckedIn = lastRecord['type'] == 'check_in';
            _lastCheckTime = (lastRecord['timestamp'] as Timestamp).toDate();
          });
        }
      } else if (mounted) {
        setState(() { // Ensure _isCheckedIn is false if no records today
          _isCheckedIn = false;
          _lastCheckTime = null;
        });
      }
    } catch (e) {
      print('Error checking attendance status: $e');
    }
  }

  Future<bool> _checkLocationPermissions() async { //
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showFeedbackSnackBar(context, 'يجب تفعيل خدمات الموقع (GPS) لتسجيل الحضور والانصراف.', isError: true);
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showFeedbackSnackBar(context, 'يجب السماح بالوصول للموقع لتسجيل الحضور والانصراف.', isError: true);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showFeedbackSnackBar(context, 'تم رفض إذن الموقع بشكل دائم. يرجى تمكينه من إعدادات التطبيق.', isError: true);
      return false;
    }
    return true;
  }

  // lib/pages/engineer/engineer_home.dart
// ... (داخل كلاس _EngineerHomeState)

  Future<bool?> _showLogoutConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // المستخدم يجب أن يختار أحد الخيارين
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: const Text(
              'تأكيد تسجيل الخروج',
              style: TextStyle(
                  color: AppConstants.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
              style: TextStyle(color: AppConstants.textSecondary, fontSize: 16),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: AppConstants.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false); // إرجاع false عند الإلغاء
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true); // إرجاع true عند التأكيد
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Position?> _getCurrentLocation() async { //
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل في الحصول على الموقع الحالي. حاول مرة أخرى.', isError: true);
      return null;
    }
  }

  Future<void> _showSignatureDialog(String type) async { //
    final SignatureController controller = SignatureController(penStrokeWidth: 3, penColor: AppConstants.primaryColor, exportBackgroundColor: AppConstants.cardColor.withOpacity(0.8));
    bool isProcessing = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                title: Text(type == 'check_in' ? 'توقيع تسجيل الحضور' : 'توقيع تسجيل الانصراف', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('الرجاء وضع التوقيع في المساحة أدناه:', style: TextStyle(color: AppConstants.textSecondary, fontSize: 15)),
                      const SizedBox(height: AppConstants.itemSpacing),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(border: Border.all(color: AppConstants.primaryLight, width: 1.5), borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2), color: AppConstants.backgroundColor),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2 -1),
                          child: Signature(controller: controller, backgroundColor: AppConstants.backgroundColor),
                        ),
                      ),
                    ],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actions: <Widget>[
                  TextButton.icon(icon: const Icon(Icons.clear_all_rounded), label: const Text('مسح'), onPressed: () => controller.clear(), style: TextButton.styleFrom(foregroundColor: AppConstants.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppConstants.textSecondary),
                    child: const Text('إلغاء'), // <-- هنا التعديل: استخدام child
                  ),                  ElevatedButton.icon(
                    icon: isProcessing ? const SizedBox.shrink() : Icon(type == 'check_in' ? Icons.login_rounded : Icons.logout_rounded, color: Colors.white),
                    label: isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text(type == 'check_in' ? 'تأكيد الحضور' : 'تأكيد الانصراف', style: const TextStyle(color: Colors.white)),
                    onPressed: isProcessing ? null : () async {
                      if (controller.isNotEmpty) {
                        setDialogState(() => isProcessing = true);
                        Navigator.of(dialogContext).pop(); // Close dialog before processing
                        await _processAttendance(type, controller); //
                      } else {
                        _showFeedbackSnackBar(context, 'الرجاء وضع التوقيع قبل المتابعة.', isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: type == 'check_in' ? AppConstants.successColor : AppConstants.warningColor, padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processAttendance(String type, SignatureController signatureController) async { //
    try {
      final hasLocationPermission = await _checkLocationPermissions();
      if (!hasLocationPermission || !mounted) return;

      final position = await _getCurrentLocation();
      if (position == null || !mounted) return;

      final signatureData = await signatureController.toPngBytes();
      if (signatureData == null || !mounted) {
        _showFeedbackSnackBar(context, 'فشل في الحصول على بيانات التوقيع.', isError: true);
        return;
      }

      final attendanceData = {
        'userId': _currentEngineerUid,
        'userName': _engineerName ?? 'غير معروف',
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'location': {'latitude': position.latitude, 'longitude': position.longitude, 'accuracy': position.accuracy},
        'signatureData': signatureData, //
        'deviceInfo': {'platform': 'mobile', 'timestamp': DateTime.now().millisecondsSinceEpoch}
      };

      await FirebaseFirestore.instance.collection('attendance').add(attendanceData);

      if (mounted) {
        setState(() {
          _isCheckedIn = type == 'check_in';
          _lastCheckTime = DateTime.now(); // Approximation, actual time from server
        });
        final message = type == 'check_in' ? 'تم تسجيل الحضور بنجاح.' : 'تم تسجيل الانصراف بنجاح.';
        _showFeedbackSnackBar(context, message, isError: false);
      }
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل تسجيل ${type == 'check_in' ? 'الحضور' : 'الانصراف'}: $e', isError: true);
    }
  }



  Future<void> _logout() async {
    // عرض نافذة التأكيد أولاً
    final bool? confirmed = await _showLogoutConfirmationDialog();

    // التحقق مما إذا كان المستخدم قد أكد تسجيل الخروج (وضمان أن الواجهة لا تزال mounted)
    if (confirmed == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) { // تحقق مرة أخرى قبل استخدام context
          Navigator.of(context).pushReplacementNamed('/login');
          _showFeedbackSnackBar(context, 'تم تسجيل الخروج بنجاح.', isError: false);
        }
      } catch (e) {
        if (mounted) { // تحقق مرة أخرى قبل استخدام context
          _showFeedbackSnackBar(context, 'فشل تسجيل الخروج: $e', isError: true);
        }
      }
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
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

  String _formatTimeForDisplay(DateTime? dateTime) { //
    if (dateTime == null) return 'غير متوفر';
    return DateFormat('hh:mm a  dd/MM/yyyy', 'ar').format(dateTime); // Arabic AM/PM and date
  }


  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEngineerUid == null) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(title: const Text('خطأ', style: TextStyle(color: Colors.white)), backgroundColor: AppConstants.primaryColor, centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 80, color: AppConstants.errorColor),
                const SizedBox(height: AppConstants.itemSpacing),
                const Text('فشل تحميل معلومات المستخدم. الرجاء تسجيل الدخول مرة أخرى.', style: TextStyle(fontSize: 18, color: AppConstants.textPrimary), textAlign: TextAlign.center),
                const SizedBox(height: AppConstants.itemSpacing),
                ElevatedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white), label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor)),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppConstants.backgroundColor,
          appBar: _buildAppBar(),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
              : FadeTransition(
            opacity: _fadeAnimation,
            child: TabBarView(
              children: [
                _buildMyProjectsTab(),
                _buildAttendanceTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _engineerName != null ? 'أهلاً، $_engineerName' : 'لوحة تحكم المهندس',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22),
      ),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
      elevation: 3,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: 'الإشعارات',
          onPressed: () => Navigator.pushNamed(context, '/notifications'), //
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          tooltip: 'تسجيل الخروج',
          onPressed: _logout,
        ),
      ],
      bottom: TabBar(
        indicatorColor: Colors.white,
        indicatorWeight: 3.0,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, fontFamily: 'Tajawal'), // Example using a common Arabic font
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
        tabs: const [
          Tab(text: 'مشاريعي', icon: Icon(Icons.business_center_outlined)),
          Tab(text: 'الحضور والانصراف', icon: Icon(Icons.timer_outlined)),
        ],
      ),
    );
  }

  Widget _buildMyProjectsTab() { //
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('engineerId', isEqualTo: _currentEngineerUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ في تحميل المشاريع: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد مشاريع مخصصة لك حالياً.', icon: Icons.work_off_outlined);
        }

        final projects = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            final data = project.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'اسم مشروع غير متوفر';
            final currentStage = data['currentStage'] ?? 0; //
            final currentPhaseName = data['currentPhaseName'] ?? 'لا توجد مراحل بعد'; //
            final clientName = data['clientName'] ?? 'غير معروف';
            final status = data['status'] ?? 'غير محدد';

            IconData statusIcon;
            Color statusColor;
            switch (status) {
              case 'نشط': statusIcon = Icons.construction_rounded; statusColor = AppConstants.infoColor; break;
              case 'مكتمل': statusIcon = Icons.check_circle_outline_rounded; statusColor = AppConstants.successColor; break;
              case 'معلق': statusIcon = Icons.pause_circle_outline_rounded; statusColor = AppConstants.warningColor; break;
              default: statusIcon = Icons.help_outline_rounded; statusColor = AppConstants.textSecondary;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
              elevation: 2,
              shadowColor: AppConstants.primaryColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: () => Navigator.pushNamed(context, '/projectDetails', arguments: project.id), //
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 26),
                          const SizedBox(width: AppConstants.paddingSmall),
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary), overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppConstants.textSecondary, size: 18),
                        ],
                      ),
                      const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
                      _buildProjectInfoRow(Icons.stairs_outlined, 'المرحلة الحالية:', '$currentStage - $currentPhaseName'),
                      _buildProjectInfoRow(Icons.person_outline_rounded, 'العميل:', clientName),
                      _buildProjectInfoRow(statusIcon, 'الحالة:', status, valueColor: statusColor),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjectInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAttendanceTab() { //
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        children: [
          _buildAttendanceStatusCard(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildAttendanceActionButtons(),
          const SizedBox(height: AppConstants.paddingLarge),
          _buildTodayAttendanceSection(),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatusCard() {
    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            Icon(
              _isCheckedIn ? Icons.work_history_rounded : Icons.home_work_outlined,
              size: 50,
              color: _isCheckedIn ? AppConstants.successColor : AppConstants.warningColor,
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(
              _isCheckedIn ? 'أنت مسجل حضور حالياً' : 'أنت مسجل انصراف حالياً',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isCheckedIn ? AppConstants.successColor : AppConstants.warningColor),
            ),
            if (_lastCheckTime != null) ...[
              const SizedBox(height: AppConstants.paddingSmall),
              Text('آخر تسجيل: ${_formatTimeForDisplay(_lastCheckTime)}', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: !_isCheckedIn ? () => _showSignatureDialog('check_in') : null,
            icon: const Icon(Icons.login_rounded, color: Colors.white),
            label: const Text('تسجيل الحضور', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.successColor,
              disabledBackgroundColor: AppConstants.successColor.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.itemSpacing),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isCheckedIn ? () => _showSignatureDialog('check_out') : null,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            label: const Text('تسجيل الانصراف', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.warningColor,
              disabledBackgroundColor: AppConstants.warningColor.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayAttendanceSection() {
    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppConstants.primaryLight.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppConstants.borderRadius), topRight: Radius.circular(AppConstants.borderRadius)),
            ),
            child: const Row(
              children: [
                Icon(Icons.history_edu_rounded, color: AppConstants.primaryColor),
                SizedBox(width: AppConstants.paddingSmall),
                Text('سجل اليوم', style: TextStyle(color: AppConstants.primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            height: 250, // Constrain height for the list
            child: _buildTodayAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceList() { //
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _currentEngineerUid)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('خطأ في تحميل سجل اليوم.');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد سجلات لليوم الحالي.', icon: Icons.event_busy_outlined);
        }

        final records = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index].data() as Map<String, dynamic>;
            final timestamp = (record['timestamp'] as Timestamp).toDate();
            final type = record['type'] as String;
            final isCheckIn = type == 'check_in';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: (isCheckIn ? AppConstants.successColor : AppConstants.warningColor).withOpacity(0.15),
                child: Icon(isCheckIn ? Icons.login_rounded : Icons.logout_rounded, color: isCheckIn ? AppConstants.successColor : AppConstants.warningColor, size: 22),
              ),
              title: Text(isCheckIn ? 'تسجيل حضور' : 'تسجيل انصراف', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppConstants.textPrimary)),
              subtitle: Text(_formatTimeForDisplay(timestamp), style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
              dense: true,
            );
          },
          separatorBuilder: (context, index) => const Divider(height: 0.5, indent: AppConstants.paddingLarge, endIndent: AppConstants.paddingLarge),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 60, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 16, color: AppConstants.textSecondary, fontWeight:FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {IconData icon = Icons.inbox_rounded}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 70, color: AppConstants.textSecondary.withOpacity(0.4)),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.textSecondary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}