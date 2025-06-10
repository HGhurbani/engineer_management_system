// lib/pages/engineer/engineer_home.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../main.dart';
import 'meeting_logs_page.dart';


class EngineerHome extends StatefulWidget {
  const EngineerHome({super.key});

  @override
  State<EngineerHome> createState() => _EngineerHomeState();
}

class _EngineerHomeState extends State<EngineerHome> with TickerProviderStateMixin {
  final String? _currentEngineerUid = FirebaseAuth.instance.currentUser?.uid;
  String? _engineerName;
  bool _isCheckedIn = false;
  DateTime? _lastCheckTime;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  final Map<String, String> _clientTypeDisplayMap = {
    'individual': 'فردي',
    'company': 'شركة',
  };

  // --- ADDITION START ---
  int _unreadNotificationsCount = 0;
  StreamSubscription? _notificationsSubscription;
  // --- ADDITION END ---

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fadeController = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    if (_currentEngineerUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logout();
      });
    } else {
      _loadInitialData();
      // --- ADDITION START ---
      _listenForUnreadNotifications();
      // --- ADDITION END ---
    }
  }

  // --- ADDITION START ---
  void _listenForUnreadNotifications() {
    if (_currentEngineerUid == null) return;
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _currentEngineerUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = snapshot.docs.length;
        });
      }
    });
  }
  // --- ADDITION END ---

  Future<void> _loadInitialData() async {
    if(!mounted) return;
    setState(() => _isLoading = true);
    await _fetchEngineerData();
    await _checkCurrentAttendanceStatus();
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  Future<void> _fetchEngineerData() async {
    if (_currentEngineerUid == null || !mounted) return;
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

  Future<void> _checkCurrentAttendanceStatus() async {
    if (_currentEngineerUid == null || !mounted) return;
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

      if (mounted) {
        if (attendanceQuery.docs.isNotEmpty) {
          final lastRecord = attendanceQuery.docs.first.data();
          setState(() {
            _isCheckedIn = lastRecord['type'] == 'check_in';
            _lastCheckTime = (lastRecord['timestamp'] as Timestamp).toDate();
          });
        } else {
          setState(() {
            _isCheckedIn = false;
            _lastCheckTime = null;
          });
        }
      }
    } catch (e) {
      print('Error checking attendance status: $e');
      if (mounted) _showFeedbackSnackBar(context, 'فشل التحقق من حالة الحضور.', isError: true);
    }
  }

  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      _showFeedbackSnackBar(context, 'يجب تفعيل خدمات الموقع (GPS) لتسجيل الحضور والانصراف.', isError: true);
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) {
        _showFeedbackSnackBar(context, 'يجب السماح بالوصول للموقع لتسجيل الحضور والانصراف.', isError: true);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      _showFeedbackSnackBar(context, 'تم رفض إذن الموقع بشكل دائم. يرجى تمكينه من إعدادات التطبيق.', isError: true);
      return false;
    }
    return true;
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل في الحصول على الموقع الحالي. حاول مرة أخرى.', isError: true);
      return null;
    }
  }
  Future<bool?> _showLogoutConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _showSignatureDialog(String type) async {
    final SignatureController controller = SignatureController(penStrokeWidth: 3, penColor: AppConstants.primaryColor, exportBackgroundColor: AppConstants.cardColor.withOpacity(0.8));
    bool isProcessing = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (stfDialogContext, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                title: Text(type == 'check_in' ? 'توقيع تسجيل الحضور' : 'توقيع تسجيل الانصراف', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                content: SizedBox(
                  width: MediaQuery.of(stfDialogContext).size.width * 0.8,
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
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton.icon(
                    icon: isProcessing ? const SizedBox.shrink() : Icon(type == 'check_in' ? Icons.login_rounded : Icons.logout_rounded, color: Colors.white),
                    label: isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text(type == 'check_in' ? 'تأكيد الحضور' : 'تأكيد الانصراف', style: const TextStyle(color: Colors.white)),
                    onPressed: isProcessing ? null : () async {
                      if (controller.isNotEmpty) {
                        setDialogState(() => isProcessing = true);
                        await _processAttendance(type, controller);
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                      } else {
                        if(mounted) _showFeedbackSnackBar(stfDialogContext, 'الرجاء وضع التوقيع قبل المتابعة.', isError: true, useDialogContext: true);
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

  Future<void> _processAttendance(String type, SignatureController signatureController) async {
    if (!mounted) return;

    // --- MODIFICATION START: Show loading indicator ---
    // You might want to add a _isLoadingProcessAttendance = true; setState(() {}); here
    // and set it to false in a finally block if you have a loading indicator in UI.
    // For now, we'll proceed without explicit UI loading state in this snippet.
    // --- MODIFICATION END ---

    try {
      final hasLocationPermission = await _checkLocationPermissions();
      if (!hasLocationPermission || !mounted) {
        // _showFeedbackSnackBar might already handle !mounted
        return;
      }

      final position = await _getCurrentLocation();
      if (position == null || !mounted) {
        return;
      }

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
        'signatureData': signatureData, // Storing as Uint8List directly might be large for Firestore. Consider uploading to Firebase Storage and storing URL.
        // However, based on the current structure, we assume it's being handled.
        'deviceInfo': {'platform': 'mobile', 'timestamp': DateTime.now().millisecondsSinceEpoch}
      };

      await FirebaseFirestore.instance.collection('attendance').add(attendanceData);

      // --- MODIFICATION START: Send notification to admins ---
      if (_currentEngineerUid != null && _engineerName != null) {
        List<String> adminUids = await getAdminUids(); // Call the helper function
        if (adminUids.isNotEmpty) {
          String notificationTitle = type == 'check_in' ? "تسجيل حضور مهندس" : "تسجيل انصراف مهندس";
          String notificationBody = "المهندس ${_engineerName ?? 'غير معروف'} قام بتسجيل ${type == 'check_in' ? 'الحضور' : 'الانصراف'}.";
          String notificationType = type == 'check_in' ? "attendance_check_in" : "attendance_check_out";

          await sendNotificationsToMultiple(
            recipientUserIds: adminUids,
            title: notificationTitle,
            body: notificationBody,
            type: notificationType,
            itemId: _currentEngineerUid, // Pass engineer's UID as itemId for context
            senderName: _engineerName,
          );
        }
      }
      // --- MODIFICATION END ---

      if (mounted) {
        setState(() {
          _isCheckedIn = type == 'check_in';
          _lastCheckTime = DateTime.now();
          // If you have a signature pad, clear it after successful submission
          signatureController.clear();
        });
        final message = type == 'check_in' ? 'تم تسجيل الحضور بنجاح.' : 'تم تسجيل الانصراف بنجاح.';
        _showFeedbackSnackBar(context, message, isError: false);
      }
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل تسجيل ${type == 'check_in' ? 'الحضور' : 'الانصراف'}: $e', isError: true);
    } finally { // --- MODIFICATION START: Hide loading indicator ---
      // if (mounted) setState(() => _isLoadingProcessAttendance = false);
      // --- MODIFICATION END ---
    }
  }

  Future<void> _logout() async {
    final bool? confirmed = await _showLogoutConfirmationDialog();
    if (confirmed == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
          _showFeedbackSnackBar(context, 'تم تسجيل الخروج بنجاح.', isError: false);
        }
      } catch (e) {
        if (mounted) {
          _showFeedbackSnackBar(context, 'فشل تسجيل الخروج: $e', isError: true);
        }
      }
    }
  }

  void _showFeedbackSnackBar(BuildContext scaffoldOrDialogContext, String message, {required bool isError, bool useDialogContext = false}) {
    if (!mounted && !useDialogContext) return;
    if (useDialogContext && !Navigator.of(scaffoldOrDialogContext).canPop() && !mounted) return; // Check if dialog context can pop

    final SnackBar snackBar = SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
    );
    ScaffoldMessenger.of(scaffoldOrDialogContext).showSnackBar(snackBar);
  }


  String _formatTimeForDisplay(DateTime? dateTime) {
    if (dateTime == null) return 'غير متوفر';
    return DateFormat('hh:mm a  dd/MM/yyyy', 'ar').format(dateTime);
  }

  Future<void> _endWorkDayForProject(String projectId) async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();
      final settings = settingsDoc.data() as Map<String, dynamic>? ?? {};
      final startString = settings['workStartTime'] ?? '06:30';
      final parts = startString.split(':');
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));

      final weekly = List<int>.from(settings['weeklyHolidays'] ?? []);
      final special = (settings['specialHolidays'] as List<dynamic>? ?? [])
          .map((d) => DateTime.tryParse(d as String))
          .whereType<DateTime>()
          .toList();
      final bool isHoliday =
          weekly.contains(now.weekday) ||
          special.any((d) => d.year == now.year && d.month == now.month && d.day == now.day);

      if (isHoliday) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تنبيه'),
            content: const Text('اليوم إجازة، هل تريد حسابه وقتًا إضافيًا؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      final assignments = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('employeeAssignments')
          .get();

      for (final doc in assignments.docs) {
        final empId = doc['employeeId'];
        await FirebaseFirestore.instance.collection('attendance').add({
          'userId': empId,
          'projectId': projectId,
          'type': 'check_in',
          'timestamp': Timestamp.fromDate(startDate),
          'overtime': isHoliday,
        });
        await FirebaseFirestore.instance.collection('attendance').add({
          'userId': empId,
          'projectId': projectId,
          'type': 'check_out',
          'timestamp': FieldValue.serverTimestamp(),
          'overtime': isHoliday,
        });
      }

      if (mounted) {
        _showFeedbackSnackBar(context, 'تم إنهاء يوم العمل.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل إنهاء يوم العمل: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    // --- ADDITION START ---
    _notificationsSubscription?.cancel();
    // --- ADDITION END ---
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEngineerUid == null && !_isLoading) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(title: const Text('خطأ في المصادقة', style: TextStyle(color: Colors.white)), backgroundColor: AppConstants.primaryColor, centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_accounts_outlined, size: 80, color: AppConstants.errorColor),
                const SizedBox(height: AppConstants.itemSpacing),
                const Text('لم يتم التعرف على المستخدم. يتم الآن تسجيل الخروج...', style: TextStyle(fontSize: 16, color: AppConstants.textPrimary), textAlign: TextAlign.center),
                const SizedBox(height: AppConstants.itemSpacing),
                const CircularProgressIndicator(color: AppConstants.primaryColor),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      // Removed DefaultTabController
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : FadeTransition(
          opacity: _fadeAnimation,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyProjectsTab(),
              _buildPartRequestsTab(),
              _buildDailyScheduleTab(),
              _buildMeetingLogsTab(),
            ],
          ),
        ),
      ),
    );
  }
  // --- بداية الدالة الجديدة ---
  Widget _buildDailyScheduleTab() {
    if (_currentEngineerUid == null) {
      return _buildErrorState('لا يمكن تحميل جدولك اليومي بدون معرّف مستخدم.');
    }

    // تحديد بداية ونهاية اليوم الحالي
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('daily_schedules')
          .where('engineerId', isEqualTo: _currentEngineerUid)
          .where('scheduleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .where('scheduleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
          .orderBy('createdAt', descending: false) // أو أي ترتيب آخر تفضله
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ أثناء تحميل جدولك اليومي: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            'لا توجد مهام مجدولة لك لهذا اليوم.',
            icon: Icons.calendar_today_outlined,
          );
        }

        final scheduledTasks = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          itemCount: scheduledTasks.length,
          itemBuilder: (context, index) {
            final taskDoc = scheduledTasks[index];
            final taskData = taskDoc.data() as Map<String, dynamic>;

            final String projectName = taskData['projectName'] ?? 'مشروع غير محدد';
            final String taskTitle = taskData['taskTitle'] ?? 'مهمة بدون عنوان';
            final String taskDescription = taskData['taskDescription'] ?? 'لا يوجد وصف';
            final Timestamp? scheduleTimestamp = taskData['scheduleDate'] as Timestamp?;
            final String scheduleDateFormatted = scheduleTimestamp != null
                ? DateFormat('EEEE, dd MMMM yyyy', 'ar_SA').format(scheduleTimestamp.toDate())
                : 'تاريخ غير محدد';
            final String taskStatus = taskData['status'] ?? 'pending'; // افتراضي إلى 'pending'

            IconData statusIcon;
            Color statusColor;
            String statusText;

            switch (taskStatus) {
              case 'completed':
                statusIcon = Icons.check_circle_outline_rounded;
                statusColor = AppConstants.successColor;
                statusText = 'مكتملة';
                break;
              case 'in-progress':
                statusIcon = Icons.construction_rounded; // أو أيقونة أخرى مناسبة
                statusColor = AppConstants.infoColor;
                statusText = 'قيد التنفيذ';
                break;
              case 'pending':
              default:
                statusIcon = Icons.pending_actions_rounded;
                statusColor = AppConstants.warningColor;
                statusText = 'معلقة';
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
              elevation: 2,
              shadowColor: AppConstants.primaryColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            taskTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: AppConstants.paddingSmall / 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppConstants.paddingMedium, thickness: 0.5),
                    _buildTaskDetailRow(Icons.business_center_outlined, 'المشروع:', projectName),
                    _buildTaskDetailRow(Icons.description_outlined, 'الوصف:', taskDescription, isExpandable: true),
                    _buildTaskDetailRow(Icons.calendar_month_outlined, 'التاريخ:', scheduleDateFormatted),
                    // لاحقًا: إضافة أزرار لتحديث حالة المهمة
                    if (taskStatus == 'pending' || taskStatus == 'in-progress')
                      Padding(
                        padding: const EdgeInsets.only(top: AppConstants.paddingSmall),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (taskStatus == 'pending')
                              ElevatedButton.icon(
                                label: const Text(
                                  'بدء المهمة',
                                  style: TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.infoColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.paddingSmall,
                                    vertical: AppConstants.paddingSmall / 2,
                                  ),
                                ),
                                onPressed: () {
                                  _updateTaskStatus(taskDoc.id, 'in-progress');
                                },
                              ),

                            if (taskStatus == 'in-progress') ...[
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                label: const Text('إكمال المهمة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.successColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: AppConstants.paddingSmall / 2),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  _updateTaskStatus(taskDoc.id, 'completed');
                                },
                              ),
                            ]
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
// --- نهاية الدالة الجديدة ---

