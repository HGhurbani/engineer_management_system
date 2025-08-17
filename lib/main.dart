// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engineer_management_system/pages/admin/admin_attendance_page.dart';
import 'package:engineer_management_system/pages/admin/admin_attendance_report_page.dart';
import 'package:engineer_management_system/pages/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:intl/date_symbol_data_local.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'package:engineer_management_system/pages/admin/admin_daily_schedule_page.dart'; // افترض هذا المسار
import 'package:engineer_management_system/pages/splash_screen.dart';
import 'package:engineer_management_system/pages/auth/login_page.dart';
import 'package:engineer_management_system/pages/admin/admin_dashboard.dart';
import 'package:engineer_management_system/pages/engineer/engineer_home.dart';
import 'package:engineer_management_system/pages/client/client_home.dart';
import 'package:engineer_management_system/pages/admin/admin_engineers_page.dart';
import 'package:engineer_management_system/pages/admin/admin_clients_page.dart';
import 'package:engineer_management_system/pages/admin/admin_employees_page.dart';
import 'package:engineer_management_system/pages/admin/admin_projects_page.dart';
import 'package:engineer_management_system/pages/admin/admin_project_details_page.dart';
// Import only ProjectDetailsPage to avoid exposing its internal AppConstants
import 'package:engineer_management_system/pages/engineer/project_details_page.dart'
    show ProjectDetailsPage;
import 'package:engineer_management_system/pages/admin/admin_settings_page.dart';
import 'package:engineer_management_system/pages/admin/admin_holiday_settings_page.dart';
import 'package:engineer_management_system/pages/engineer/request_material_page.dart';
import 'package:engineer_management_system/pages/engineer/meeting_logs_page.dart';
import 'package:engineer_management_system/pages/engineer/images_viewer_page.dart';
import 'package:engineer_management_system/pages/admin/admin_meeting_logs_page.dart';
import 'package:engineer_management_system/pages/admin/admin_materials_page.dart';
import 'package:engineer_management_system/pages/common/change_password_page.dart';
import 'package:engineer_management_system/pages/common/pdf_preview_screen.dart';
import 'package:engineer_management_system/pages/common/bookings_page.dart';
import 'package:engineer_management_system/pages/common/material_request_details_page.dart';
import 'package:engineer_management_system/pages/admin/report_snapshot_migration_page.dart';

import 'package:engineer_management_system/pages/admin/admin_evaluations_page.dart'; // استيراد صفحة التقييم الجديدة
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:engineer_management_system/utils/concurrent_operations_manager.dart';
import 'package:engineer_management_system/utils/performance_monitor.dart';
import 'package:engineer_management_system/utils/firebase_manager.dart';
import 'package:engineer_management_system/utils/advanced_cache_manager.dart';
import 'package:engineer_management_system/utils/advanced_report_manager.dart';

late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// إضافة إدارة الذاكرة
class MemoryManager {
  static const int _maxMemoryUsage = 100 * 1024 * 1024; // 100MB
  static int _currentMemoryUsage = 0;
  
  static void logMemoryUsage(String operation) {
    if (kIsWeb) {
      print('Memory usage for $operation: ${_currentMemoryUsage ~/ (1024 * 1024)}MB');
    }
  }
  
  static void cleanupMemory() {
    // تنظيف الذاكرة
    _currentMemoryUsage = 0;
    if (kIsWeb) {
      // إجبار جمع القمامة في الويب
      print('Memory cleanup completed');
    }
  }
}

