import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // لاستخدام Firestore

// Constants for consistent styling and text (يمكنك وضعها في ملف منفصل إذا كنت تستخدمها في أماكن أخرى)
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح
  static const Color warningColor = Colors.orange; // لون للتحذير

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0; // تباعد بين العناصر
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // متغيرات لتخزين أعداد الإحصائيات
  int _engineerCount = 0;
  int _clientCount = 0;
  int _activeProjectCount = 0;
  bool _isLoadingStats = true; // حالة تحميل الإحصائيات
  String? _statsError; // لتخزين أي أخطاء تحدث أثناء جلب الإحصائيات

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats(); // جلب الإحصائيات عند تهيئة الصفحة
  }

  // دالة لجلب الإحصائيات من Firebase Firestore
  Future<void> _fetchDashboardStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null; // إعادة تعيين الخطأ
    });

    try {
      // جلب عدد المهندسين
      final engineerSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .count()
          .get();
      _engineerCount = engineerSnapshot.count!;

      // جلب عدد العملاء
      final clientSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'client')
          .count()
          .get();
      _clientCount = clientSnapshot.count!;

      // جلب عدد المشاريع النشطة
      final activeProjectSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('status', isEqualTo: 'نشط')
          .count()
          .get();
      _activeProjectCount = activeProjectSnapshot.count!;

      setState(() {
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
        _statsError = 'فشل في جلب الإحصائيات: $e';
      });
      // يمكنك إظهار SnackBar هنا إذا أردت إبلاغ المستخدم بخطأ فوراً
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('فشل جلب الإحصائيات: $e'), backgroundColor: AppConstants.errorColor),
      // );
    }
  }

  // دالة لتسجيل الخروج
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // إذا نجح تسجيل الخروج، قم بإعادة التوجيه
      Navigator.of(context).pushReplacementNamed('/login');
      // يمكنك عرض SnackBar للنجاح هنا
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الخروج بنجاح.'), backgroundColor: AppConstants.successColor),
      );
    } catch (e) {
      // في حال حدوث خطأ، قم بطباعة الخطأ وعرض SnackBar للمستخدم
      print("Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الخروج: $e'), backgroundColor: AppConstants.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // جعل الواجهة من اليمين لليسار
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'لوحة تحكم الإدارة',
            style: TextStyle(
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
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // قسم الترحيب
              _buildWelcomeSection(),
              const SizedBox(height: AppConstants.itemSpacing * 2),

              // قسم الإحصائيات الموجزة
              _buildStatsOverview(),
              const SizedBox(height: AppConstants.itemSpacing * 2),

              // عنوان لأقسام الإدارة
              Text(
                'أقسام الإدارة الرئيسية',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
                textAlign: TextAlign.right, // ليتناسب مع RTL
              ),
              const SizedBox(height: AppConstants.itemSpacing),

              // شبكة من بطاقات المهام
              GridView.count(
                shrinkWrap: true, // مهم لجعل GridView يعمل داخل SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(), // تعطيل السكرول الخاص بالـ GridView
                crossAxisCount: 2, // عمودين
                crossAxisSpacing: AppConstants.itemSpacing,
                mainAxisSpacing: AppConstants.itemSpacing,
                childAspectRatio: 1.2, // نسبة العرض إلى الارتفاع للبطاقات
                children: [
                  _DashboardGridTile(
                    title: 'إدارة المهندسين',
                    icon: Icons.engineering,
                    color: Colors.teal.shade400, // لون مميز
                    onTap: () => Navigator.pushNamed(context, '/admin/engineers'),
                  ),
                  _DashboardGridTile(
                    title: 'إدارة العملاء',
                    icon: Icons.person_outline,
                    color: Colors.blueGrey.shade400,
                    onTap: () => Navigator.pushNamed(context, '/admin/clients'),
                  ),
                  _DashboardGridTile(
                    title: 'إدارة الموظفين',
                    icon: Icons.group_outlined,
                    color: Colors.purple.shade400,
                    onTap: () => Navigator.pushNamed(context, '/admin/employees'),
                  ),
                  _DashboardGridTile(
                    title: 'عرض جميع المشاريع',
                    icon: Icons.work_outline,
                    color: Colors.orange.shade400,
                    onTap: () => Navigator.pushNamed(context, '/admin/projects'),
                  ),
                  _DashboardGridTile(
                    title: 'التقارير والإحصائيات',
                    icon: Icons.analytics_outlined,
                    color: Colors.green.shade400,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('صفحة التقارير قيد الإنشاء')),
                      );
                    },
                  ),
                  _DashboardGridTile(
                    title: 'الإعدادات العامة',
                    icon: Icons.settings_outlined,
                    color: Colors.grey.shade600,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('صفحة الإعدادات قيد الإنشاء')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.itemSpacing * 2),
            ],
          ),
        ),
      ),
    );
  }

  // --- مكونات مساعدة لبناء واجهة المستخدم ---

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.padding),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Align text to the start (right for RTL)
        children: [
          const Text(
            'مرحباً بك،',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'مسؤول النظام!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'هذه لوحة التحكم الرئيسية لإدارة نظام المهندسين.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.right, // ليتناسب مع RTL
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Card(
      color: AppConstants.cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نظرة عامة سريعة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConstants.textColor,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            _isLoadingStats
                ? const Center(
              child: CircularProgressIndicator(color: AppConstants.primaryColor),
            )
                : _statsError != null
                ? Center(
              child: Text(
                _statsError!,
                style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.person_add_alt_1,
                  value: _engineerCount.toString(),
                  label: 'مهندس',
                  color: Colors.green,
                ),
                _StatItem(
                  icon: Icons.people_alt,
                  value: _clientCount.toString(),
                  label: 'عميل',
                  color: Colors.blue,
                ),
                _StatItem(
                  icon: Icons.folder_open,
                  value: _activeProjectCount.toString(),
                  label: 'مشروع نشط',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            // زر لتحديث الإحصائيات يدوياً
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _isLoadingStats ? null : _fetchDashboardStats,
                icon: Icon(Icons.refresh, color: AppConstants.primaryColor),
                label: Text(
                  'تحديث الإحصائيات',
                  style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// بطاقة لعرض الإحصائيات الفردية
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppConstants.textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppConstants.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}

// بطاقة مهمة في GridView
class _DashboardGridTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardGridTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppConstants.cardColor,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell( // لجعل البطاقة قابلة للنقر مع تأثير مرئي
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.padding / 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: AppConstants.itemSpacing / 2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}