// lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:ui' as ui;


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

  // --- MODIFICATION START: _handleNotificationTap ---
  // lib/pages/notifications_page.dart
// ... (الكود السابق للدالة)

  void _handleNotificationTap(String? projectId, String? itemId, String notificationType) {
    if (!mounted) return;
    String route = '';

    // Determine base route by role
    if (_currentUserRole == 'admin') {
      route = '/admin'; // Base for admin
    } else if (_currentUserRole == 'engineer') {
      route = '/engineer'; // Base for engineer
    } else if (_currentUserRole == 'client') {
      route = '/client'; // Client home, already shows project details.
      // For client, direct navigation to project is usually sufficient.
      if (projectId != null && projectId.isNotEmpty) {
        // ClientHome will show the project, no specific itemId needed for deep link here usually
      } else if (notificationType.startsWith('part_request_')) {
        // Client doesn't typically see part requests directly
        _showFeedbackSnackBar(context, 'تفاصيل هذا الإشعار تعرض ضمن تحديثات المشروع.', isError: false, isInfo: true);
        return;
      }
      Navigator.pushNamed(context, route);
      return;
    } else {
      _showFeedbackSnackBar(context, 'لا يمكن تحديد وجهة الانتقال.', isError: true);
      return;
    }

    // Specific routing based on notification type
    switch (notificationType) {
      case 'attendance_check_in':
      case 'attendance_check_out':
        if (_currentUserRole == 'admin') {
          Navigator.pushNamed(context, '/admin/attendance');
        }
        break;

      case 'project_assignment':
        if (_currentUserRole == 'engineer' && projectId != null && projectId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/projectDetails',
            arguments: {
              'projectId': projectId,
              'itemId': itemId,
              'notificationType': notificationType,
            },
          );
        } else if (_currentUserRole == 'client') {
          // Client does not get project assignment notifications directly
          // or they are handled by a general client home page, no deep link for client
          Navigator.pushNamed(context, route); // Go to client home
        }
        break;

    // Phase, Sub-phase, Test, and Entry updates by Admin or Engineer
      case 'phase_update_by_admin':
      case 'subphase_update_by_admin':
      case 'test_update_by_admin':
      case 'project_entry_admin':
      // حالات التراجع عن الاكتمال بواسطة المسؤول
      case 'phase_reverted_by_admin':
      case 'subphase_reverted_by_admin':
      case 'test_reverted_by_admin':
      case 'project_entry_engineer': // المهندس أضاف إدخال
        if ((_currentUserRole == 'admin' || _currentUserRole == 'engineer') && projectId != null && projectId.isNotEmpty) {
          String detailRoute = _currentUserRole == 'admin' ? '/admin/projectDetails' : '/projectDetails';
          Navigator.pushNamed(
            context,
            detailRoute,
            arguments: {
              'projectId': projectId,
              'itemId': itemId,
              'notificationType': notificationType,
            },
          );
        }
        break;

    // Client notifications for completions and Admin entries
      case 'phase_completed_for_client':
      case 'subphase_completed_for_client':
      case 'test_completed_for_client':
      case 'project_entry_admin_to_client': // المسؤول أضاف إدخال للعميل
      case 'project_entry_engineer_to_client': // المهندس أضاف إدخال للعميل
      // حالات التراجع عن الاكتمال التي تظهر للعميل
      case 'phase_reverted_for_client':
      case 'subphase_reverted_for_client':
      case 'test_reverted_for_client':
        if (_currentUserRole == 'client' && projectId != null && projectId.isNotEmpty) {
          // ClientHome is already the destination, it will show the project.
          // No specific deep link needed beyond the main client page.
          Navigator.pushNamed(context, route);
        }
        break;

      case 'part_request_new':
        if (_currentUserRole == 'admin') {
          // Admin navigates to projects page, where they can see part requests.
          Navigator.pushNamed(context, '/admin/projects'); // أو /admin/partRequests إذا كان هناك صفحة مخصصة
          _showFeedbackSnackBar(context, 'يرجى مراجعة طلبات المواد للمشروع ذو الصلة.', isError: false, isInfo: true);
        }
        break;

      case 'part_request_status_update': // (إذا كان لديك منطق لتحديث حالة طلب القطعة)
        if (_currentUserRole == 'engineer') {
          Navigator.pushNamed(context, '/engineer'); // المهندس يعود لصفحته الرئيسية حيث يمكنه رؤية طلبات المواد
          _showFeedbackSnackBar(context, 'تم تحديث حالة طلب المواد. يرجى مراجعة طلباتك.', isError: false, isInfo: true);
        }
        break;

      case 'engineer_evaluation': // تقييم المهندس
        if (_currentUserRole == 'engineer') {
          Navigator.pushNamed(context, '/engineer'); // المهندس لا يمتلك صفحة تقييم مفصلة (حسب الكود الحالي)
        } else if (_currentUserRole == 'admin') {
          // المسؤول يذهب لصفحة التقييم
          Navigator.pushNamed(context, '/admin/evaluations');
        }
        break;

      case 'new_daily_task':
        if (_currentUserRole == 'engineer') {
          // يمكن توجيه المهندس إلى صفحة جدوله اليومي مباشرة
          // إذا كان التبويب "جدولي اليومي" هو التبويب الافتراضي أو يمكن الوصول إليه بسهولة،
          // فقد يكون Navigator.pushNamed(context, '/engineer'); كافيًا.
          // أو يمكنك تمرير argument لتحديد التبويب المطلوب عند فتح EngineerHome
          Navigator.pushNamed(context, '/engineer');
          // يمكنك إضافة منطق لتحديد التبويب الخاص بالجدول اليومي هنا إذا لزم الأمر
          // أو عرض رسالة تعلم المهندس بالانتقال إلى جدوله.
          _showFeedbackSnackBar(context, 'تمت إضافة مهمة جديدة لجدولك اليومي. يرجى التحقق.', isError: false, isInfo: true);
        } else if (_currentUserRole == 'admin') {
          // إذا كان المسؤول هو من يتلقى هذا الإشعار (لسبب ما)، يمكن توجيهه لصفحة الجداول
          if (projectId != null && projectId.isNotEmpty) {
            // قد ترغب في فتح صفحة الجداول مع تحديد تاريخ معين أو مشروع معين
            Navigator.pushNamed(context, '/admin/daily_schedule');
          } else {
            Navigator.pushNamed(context, '/admin/daily_schedule');
          }
        }
        break;

      case 'daily_task_status_update_by_engineer':
        if (_currentUserRole == 'admin') {
          // توجيه المسؤول إلى صفحة الجداول اليومية، وربما تحديد المشروع أو المهندس
          // إذا كان itemId هو taskId, و projectId موجود
          if (projectId != null && projectId.isNotEmpty) {
            // يمكن تمرير projectId و itemId لفتح تفاصيل معينة إذا أردت
            Navigator.pushNamed(context, '/admin/daily_schedule'); // أو صفحة تفاصيل مشروع
            _showFeedbackSnackBar(context, 'قام مهندس بتحديث حالة مهمة يومية.', isError: false, isInfo: true);
          } else {
            Navigator.pushNamed(context, '/admin/daily_schedule');
          }
        }
        break;

      default:
      // إذا لم يكن هناك مسار محدد، قم بتوجيه المستخدم إلى صفحته الرئيسية
        if (_currentUserRole == 'admin') {
          Navigator.pushNamed(context, '/admin');
        } else if (_currentUserRole == 'engineer'){
          Navigator.pushNamed(context, '/engineer');
        } else if (_currentUserRole == 'client'){
          Navigator.pushNamed(context, '/client');
        } else {
          _showFeedbackSnackBar(context, 'نوع الإشعار غير معروف أو لا يمكن الانتقال إليه.', isError: true);
        }
    }
  }
  // --- MODIFICATION END: _handleNotificationTap ---

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

                // --- MODIFICATION START: Read projectId and itemId ---
                final String? projectId = data['projectId'] as String?;
                final String? itemId = data['itemId'] as String?; // Generic item ID
                // --- MODIFICATION END ---
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
                      // --- MODIFICATION START: Call updated _handleNotificationTap ---
                      _handleNotificationTap(projectId, itemId, notificationType);
                      // --- MODIFICATION END ---
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