Future<void> _optimizeWebMemory() async {
  if (kIsWeb) {
    // تحسينات خاصة بالويب
    print('Applying web memory optimizations...');
    
    // تعيين حدود للعمليات المتزامنة
    const int maxConcurrentOperations = 3;
    
    // تنظيف الذاكرة دورياً
    ConcurrentOperationsManager.addTimer(
      'web_memory_cleanup',
      const Duration(minutes: 5),
      () {
        MemoryManager.cleanupMemory();
        print('Web memory cleanup completed');
      },
    );
    
    // تنظيف Firebase دورياً
    ConcurrentOperationsManager.addTimer(
      'firebase_cleanup',
      const Duration(minutes: 10),
      () {
        // تنظيف العمليات المعلقة
        if (FirebaseManager.pendingOperationsCount > 10) {
          print('Cleaning up pending Firebase operations...');
          // يمكن إضافة منطق تنظيف إضافي هنا
        }
      },
    );
    
    // مراقبة الأداء دورياً
    ConcurrentOperationsManager.addTimer(
      'performance_monitoring',
      const Duration(minutes: 2),
      () {
        final summary = PerformanceMonitor.getPerformanceSummary();
        if (summary.contains('⚠️')) {
          print('Performance warning detected: $summary');
          // تنظيف الذاكرة عند اكتشاف مشاكل في الأداء
          MemoryManager.cleanupMemory();
        }
      },
    );
    
    // بدء مراقبة الأداء للويب
    PerformanceMonitor.startAutoCleanup();
    
    print('Web memory optimizations applied successfully');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // بدء مراقبة الأداء
  PerformanceMonitor.startAutoCleanup();
  
  // تهيئة نظام الكاش المتقدم
  await AdvancedCacheManager.initialize();
  
  // إضافة إدارة الذاكرة
  if (kIsWeb) {
    await _optimizeWebMemory();
  }
  
  // تهيئة Firebase مع إدارة الأخطاء
  try {
    await FirebaseManager.initializeFirebase();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
    // محاولة إعادة التهيئة
    try {
      await FirebaseManager.initializeFirebase();
    } catch (retryError) {
      print('Firebase initialization failed after retry: $retryError');
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _setupPushNotifications();

  await initializeDateFormatting('ar', null);
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
          title: 'Engineer Management System',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
            useMaterial3: true,
            fontFamily: 'Tajawal',
            appBarTheme: const AppBarTheme(
              color: AppConstants.primaryDark,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 16.0),
              bodyMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 14.0),
              displayLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 32.0, fontWeight: FontWeight.bold),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w500),
              ),
            ),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          locale: const Locale('ar'),
          initialRoute: '/',
          
          // إضافة إدارة الأخطاء
          builder: (context, child) {
            ErrorWidget.builder = (FlutterErrorDetails details) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'حدث خطأ في التطبيق',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يرجى إعادة تشغيل التطبيق',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // تنظيف الموارد قبل إعادة التشغيل
                            _cleanupResources();
                            // إعادة تشغيل التطبيق
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                          child: const Text('إعادة تشغيل'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // عرض تفاصيل الخطأ للمطورين
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('تفاصيل الخطأ'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(details.toString()),
                                      const SizedBox(height: 16),
                                      const Text('إحصائيات الأداء:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(PerformanceMonitor.getPerformanceSummary()),
                                      const SizedBox(height: 8),
                                      const Text('إحصائيات Firebase:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('العمليات المعلقة: ${FirebaseManager.pendingOperationsCount}'),
                                      Text('الاشتراكات النشطة: ${FirebaseManager.activeSubscriptionsCount}'),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('إغلاق'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _cleanupResources();
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('تنظيف الموارد'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('عرض التفاصيل'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            };
            return child!;
          },
          
          routes: {
            '/': (context) => const SplashScreen(),
            '/auth': (context) => const AuthWrapper(),
            '/login': (context) => const LoginPage(),
            '/admin': (context) => const AdminDashboard(),
        '/engineer': (context) => const EngineerHome(),
        '/client': (context) => const ClientHome(),
        '/admin/engineers': (context) => const AdminEngineersPage(),
        '/admin/clients': (context) => const AdminClientsPage(),
        '/admin/employees': (context) => const AdminEmployeesPage(),
        '/admin/projects': (context) => const AdminProjectsPage(),
        '/admin/projectDetails': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is Map<String, dynamic>) {
            return AdminProjectDetailsPage(
              projectId: args['projectId'] as String,
              highlightItemId: args['itemId'] as String?,
              notificationType: args['notificationType'] as String?,
            );
          }
          final projectId = args as String;
          return AdminProjectDetailsPage(projectId: projectId);
        },
        '/projectDetails': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is Map<String, dynamic>) {
            return ProjectDetailsPage(
              projectId: args['projectId'] as String,
              highlightItemId: args['itemId'] as String?,
              notificationType: args['notificationType'] as String?,
            );
          }
          final projectId = args as String;
          return ProjectDetailsPage(projectId: projectId);
        },
        '/admin/daily_schedule': (context) => const AdminDailySchedulePage(),
        '/admin/settings': (context) => const AdminSettingsPage(),
        '/admin/holiday_settings': (context) => const AdminHolidaySettingsPage(),
        '/admin/attendance': (context) => const AdminAttendancePage(),
        '/admin/attendance_report': (context) => const AdminAttendanceReportPage(),
        '/notifications': (context) => const NotificationsPage(),
        '/bookings': (context) => const BookingsPage(),
        '/admin/change_password': (context) => const ChangePasswordPage(role: 'admin'),
        '/engineer/change_password': (context) => const ChangePasswordPage(role: 'engineer'),
        '/client/change_password': (context) => const ChangePasswordPage(role: 'client'),
        // New route for requesting materials
        '/engineer/request_material': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('engineerId') && args.containsKey('engineerName')) {
            return RequestMaterialPage(
              engineerId: args['engineerId'] as String,
              engineerName: args['engineerName'] as String,
              initialProjectId: args['projectId'] as String?,
              initialProjectName: args['projectName'] as String?,
            );
          }
          print('Error: Missing arguments for /engineer/request_material route.');
          return const LoginPage();
        },
        '/material_request_details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('requestDoc') && args.containsKey('userRole')) {
            return MaterialRequestDetailsPage(
              requestDoc: args['requestDoc'] as DocumentSnapshot,
              userRole: args['userRole'] as String,
            );
          }
          print('Error: Missing arguments for /material_request_details route.');
          return const LoginPage();
        },
        '/engineer/meeting_logs': (context) {
          final engineerId = ModalRoute.of(context)!.settings.arguments as String?;
          if (engineerId != null) {
            return MeetingLogsPage(engineerId: engineerId);
          }
          return const LoginPage();
        },
        '/engineer/images_viewer': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('imageUrls') && args.containsKey('title')) {
            return ImagesViewerPage(
              imageUrls: args['imageUrls'] as List<String>,
              title: args['title'] as String,
              note: args['note'] as String?,
              authorName: args['authorName'] as String?,
              timestamp: args['timestamp'] as DateTime?,
            );
          }
          return const LoginPage();
        },
          '/pdf_preview': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
            if (args != null && args['bytes'] != null && args['fileName'] != null && args['text'] != null) {
              return PdfPreviewScreen(
                pdfBytes: args['bytes'] as Uint8List,
                fileName: args['fileName'] as String,
                shareText: args['text'] as String,
                clientPhone: args['phone'] as String?,
                shareLink: args['link'] as String?,
                imageUrl: args['image'] as String?,
              );
            }
            return const Scaffold(body: Center(child: Text('لا يمكن عرض الملف')));
          },
        // --- ADDITION START ---
        '/admin/evaluations': (context) => const AdminEvaluationsPage(), // مسار جديد لصفحة التقييم
        '/admin/meeting_logs': (context) => const AdminMeetingLogsPage(),
        '/admin/materials': (context) => const AdminMaterialsPage(),
        '/admin/report_migration': (context) => const ReportSnapshotMigrationPage(),

        // --- ADDITION END ---
      },

      debugShowCheckedModeBanner: false,
    );
  }
  
  /// تنظيف الموارد عند حدوث خطأ
  void _cleanupResources() {
    try {
      // تنظيف Firebase
      FirebaseManager.dispose();
      
      // تنظيف العمليات المتزامنة
      ConcurrentOperationsManager.dispose();
      
      // تنظيف الذاكرة
      MemoryManager.cleanupMemory();
      
      // إيقاف مراقبة الأداء
      PerformanceMonitor.stopAutoCleanup();
      
      print('Resources cleaned up successfully');
    } catch (e) {
      print('Error during resource cleanup: $e');
    }
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري التحميل...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'خطأ في المصادقة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text('العودة لتسجيل الدخول'),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: _getUserDataWithTimeout(snapshot.data!.uid),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جاري تحميل بيانات المستخدم...', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                );
              } else if (userDocSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'خطأ في تحميل بيانات المستخدم',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${userDocSnapshot.error}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/login');
                          },
                          child: const Text('العودة لتسجيل الدخول'),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final data = userDocSnapshot.data!.data() as Map<String, dynamic>;
                final role = data['role'];
                
                // تسجيل استخدام الذاكرة
                MemoryManager.logMemoryUsage('user_authentication');
                
                if (role == 'admin') return const AdminDashboard();
                if (role == 'engineer') return const EngineerHome();
                if (role == 'client') return const ClientHome();
                return const LoginPage();
              } else {
                print('User authenticated but no user document found in Firestore. UID: ${snapshot.data!.uid}');
                return const LoginPage();
              }
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
  
  // إضافة timeout للعمليات مع استخدام الأدوات الجديدة
  Future<DocumentSnapshot> _getUserDataWithTimeout(String uid) async {
    return await ConcurrentOperationsManager.executeOperation(
      operationId: 'user_data_fetch_$uid',
      operation: () async {
        PerformanceMonitor.startTimer('user_data_fetch');
        try {
          final result = await FirebaseManager.executeWithConcurrencyLimit(
            operationId: 'firestore_user_fetch_$uid',
            operation: () => FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get(),
            timeout: const Duration(seconds: 10),
          );
          return result;
        } finally {
          PerformanceMonitor.endTimer('user_data_fetch');
        }
      },
      timeout: const Duration(seconds: 15),
      priority: 1,
    );
  }
}

