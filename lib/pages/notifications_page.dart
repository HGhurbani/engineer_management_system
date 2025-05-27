// lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:ui' as ui;

// Constants for consistent styling, aligned with the admin dashboard's style.
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B); // Not used here but good for consistency
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6); // Used for info snackbar
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color deleteColor = errorColor; // Used in popup menu
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0; //
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
        color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String? _currentUserRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchUserRole();
    } else {
      // Handle case where user is somehow null, though AuthWrapper should prevent this.
      setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _fetchUserRole() async { //
    if (_currentUser == null) {
      if (mounted) setState(() => _isLoadingRole = false);
      return;
    }
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>?; //
        if (userData != null) {
          setState(() {
            _currentUserRole = userData['role'] as String?;
          });
        }
      }
    } catch (e) {
      print('Error fetching user role: $e');
      if (mounted) _showFeedbackSnackBar(context, 'فشل تحميل دور المستخدم.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async { //
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
      // Optionally show a success message, though it might be too intrusive for this action.
    } catch (e) {
      print('Error marking notification as read: $e');
      if (mounted) _showFeedbackSnackBar(context, 'فشل تحديث حالة الإشعار.', isError: true);
    }
  }

  Future<void> _deleteNotification(String notificationId) async { //
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          title: const Text('تأكيد الحذف', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا الإشعار؟', style: TextStyle(color: AppConstants.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.deleteColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2))),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('notifications').doc(notificationId).delete();
        if (mounted) _showFeedbackSnackBar(context, 'تم حذف الإشعار بنجاح.', isError: false);
      } catch (e) {
        if (mounted) _showFeedbackSnackBar(context, 'فشل حذف الإشعار: $e', isError: true);
      }
    }
  }

  void _handleNotificationTap(String projectId, String? phaseDocId, String notificationType) { //
    if (!mounted) return;
    String route = '';
    if (_currentUserRole == 'admin') {
      route = '/admin/projectDetails';
    } else if (_currentUserRole == 'engineer') {
      route = '/projectDetails';
    } else if (_currentUserRole == 'client') {
      route = '/client';
    }

    if (route.isNotEmpty) {
      if (route.contains('projectDetails')) { // For admin and engineer
        if (projectId.isNotEmpty) {
          Navigator.pushNamed(context, route, arguments: projectId);
        } else {
          _showFeedbackSnackBar(context, 'معرّف المشروع غير متوفر في هذا الإشعار.', isError: true);
        }
      } else { // For client, navigate to their home
        Navigator.pushNamed(context, route);
      }
    } else {
      _showFeedbackSnackBar(context, 'لا يمكن تحديد وجهة الانتقال لهذا الإشعار.', isError: true);
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError, bool isInfo = false}) {
    if (!mounted) return;
    Color backgroundColor = AppConstants.successColor;
    if (isError) {
      backgroundColor = AppConstants.errorColor;
    } else if (isInfo) {
      backgroundColor = AppConstants.infoColor;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'الإشعارات',
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
      elevation: 3,
      centerTitle: true,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 80, color: AppConstants.textSecondary.withOpacity(0.4)),
            const SizedBox(height: AppConstants.itemSpacing),
            const Text(
              'لا توجد إشعارات جديدة حالياً.',
              style: TextStyle(fontSize: 18, color: AppConstants.textSecondary, fontWeight: FontWeight.w500),
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
            const Icon(Icons.error_outline_rounded, size: 70, color: AppConstants.errorColor),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.textPrimary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return Scaffold(appBar: _buildAppBar(), body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)));
    }
    if (_currentUser == null) {
      return Scaffold(appBar: _buildAppBar(), body: _buildErrorState('يرجى تسجيل الدخول لعرض الإشعارات.'));
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notifications')
              .where('userId', isEqualTo: _currentUser!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(), //
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (snapshot.hasError) {
              return _buildErrorState('حدث خطأ في تحميل الإشعارات: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(); //
            }

            final notifications = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(AppConstants.paddingSmall),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final Map<String, dynamic> data = notification.data() as Map<String, dynamic>? ?? {}; //

                final bool isRead = data['isRead'] as bool? ?? false; //
                final String title = data['title'] as String? ?? 'إشعار جديد'; //
                final String body = data['body'] as String? ?? 'لا توجد تفاصيل.'; //
                final Timestamp timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now(); //
                final String projectId = data['projectId'] as String? ?? ''; //
                final String? phaseDocId = data['phaseDocId'] as String?; // Nullable
                final String notificationType = data['type'] as String? ?? ''; //

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.5, horizontal: AppConstants.paddingSmall),
                  elevation: isRead ? 1.0 : 2.5,
                  shadowColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                      side: BorderSide(
                        color: isRead ? Colors.transparent : AppConstants.primaryLight.withOpacity(0.5),
                        width: 1,
                      )
                  ),
                  color: isRead ? AppConstants.cardColor : AppConstants.primaryColor.withOpacity(0.03), // Subtle highlight for unread
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall, horizontal: AppConstants.paddingMedium),
                    leading: CircleAvatar(
                      backgroundColor: isRead ? AppConstants.textSecondary.withOpacity(0.1) : AppConstants.primaryColor.withOpacity(0.15), //
                      child: Icon(
                        isRead ? Icons.notifications_none_outlined : Icons.notifications_active_rounded, //
                        color: isRead ? AppConstants.textSecondary : AppConstants.primaryColor,
                        size: 26,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold, //
                        color: AppConstants.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppConstants.paddingSmall / 2),
                        Text(
                          body,
                          style: TextStyle(fontSize: 14, color: isRead ? AppConstants.textSecondary : AppConstants.textPrimary.withOpacity(0.85)), //
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppConstants.paddingSmall / 1.5),
                        Text(
                          DateFormat('yyyy-MM-dd  hh:mm a', 'ar').format(timestamp.toDate()), //
                          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary.withOpacity(0.7)),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) _markAsRead(notification.id);
                      _handleNotificationTap(projectId, phaseDocId, notificationType); //
                    },
                    trailing: PopupMenuButton<String>( //
                      icon: Icon(Icons.more_vert_rounded, color: AppConstants.textSecondary.withOpacity(0.8)),
                      onSelected: (value) {
                        if (value == 'mark_read') {
                          _markAsRead(notification.id);
                        } else if (value == 'delete') {
                          _deleteNotification(notification.id);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        if (!isRead)
                          const PopupMenuItem<String>(
                            value: 'mark_read',
                            child: Row(children: [Icon(Icons.mark_chat_read_outlined, color: AppConstants.primaryLight, size: 20), SizedBox(width: AppConstants.paddingSmall), Text('وضع علامة مقروء')]),
                          ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(children: [Icon(Icons.delete_outline_rounded, color: AppConstants.deleteColor, size: 20), SizedBox(width: AppConstants.paddingSmall), Text('حذف الإشعار', style: TextStyle(color: AppConstants.deleteColor))]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}