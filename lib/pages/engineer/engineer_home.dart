import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';

// Constants for consistent styling and text
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح
  static const Color warningColor = Color(0xFFFFA000); // لون للتحذير (برتقالي أغمق)
  static const Color infoColor = Color(0xFF00BCD4); // لون للمعلومات (أزرق فاتح)

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class EngineerHome extends StatefulWidget {
  const EngineerHome({super.key});

  @override
  State<EngineerHome> createState() => _EngineerHomeState();
}

class _EngineerHomeState extends State<EngineerHome> {
  // UID للمهندس الحالي
  final String? _currentEngineerUid = FirebaseAuth.instance.currentUser?.uid;
  // اسم المهندس لعرضه في شريط التطبيق
  String? _engineerName;
  // حالة الحضور الحالية
  bool _isCheckedIn = false;
  // وقت آخر تسجيل حضور/انصراف
  DateTime? _lastCheckTime;

  @override
  void initState() {
    super.initState();
    // تأكد من وجود UID للمستخدم قبل جلب البيانات
    if (_currentEngineerUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // إذا لم يكن هناك مستخدم مسجل دخول، قم بتسجيل الخروج وإعادة التوجيه لصفحة تسجيل الدخول
        _logout();
      });
    } else {
      // جلب بيانات المهندس إذا كان الـ UID متاحًا
      _fetchEngineerData();
      _checkCurrentAttendanceStatus();
    }
  }

  // دالة لجلب اسم المهندس الحالي من Firestore
  Future<void> _fetchEngineerData() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentEngineerUid).get();
      if (userDoc.exists) {
        setState(() {
          _engineerName = userDoc.data()?['name'] as String?;
        });
      }
    } catch (e) {
      // طباعة الخطأ للمساعدة في التصحيح
      print('Error fetching engineer name: $e');
    }
  }

  // فحص حالة الحضور الحالية
  Future<void> _checkCurrentAttendanceStatus() async {
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
        setState(() {
          _isCheckedIn = lastRecord['type'] == 'check_in';
          _lastCheckTime = (lastRecord['timestamp'] as Timestamp).toDate();
        });
      }
    } catch (e) {
      print('Error checking attendance status: $e');
    }
  }

  // فحص صلاحيات الموقع وحالة GPS
  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // فحص إذا كانت خدمات الموقع مفعلة
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar(context, 'يجب تفعيل خدمات الموقع (GPS) لتسجيل الحضور والانصراف');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar(context, 'يجب السماح بالوصول للموقع لتسجيل الحضور والانصراف');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar(context, 'يجب السماح بالوصول للموقع من إعدادات التطبيق');
      return false;
    }

    return true;
  }

  // الحصول على الموقع الحالي
  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _showErrorSnackBar(context, 'فشل في الحصول على الموقع الحالي');
      return null;
    }
  }

  // عرض نافذة التوقيع الرقمي
  Future<void> _showSignatureDialog(String type) async {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 2,
      penColor: AppConstants.primaryColor,
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            type == 'check_in' ? 'توقيع تسجيل الحضور' : 'توقيع تسجيل الانصراف',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            height: 200,
            width: 300,
            child: Column(
              children: [
                Text(
                  'الرجاء وضع التوقيع في المساحة أدناه',
                  style: TextStyle(color: AppConstants.secondaryTextColor),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppConstants.primaryColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Signature(
                    controller: controller,
                    height: 150,
                    backgroundColor: Colors.grey[100]!,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('مسح'),
              onPressed: () {
                controller.clear();
              },
            ),
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _processAttendance(type, controller);
                } else {
                  _showErrorSnackBar(context, 'الرجاء وضع التوقيع قبل المتابعة');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // معالجة عملية تسجيل الحضور/الانصراف
  Future<void> _processAttendance(String type, SignatureController signatureController) async {
    try {
      // فحص صلاحيات الموقع
      final hasLocationPermission = await _checkLocationPermissions();
      if (!hasLocationPermission) return;

      // الحصول على الموقع الحالي
      final position = await _getCurrentLocation();
      if (position == null) return;

      // تحويل التوقيع إلى بيانات
      final signatureData = await signatureController.toPngBytes();

      // إنشاء سجل الحضور
      final attendanceData = {
        'userId': _currentEngineerUid,
        'userName': _engineerName ?? 'غير معروف',
        'type': type, // 'check_in' أو 'check_out'
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
        'signatureData': signatureData,
        'deviceInfo': {
          'platform': 'mobile',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      };

      // حفظ السجل في قاعدة البيانات
      await FirebaseFirestore.instance
          .collection('attendance')
          .add(attendanceData);

      // تحديث الحالة المحلية
      setState(() {
        _isCheckedIn = type == 'check_in';
        _lastCheckTime = DateTime.now();
      });

      // عرض رسالة نجاح
      final message = type == 'check_in'
          ? 'تم تسجيل الحضور بنجاح'
          : 'تم تسجيل الانصراف بنجاح';
      _showSuccessSnackBar(context, message);

    } catch (e) {
      _showErrorSnackBar(context, 'فشل في تسجيل ${type == 'check_in' ? 'الحضور' : 'الانصراف'}: $e');
    }
  }

  // دالة لتسجيل الخروج من Firebase
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
        _showSuccessSnackBar(context, 'تم تسجيل الخروج بنجاح.');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'فشل تسجيل الخروج: $e');
      }
    }
  }

  // دالة مساعدة لعرض رسائل النجاح للمستخدم
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // دالة مساعدة لعرض رسائل الخطأ للمستخدم
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // عرض واجهة خطأ إذا لم يكن هناك UID للمهندس (لم يتم تسجيل الدخول بشكل صحيح)
    if (_currentEngineerUid == null) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text('خطأ', style: TextStyle(color: Colors.white)),
          backgroundColor: AppConstants.primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: AppConstants.errorColor),
              const SizedBox(height: AppConstants.itemSpacing),
              Text(
                'فشل تحميل معلومات المستخدم. الرجاء تسجيل الدخول مرة أخرى.',
                style: TextStyle(fontSize: 18, color: AppConstants.textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    // الواجهة الرئيسية للمهندس مع تبويبات المشاريع وتسجيل الحضور
    return Directionality(
      textDirection: TextDirection.rtl, // تحديد اتجاه النص من اليمين لليسار
      child: DefaultTabController(
        length: 2, // عدد التبويبات: المشاريع وتسجيل الحضور
        child: Scaffold(
          backgroundColor: AppConstants.backgroundColor,
          appBar: AppBar(
            title: Text(
              _engineerName != null ? 'مرحباً، $_engineerName!' : 'لوحة تحكم المهندس',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            backgroundColor: AppConstants.primaryColor,
            elevation: 4,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'تسجيل الخروج',
                onPressed: _logout,
              ),
            ],
            // تبويبات التنقل بين المشاريع وتسجيل الحضور
            bottom: const TabBar(
              indicatorColor: Colors.white, // لون المؤشر تحت التبويب النشط
              labelColor: Colors.white, // لون نص التبويب النشط
              unselectedLabelColor: Colors.white70, // لون نص التبويب غير النشط
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              tabs: [
                Tab(text: 'مشاريعي', icon: Icon(Icons.folder_open)),
                Tab(text: 'تسجيل الحضور والانصراف', icon: Icon(Icons.access_time)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildMyProjectsTab(), // محتوى تبويب "مشاريعي"
              _buildAttendanceTab(), // محتوى تبويب "تسجيل الحضور والانصراف"
            ],
          ),
        ),
      ),
    );
  }

  // بناء تبويب عرض المشاريع المخصصة للمهندس
  Widget _buildMyProjectsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('engineerId', isEqualTo: _currentEngineerUid) // فلترة المشاريع بالمهندس الحالي
          .orderBy('createdAt', descending: true) // ترتيب حسب تاريخ الإنشاء الأحدث
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          // عرض رسالة خطأ واضحة إذا فشل تحميل المشاريع
          return Center(
            child: Text(
              'حدث خطأ في تحميل المشاريع: ${snapshot.error}',
              style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // عرض رسالة إذا لم يكن هناك مشاريع مخصصة للمهندس
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                const SizedBox(height: AppConstants.itemSpacing),
                Text(
                  'لا توجد مشاريع مخصصة لك حتى الآن.',
                  style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                Text(
                  'الرجاء التواصل مع المسؤول لمزيد من المعلومات.',
                  style: TextStyle(fontSize: 14, color: AppConstants.secondaryTextColor.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final projects = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.padding / 2),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            final data = project.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? 'اسم مشروع غير متوفر';
            final currentStage = data['currentStage'] as int? ?? 1;
            final clientName = data['clientName'] as String? ?? 'غير معروف';
            final status = data['status'] as String? ?? 'غير محدد'; // حالة المشروع

            // تحديد أيقونة ولون بناءً على حالة المشروع
            Color statusColor = AppConstants.secondaryTextColor;
            IconData statusIcon = Icons.info_outline;
            if (status == 'نشط') {
              statusColor = AppConstants.successColor;
              statusIcon = Icons.play_circle_fill_outlined;
            } else if (status == 'مكتمل') {
              statusColor = Colors.blue.shade600;
              statusIcon = Icons.check_circle_outline;
            } else if (status == 'معلق') {
              statusColor = AppConstants.warningColor;
              statusIcon = Icons.pause_circle_outline;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(statusIcon, color: statusColor),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textColor,
                  ),
                  overflow: TextOverflow.ellipsis, // لقطع النص الطويل
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المرحلة الحالية: $currentStage / 12',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.secondaryTextColor,
                      ),
                    ),
                    Text(
                      'العميل: $clientName',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppConstants.secondaryTextColor.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'الحالة: $status',
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true, // للسماح بعرض 3 أسطر في العنوان الفرعي
                trailing: const Icon(Icons.arrow_forward_ios, color: AppConstants.accentColor),
                onTap: () {
                  // عند النقر، انتقل إلى صفحة تفاصيل المشروع
                  Navigator.pushNamed(context, '/projectDetails', arguments: project.id);
                },
              ),
            );
          },
        );
      },
    );
  }

  // بناء تبويب تسجيل الحضور والانصراف
  Widget _buildAttendanceTab() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.padding),
      child: Column(
        children: [
          // بطاقة الحالة الحالية
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.padding),
              child: Column(
                children: [
                  Icon(
                    _isCheckedIn ? Icons.work : Icons.home,
                    size: 60,
                    color: _isCheckedIn ? AppConstants.successColor : AppConstants.warningColor,
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),
                  Text(
                    _isCheckedIn ? 'أنت حالياً في العمل' : 'أنت غير متواجد في العمل',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isCheckedIn ? AppConstants.successColor : AppConstants.warningColor,
                    ),
                  ),
                  if (_lastCheckTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'آخر تسجيل: ${_formatTime(_lastCheckTime!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.secondaryTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.itemSpacing * 2),

          // أزرار تسجيل الحضور والانصراف
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !_isCheckedIn
                      ? () => _showSignatureDialog('check_in')
                      : null,
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text(
                    'تسجيل الحضور',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCheckedIn
                        ? AppConstants.secondaryTextColor
                        : AppConstants.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.itemSpacing),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isCheckedIn
                      ? () => _showSignatureDialog('check_out')
                      : null,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'تسجيل الانصراف',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isCheckedIn
                        ? AppConstants.secondaryTextColor
                        : AppConstants.warningColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.itemSpacing * 2),

          // سجل الحضور لليوم الحالي
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppConstants.borderRadius),
                        topRight: Radius.circular(AppConstants.borderRadius),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.history, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'سجل اليوم',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildTodayAttendanceList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء قائمة سجل الحضور لليوم الحالي
  Widget _buildTodayAttendanceList() {
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
          return Center(
            child: Text(
              'خطأ في تحميل السجل',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد سجلات لليوم الحالي',
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        final records = snapshot.data!.docs;

        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index].data() as Map<String, dynamic>;
            final timestamp = (record['timestamp'] as Timestamp).toDate();
            final type = record['type'] as String;
            final isCheckIn = type == 'check_in';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isCheckIn
                    ? AppConstants.successColor.withOpacity(0.2)
                    : AppConstants.warningColor.withOpacity(0.2),
                child: Icon(
                  isCheckIn ? Icons.login : Icons.logout,
                  color: isCheckIn ? AppConstants.successColor : AppConstants.warningColor,
                ),
              ),
              title: Text(
                isCheckIn ? 'تسجيل حضور' : 'تسجيل انصراف',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                _formatTime(timestamp),
                style: TextStyle(
                  color: AppConstants.secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              trailing: Icon(
                Icons.check_circle,
                color: AppConstants.successColor,
                size: 20,
              ),
            );
          },
        );
      },
    );
  }

  // دالة لتنسيق الوقت
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;

    return '$day/$month/$year - $hour:$minute';
  }
}