// --- بداية دالة مساعدة لعرض تفاصيل المهمة ---
  Widget _buildTaskDetailRow(IconData icon, String label, String value, {bool isExpandable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          const SizedBox(width: AppConstants.paddingSmall),
          Text('$label ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: isExpandable
                ? ExpandableText(value, valueColor: AppConstants.textPrimary, trimLines: 3) // استخدام ExpandableText
                : Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
// --- نهاية دالة مساعدة ---

// --- بداية دالة تحديث حالة المهمة ---
  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('daily_schedules').doc(taskId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showFeedbackSnackBar(context, 'تم تحديث حالة المهمة بنجاح.', isError: false);

      // إرسال إشعار للمسؤول (إذا لزم الأمر)
      // يمكنك إضافة هذا الجزء إذا كنت تريد إعلام المسؤول بتحديثات حالة المهام
      final taskDoc = await FirebaseFirestore.instance.collection('daily_schedules').doc(taskId).get();
      final taskData = taskDoc.data();
      if (taskData != null && _engineerName != null) {
        final adminUids = await getAdminUids(); // تأكد من وجود هذه الدالة
        if (adminUids.isNotEmpty) {
          sendNotificationsToMultiple(
            recipientUserIds: adminUids,
            title: 'تحديث حالة مهمة يومية',
            body: 'المهندس "$_engineerName" قام بتحديث حالة المهمة "${taskData['taskTitle']}" إلى "$newStatus".',
            type: 'daily_task_status_update',
            projectId: taskData['projectId'],
            itemId: taskId,
            senderName: _engineerName,
          );
        }
      }

    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المهمة: $e', isError: true);
    }
  }
// --- نهاية دالة تحديث حالة المهمة ---

  Future<void> _updatePartRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('partRequests')
          .doc(requestId)
          .update({'status': newStatus});
      _showFeedbackSnackBar(context, 'تم تحديث حالة الطلب.', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث الطلب: $e', isError: true);
    }
  }

  Widget _buildPartRequestsTab() {
    if (_currentEngineerUid == null) {
      return _buildErrorState('لا يمكن تحميل طلبات القطع بدون معرّف مهندس.');
    }
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('partRequests')
            .where('engineerId', isEqualTo: _currentEngineerUid)
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
          }
          if (snapshot.hasError) {
            return _buildErrorState('حدث خطأ في تحميل طلبات القطع: ${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState('لا توجد طلبات قطع حالياً.', icon: Icons.list_alt_outlined);
          }

          final requests = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestDoc = requests[index];
              final data = requestDoc.data() as Map<String, dynamic>;
              final partName = data['partName'] ?? 'قطعة غير مسماة';
              final quantity = data['quantity']?.toString() ?? 'N/A';
              final projectName = data['projectName'] ?? 'مشروع غير محدد';
              final status = data['status'] ?? 'غير معروف';
              final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
              final formattedDate = requestedAt != null
                  ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(requestedAt)
                  : 'غير معروف';

              Color statusColor;
              switch (status) {
                case 'معلق':
                  statusColor = AppConstants.warningColor;
                  break;
                case 'تمت الموافقة':
                  statusColor = AppConstants.successColor;
                  break;
                case 'مرفوض':
                  statusColor = AppConstants.errorColor;
                  break;
                case 'تم الطلب':
                  statusColor = AppConstants.infoColor;
                  break;
                case 'تم الاستلام':
                  statusColor = AppConstants.primaryColor;
                  break;
                default:
                  statusColor = AppConstants.textSecondary;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                child: ListTile(
                  title: Text('اسم القطعة: $partName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الكمية: $quantity', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                      Text('المشروع: $projectName', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                      Row(
                        children: [
                          Icon(Icons.circle, color: statusColor, size: 10),
                          const SizedBox(width: 4),
                          Text(status, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Text('تاريخ الطلب: $formattedDate', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary.withOpacity(0.8))),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) => _updatePartRequestStatus(requestDoc.id, val),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'تم الطلب', child: Text('تم الطلب')),
                      PopupMenuItem(value: 'تم الاستلام', child: Text('تم الاستلام')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_currentEngineerUid != null && _engineerName != null) {
            Navigator.pushNamed(
              context,
              '/engineer/request_part',
              arguments: {
                'engineerId': _currentEngineerUid,
                'engineerName': _engineerName,
              },
            );
          } else {
            _showFeedbackSnackBar(context, 'بيانات المهندس غير متوفرة.', isError: true);
          }
        },
        label: const Text('طلب قطعة جديدة', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        backgroundColor: AppConstants.primaryColor,
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
        // --- ADDITION START ---
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              tooltip: 'الإشعارات',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            if (_unreadNotificationsCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppConstants.errorColor, // لون أحمر مميز
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _unreadNotificationsCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
          ],
        ),
        // --- ADDITION END ---
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'change_password':
                Navigator.pushNamed(context, '/engineer/change_password');
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'change_password',
              child: Row(
                children: [
                  Icon(Icons.lock_reset, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('تغيير كلمة المرور'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppConstants.errorColor),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج', style: TextStyle(color: AppConstants.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController, // Ensure this is using your state's _tabController
        indicatorColor: Colors.white,
        indicatorWeight: 3.0,
        labelColor: Colors.white,
        isScrollable: true,
        labelPadding: EdgeInsets.symmetric(horizontal: 12.0), // يمكنك الإبقاء على هذا أو تعديله
        tabAlignment: TabAlignment.start,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, fontFamily: 'Tajawal'),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
        tabs: const [
          Tab(text: 'مشاريعي', icon: Icon(Icons.business_center_outlined)),
          Tab(text: 'طلبات القطع', icon: Icon(Icons.build_circle_outlined)),
          Tab(text: 'جدولي اليومي', icon: Icon(Icons.calendar_today_rounded)),
          Tab(text: 'محاضر الاجتماعات', icon: Icon(Icons.event_note_outlined)),
        ],
      ),
    );
  }

  Widget _buildMyProjectsTab() {
    if (_currentEngineerUid == null) {
      return _buildErrorState('لا يمكن تحميل المشاريع بدون معرّف مهندس.');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('engineerUids', arrayContains: _currentEngineerUid)
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
            final currentStage = data['currentStage'] ?? 0;
            final currentPhaseName = data['currentPhaseName'] ?? 'لا توجد مراحل بعد';
            final clientName = data['clientName'] ?? 'غير معروف';
            final String clientTypeKey = data['clientType'] ?? 'individual';
            final String clientTypeDisplay = _clientTypeDisplayMap[clientTypeKey] ?? clientTypeKey;
            final status = data['status'] ?? 'غير محدد';

            final List<dynamic> assignedEngineersRaw = data['assignedEngineers'] as List<dynamic>? ?? [];
            String engineersDisplay = "غير محددين";
            if (assignedEngineersRaw.isNotEmpty) {
              engineersDisplay = assignedEngineersRaw.map((eng) => eng['name'] ?? 'م.غير معروف').join('، ');
              if (engineersDisplay.length > 40) {
                engineersDisplay = '${engineersDisplay.substring(0, 40)}...';
              }
            }

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
                onTap: () => Navigator.pushNamed(context, '/projectDetails', arguments: project.id),
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
                      // _buildProjectInfoRow(Icons.stairs_outlined, 'المرحلة الحالية:', '$currentStage - $currentPhaseName'),
                      _buildProjectInfoRow(Icons.engineering_outlined, 'المهندسون:', engineersDisplay),
                      _buildProjectInfoRow(Icons.person_outline_rounded, 'العميل:', clientName),
                      _buildProjectInfoRow(Icons.business_center_outlined, 'نوع العميل:', clientTypeDisplay),
                      _buildProjectInfoRow(statusIcon, 'الحالة:', status, valueColor: statusColor),
                      const SizedBox(height: AppConstants.itemSpacing),
                      ElevatedButton.icon(
                        onPressed: () => _endWorkDayForProject(project.id),
                        icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                        label: const Text('إنهاء يوم العمل', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                        ),
                      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
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
            height: 250,
            child: _buildTodayAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceList() {
    if (_currentEngineerUid == null) return _buildErrorState('لا يمكن تحميل سجل اليوم.');
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



  Widget _buildMeetingLogsTab() {
    if (_currentEngineerUid == null) {
      return _buildErrorState('لا يمكن تحميل المحاضر.');
    }
    return MeetingLogsPage(engineerId: _currentEngineerUid!);
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
// ... (في نهاية ملف engineer_home.dart)

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final Color? valueColor; // اجعلها اختيارية
  final TextStyle? textStyle; // نمط النص

  const ExpandableText(
      this.text, {
        super.key,
        this.trimLines = 2,
        this.valueColor, // قيمة افتراضية ستكون null
        this.textStyle, // قيمة افتراضية ستكون null
      });

  @override
  ExpandableTextState createState() => ExpandableTextState();
}

class ExpandableTextState extends State<ExpandableText> {
  bool _readMore = true;
  void _onTapLink() {
    setState(() => _readMore = !_readMore);
  }

  @override
  Widget build(BuildContext context) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle effectiveTextStyle = widget.textStyle ?? defaultTextStyle.style;
    if (widget.valueColor != null) {
      effectiveTextStyle = effectiveTextStyle.copyWith(color: widget.valueColor);
    }


    TextSpan link = TextSpan(
        text: _readMore ? " عرض المزيد" : " عرض أقل",
        style: effectiveTextStyle.copyWith( // استخدم النمط الفعال مع تعديل اللون
            color: AppConstants.primaryColor,
            fontWeight: FontWeight.bold), // استخدم لونًا مميزًا للرابط
        recognizer: TapGestureRecognizer()..onTap = _onTapLink);

    Widget result = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        assert(constraints.hasBoundedWidth);
        final double maxWidth = constraints.maxWidth;
        final text = TextSpan(
          text: widget.text,
          style: effectiveTextStyle, // استخدم النمط الفعال هنا أيضًا
        );
        TextPainter textPainter = TextPainter(
          text: link,
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          maxLines: widget.trimLines,
          ellipsis: '...',
        );
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final linkSize = textPainter.size;
        textPainter.text = text;
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final textSize = textPainter.size;
        int endIndex = textPainter.getPositionForOffset(Offset(
          textSize.width - linkSize.width,
          textSize.height,
        )).offset;

        TextSpan textSpan;
        if (textPainter.didExceedMaxLines) {
          endIndex = textPainter.getOffsetBefore(endIndex) ?? widget.text.length;
          textSpan = TextSpan(
            text: _readMore && widget.text.length > endIndex && endIndex > 0
                ? widget.text.substring(0, endIndex) + "..."
                : widget.text,
            style: effectiveTextStyle,
            children: <TextSpan>[const TextSpan(text: " "), link],
          );
        } else {
          textSpan = TextSpan(
            text: widget.text,
            style: effectiveTextStyle,
          );
        }
        return RichText(
          softWrap: true,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          text: textSpan,
        );
      },
    );
    return result;
  }
}