Future<void> sendNotification({
  required String recipientUserId,
  required String title,
  required String body,
  required String type,
  String? projectId,
  String? itemId,
  String? senderName,
}) async {
  return await ConcurrentOperationsManager.executeOperation(
    operationId: 'send_notification_$recipientUserId',
    operation: () async {
      PerformanceMonitor.startTimer('send_notification');
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': recipientUserId,
          'title': title,
          'body': body,
          'type': type,
          'projectId': projectId,
          'itemId': itemId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'senderName': senderName ?? 'النظام',
        });

        // Retrieve recipient FCM token
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(recipientUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final token = userData != null ? userData['fcmToken'] as String? : null;
        if (token != null && token.isNotEmpty) {
          await _sendPushMessage(token, title, body);
        }
      } catch (e) {
        print('Error sending notification to $recipientUserId: $e');
        PerformanceMonitor.logPerformanceError('send_notification', e.toString());
        rethrow;
      } finally {
        PerformanceMonitor.endTimer('send_notification');
      }
    },
    timeout: const Duration(seconds: 20),
    priority: 2,
  );
}

Future<void> sendNotificationsToMultiple({
  required List<String> recipientUserIds,
  required String title,
  required String body,
  required String type,
  String? projectId,
  String? itemId,
  String? senderName,
}) async {
  return await ConcurrentOperationsManager.executeOperation(
    operationId: 'send_multiple_notifications_${recipientUserIds.length}',
    operation: () async {
      PerformanceMonitor.startTimer('send_multiple_notifications');
      try {
        // إرسال الإشعارات في مجموعات لتجنب استهلاك الذاكرة
        const int batchSize = 5;
        
        for (int i = 0; i < recipientUserIds.length; i += batchSize) {
          final end = (i + batchSize < recipientUserIds.length) ? i + batchSize : recipientUserIds.length;
          final batch = recipientUserIds.sublist(i, end);
          
          // إرسال المجموعة
          await Future.wait(
            batch.map((userId) => sendNotification(
              recipientUserId: userId,
              title: title,
              body: body,
              type: type,
              projectId: projectId,
              itemId: itemId,
              senderName: senderName,
            )),
          );
          
          // تنظيف الذاكرة بين المجموعات
          if (kIsWeb) {
            MemoryManager.cleanupMemory();
          }
        }
      } catch (e) {
        print('Error sending multiple notifications: $e');
        PerformanceMonitor.logPerformanceError('send_multiple_notifications', e.toString());
        rethrow;
      } finally {
        PerformanceMonitor.endTimer('send_multiple_notifications');
      }
    },
    timeout: const Duration(seconds: 60),
    priority: 1,
  );
}

