// lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:ui' as ui;

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
  static const Color warningColor = Color(0xFFFFA000); // لون للتحذير
  static const Color infoColor = Color(0xFF00BCD4); // لون للمعلومات (أزرق فاتح)
  static const Color deleteColor = Colors.redAccent; // NEW: Added missing deleteColor

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
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

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchUserRole();
    }
  }

  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        // NEW: Explicitly cast to Map<String, dynamic> before accessing with []
        // Use a null-aware operator for .data() and then safely access 'role'
        final userData = userDoc.data() as Map<String, dynamic>?; // Cast to nullable map
        if (userData != null) {
          setState(() {
            _currentUserRole = userData['role'] as String?; // Access 'role' from the map
          });
        }
      }
    } catch (e) {
      print('Error fetching user role: $e');
      _showErrorSnackBar(context, 'فشل تحميل دور المستخدم.');
    }
  }

  // Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
      _showErrorSnackBar(context, 'فشل تحديث الإشعار.');
    }
  }

  // Delete notification
  Future<void> _deleteNotification(String notificationId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا الإشعار؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deleteColor),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('notifications').doc(notificationId).delete();
        _showSuccessSnackBar(context, 'تم حذف الإشعار بنجاح.');
      } catch (e) {
        _showErrorSnackBar(context, 'فشل حذف الإشعار: $e');
      }
    }
  }

  // Navigate to project details based on notification type
  void _handleNotificationTap(
      String projectId, String? phaseDocId, String notificationType) {
    String route = '';
    // Determine the route based on user role and notification type
    if (_currentUserRole == 'admin') {
      route = '/admin/projectDetails';
    } else if (_currentUserRole == 'engineer') {
      route = '/projectDetails';
    } else if (_currentUserRole == 'client') {
      route = '/client'; // Navigate to client's home
    }

    if (route.isNotEmpty) {
      // If navigating to project details, pass the project ID
      if (route.contains('projectDetails')) {
        Navigator.pushNamed(context, route, arguments: projectId);
      } else {
        Navigator.pushNamed(context, route);
      }
    } else {
      _showInfoSnackBar(context, 'لا يمكن الانتقال إلى صفحة التفاصيل لهذا الإشعار.');
    }
  }

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

  void _showInfoSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.infoColor, // Use info color for info messages
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null || _currentUserRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: AppConstants.primaryColor,
          elevation: 4,
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notifications')
              .where('userId', isEqualTo: _currentUser!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ في تحميل الإشعارات: ${snapshot.error}',
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
                    Icon(Icons.notifications_off, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Text(
                      'لا توجد إشعارات حاليًا.',
                      style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(AppConstants.padding / 2),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                // Safely access data, using .data() which returns Map<String, dynamic>?
                // and providing default empty map if null
                final Map<String, dynamic> data = notification.data() as Map<String, dynamic>? ?? {}; // NEW: Safe cast and null-check

                final bool isRead = data['isRead'] as bool? ?? false;
                final String title = data['title'] as String? ?? 'إشعار جديد';
                final String body = data['body'] as String? ?? 'لا توجد تفاصيل.';
                final Timestamp timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now(); // NEW: Safe null-check for timestamp
                final String projectId = data['projectId'] as String? ?? '';
                final String phaseDocId = data['phaseDocId'] as String? ?? '';
                final String notificationType = data['type'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  color: isRead ? AppConstants.cardColor : AppConstants.accentColor.withOpacity(0.08), // Light highlight for unread
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: isRead ? AppConstants.secondaryTextColor.withOpacity(0.1) : AppConstants.primaryColor.withOpacity(0.2),
                      child: Icon(
                        isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: isRead ? AppConstants.secondaryTextColor : AppConstants.primaryColor,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: AppConstants.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            color: isRead ? AppConstants.secondaryTextColor : AppConstants.textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppConstants.secondaryTextColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _markAsRead(notification.id);
                      _handleNotificationTap(projectId, phaseDocId, notificationType); // Pass phaseDocId and type
                    },
                    trailing: PopupMenuButton<String>(
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
                            child: Text('وضع علامة "مقروء"'),
                          ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('حذف', style: TextStyle(color: AppConstants.deleteColor)),
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