import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling and text with improved color scheme
class AppConstants {
  // Primary colors - soft and professional
  static const Color primaryColor = Color(0xFF2563EB); // Modern blue
  static const Color primaryLight = Color(0xFF3B82F6); // Lighter blue
  static const Color primaryDark = Color(0xFF1E40AF); // Darker blue

  // Secondary colors
  static const Color accentColor = Color(0xFF10B981); // Emerald green
  static const Color surfaceColor = Color(0xFFFAFAFA); // Very light gray
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC); // Soft background

  // Text colors
  static const Color textPrimary = Color(0xFF1F2937); // Dark gray
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray
  static const Color textLight = Color(0xFF9CA3AF); // Light gray

  // Status colors
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color infoColor = Color(0xFF3B82F6); // Blue

  // Spacing and dimensions
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  static const double borderRadius = 16.0;
  static const double borderRadiusSmall = 8.0;
  static const double itemSpacing = 16.0;

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Statistics variables
  int _engineerCount = 0;
  int _clientCount = 0;
  int _activeProjectCount = 0;
  int _totalRevenueCount = 0;
  bool _isLoadingStats = true;
  String? _statsError;

  // User greeting
  String _currentGreeting = '';
  String _userName = 'مسؤول النظام';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setGreeting();
    _fetchDashboardStats();
    _getCurrentUserName();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _currentGreeting = 'صباح الخير';
    } else if (hour < 17) {
      _currentGreeting = 'مساء الخير';
    } else {
      _currentGreeting = 'مساء الخير';
    }
  }

  Future<void> _getCurrentUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['name'] ?? 'مسؤول النظام';
          });
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
  }

  Future<void> _fetchDashboardStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      // Fetch statistics in parallel for better performance
      final List<Future> futures = [
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'engineer')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'client')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('projects')
            .where('status', isEqualTo: 'نشط')
            .count()
            .get(),
      ];

      final results = await Future.wait(futures);

      setState(() {
        _engineerCount = (results[0] as AggregateQuerySnapshot).count!;
        _clientCount = (results[1] as AggregateQuerySnapshot).count!;
        _activeProjectCount = (results[2] as AggregateQuerySnapshot).count!;
        _totalRevenueCount = 450000; // Mock data - replace with actual calculation
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
        _statsError = 'فشل في جلب الإحصائيات. يرجى المحاولة مرة أخرى.';
      });
      _showErrorSnackBar('فشل في جلب الإحصائيات: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await _showLogoutConfirmation();
    if (!confirmed!) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
        _showSuccessSnackBar('تم تسجيل الخروج بنجاح');
      }
    } catch (e) {
      _showErrorSnackBar('فشل تسجيل الخروج: $e');
    }
  }

  Future<bool?> _showLogoutConfirmation() async {
    return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: const Text('تأكيد تسجيل الخروج'),
            content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
            actions: [
            TextButton(
            onPressed: () => Navigator.of(context).pop(false),
    child: const Text('إلغاء'),
    ),
    ElevatedButton(
    onPressed: () => Navigator.of(context).pop(true),
    style: ElevatedButton.styleFrom(
    backgroundColor: AppConstants.errorColor,
    foregroundColor: Colors.white,
    ),
    child: const Text('تسجيل الخروج'),
    ),],
        ),);

  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: _fetchDashboardStats,
              color: AppConstants.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: AppConstants.paddingXLarge),
                    _buildStatsOverview(),
                    const SizedBox(height: AppConstants.paddingXLarge),
                    _buildSectionHeader('أقسام الإدارة الرئيسية'),
                    const SizedBox(height: AppConstants.paddingLarge),
                    _buildManagementGrid(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'لوحة تحكم الإدارة',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
      ),
      backgroundColor: AppConstants.primaryColor,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: 'الإشعارات',
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {

              case 'settings':
                Navigator.pushNamed(context, '/admin/settings');
                break;
              case 'logout':
                _logout(context);
                break;
            }
          },
          itemBuilder: (context) => [

            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined,color: Colors.blueAccent,),
                  SizedBox(width: 8),
                  Text('الإعدادات'),
                ],
              ),
            ),
            const PopupMenuDivider(),
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
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingXLarge),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: AppConstants.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            '$_currentGreeting،',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingSmall,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'إدارة شاملة لنظام المهندسين',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppConstants.paddingMedium),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppConstants.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppConstants.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: AppConstants.primaryColor,
                size: 28,
              ),
              const SizedBox(width: AppConstants.paddingMedium),
              const Text(
                'نظرة عامة سريعة',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                ),
              ),
              const Spacer(),
              if (!_isLoadingStats)
                IconButton(
                  onPressed: _fetchDashboardStats,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppConstants.primaryColor,
                  ),
                  tooltip: 'تحديث الإحصائيات',
                ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          _isLoadingStats
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(AppConstants.paddingXLarge),
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            ),
          )
              : _statsError != null
              ? _buildErrorState()
              : _buildStatsGrid(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        border: Border.all(color: AppConstants.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppConstants.errorColor,
            size: 48,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            _statsError!,
            style: const TextStyle(
              color: AppConstants.errorColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          ElevatedButton.icon(
            onPressed: _fetchDashboardStats,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        // Projects Overview
        _buildStatCard(
          _StatData(
            icon: Icons.work_rounded,
            value: _activeProjectCount.toString(),
            label: 'مشروع نشط',
            color: AppConstants.warningColor,
            isPositive: true,
          ),
          isFullWidth: true, // Make this card span full width
        ),
        const SizedBox(height: AppConstants.paddingMedium), // Spacing between rows
        // Engineers and Clients
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                _StatData(
                  icon: Icons.engineering_rounded,
                  value: _engineerCount.toString(),
                  label: 'مهندس',
                  color: AppConstants.successColor,
                  isPositive: true,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _buildStatCard(
                _StatData(
                  icon: Icons.people_rounded,
                  value: _clientCount.toString(),
                  label: 'عميل',
                  color: AppConstants.infoColor,
                  isPositive: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatData stat, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null, // Set width based on isFullWidth
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      decoration: BoxDecoration(
        color: stat.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: stat.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(stat.icon, size: 36, color: stat.color),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: stat.color,
            ),
          ),
          Text(
            stat.label,
            style: const TextStyle(
              fontSize: 14,
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementGrid() {
    final managementItems = [
      _ManagementItem(
        title: 'إدارة المهندسين',
        subtitle: 'عرض وإدارة المهندسين',
        icon: Icons.engineering_rounded,
        color: AppConstants.successColor,
        route: '/admin/engineers',
      ),
      _ManagementItem(
        title: 'إدارة العملاء',
        subtitle: 'عرض وإدارة العملاء',
        icon: Icons.people_rounded,
        color: AppConstants.infoColor,
        route: '/admin/clients',
      ),
      _ManagementItem(
        title: 'إدارة الموظفين',
        subtitle: 'عرض وإدارة الموظفين',
        icon: Icons.badge_rounded,
        color: AppConstants.primaryColor,
        route: '/admin/employees',
      ),
      _ManagementItem(
        title: 'عرض المشاريع',
        subtitle: 'متابعة جميع المشاريع',
        icon: Icons.work_rounded,
        color: AppConstants.warningColor,
        route: '/admin/projects',
      ),
      _ManagementItem(
        title: 'كشف حضور',
        subtitle: 'متابعة حضور الموظفين',
        icon: Icons.access_time_filled_rounded,
        color: const Color(0xFF8B5CF6),
        route: '/admin/attendance',
      ),
      _ManagementItem(
        title: 'الإعدادات العامة',
        subtitle: 'إعدادات النظام',
        icon: Icons.settings_rounded,
        color: AppConstants.textSecondary,
        route: '/admin/settings',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppConstants.paddingMedium,
        mainAxisSpacing: AppConstants.paddingMedium,
        childAspectRatio: 0.9,
      ),
      itemCount: managementItems.length,
      itemBuilder: (context, index) => _buildManagementCard(managementItems[index]),
    );
  }

  Widget _buildManagementCard(_ManagementItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, item.route),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    item.icon,
                    size: 32,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  item.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// Data classes
class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isPositive;

  _StatData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isPositive,
  });
}

class _ManagementItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _ManagementItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}