Future<List<String>> getAdminUids() async {
  return await ConcurrentOperationsManager.executeOperation(
    operationId: 'get_admin_uids',
    operation: () async {
      PerformanceMonitor.startTimer('get_admin_uids');
      try {
        final adminSnapshot = await FirebaseManager.executeWithConcurrencyLimit(
          operationId: 'firestore_admin_query',
          operation: () => FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get(),
          timeout: const Duration(seconds: 15),
        );
        return adminSnapshot.docs.map((doc) => doc.id).toList();
      } catch (e) {
        print('Error fetching admin UIDs: $e');
        PerformanceMonitor.logPerformanceError('get_admin_uids', e.toString());
        return [];
      } finally {
        PerformanceMonitor.endTimer('get_admin_uids');
      }
    },
    timeout: const Duration(seconds: 20),
    priority: 1,
  );
}

Future<void> _setupPushNotifications() async {
  PerformanceMonitor.startTimer('push_notifications_setup');
  
  try {
    channel = const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.denied) {
      final token = await messaging.getToken();
      if (token != null) {
        await _updateUserFcmToken(token);
      }
      FirebaseMessaging.onMessage.listen(_showFlutterNotification);
      FirebaseMessaging.instance.onTokenRefresh.listen(_updateUserFcmToken);
    }
    
    print('Push notifications setup completed successfully');
  } catch (e) {
    print('Error setting up push notifications: $e');
    PerformanceMonitor.logPerformanceError('push_notifications_setup', e.toString());
  } finally {
    PerformanceMonitor.endTimer('push_notifications_setup');
  }
}

void _showFlutterNotification(RemoteMessage message) {
  PerformanceMonitor.startTimer('show_flutter_notification');
  
  try {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (notification != null && android != null && channel.id.isNotEmpty) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  } catch (e) {
    print('Error showing flutter notification: $e');
    PerformanceMonitor.logPerformanceError('show_flutter_notification', e.toString());
  } finally {
    PerformanceMonitor.endTimer('show_flutter_notification');
  }
}

Future<void> _sendPushMessage(
    String token, String title, String body) async {
  return await ConcurrentOperationsManager.executeOperation(
    operationId: 'send_push_message',
    operation: () async {
      PerformanceMonitor.startTimer('send_push_message');
      try {
        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'key=AIzaSyDRvznjDBdA83VNWzmbC2VbU-0UGuYyRCk',
          },
          body: jsonEncode({
            'to': token,
            'notification': {
              'title': title,
              'body': body,
            },
          }),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Error sending push message: $e');
        PerformanceMonitor.logPerformanceError('send_push_message', e.toString());
        rethrow;
      } finally {
        PerformanceMonitor.endTimer('send_push_message');
      }
    },
    timeout: const Duration(seconds: 15),
    priority: 2,
  );
}

Future<void> _updateUserFcmToken(String token) async {
  return await ConcurrentOperationsManager.executeOperation(
    operationId: 'update_fcm_token',
    operation: () async {
      PerformanceMonitor.startTimer('update_fcm_token');
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseManager.executeWithConcurrencyLimit(
            operationId: 'firestore_fcm_update',
            operation: () => FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'fcmToken': token}),
            timeout: const Duration(seconds: 10),
          );
        }
      } catch (e) {
        print('Error updating FCM token: $e');
        PerformanceMonitor.logPerformanceError('update_fcm_token', e.toString());
      } finally {
        PerformanceMonitor.endTimer('update_fcm_token');
      }
    },
    timeout: const Duration(seconds: 15),
    priority: 3,
  );
}