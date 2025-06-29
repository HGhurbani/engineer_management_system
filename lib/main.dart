// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engineer_management_system/pages/admin/admin_attendance_page.dart';
import 'package:engineer_management_system/pages/admin/admin_attendance_report_page.dart';
import 'package:engineer_management_system/pages/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:intl/date_symbol_data_local.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'firebase_options.dart';
import 'package:engineer_management_system/pages/admin/admin_daily_schedule_page.dart'; // افترض هذا المسار
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
import 'package:engineer_management_system/pages/admin/admin_meeting_logs_page.dart';
import 'package:engineer_management_system/pages/common/change_password_page.dart';
import 'package:engineer_management_system/pages/common/pdf_preview_screen.dart';

// --- ADDITION START ---
import 'package:engineer_management_system/pages/admin/admin_evaluations_page.dart'; // استيراد صفحة التقييم الجديدة
// --- ADDITION END ---


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // if (Firebase.apps.isEmpty) {
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  // } else {
  //   print('Firebase app [DEFAULT] already initialized.');
  // }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


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
          routes: {
            '/': (context) => const AuthWrapper(),
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
        '/engineer/meeting_logs': (context) {
          final engineerId = ModalRoute.of(context)!.settings.arguments as String?;
          if (engineerId != null) {
            return MeetingLogsPage(engineerId: engineerId);
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
              );
            }
            return const Scaffold(body: Center(child: Text('لا يمكن عرض الملف')));
          },
        // --- ADDITION START ---
        '/admin/evaluations': (context) => const AdminEvaluationsPage(), // مسار جديد لصفحة التقييم
        '/admin/meeting_logs': (context) => const AdminMeetingLogsPage(),
        // --- ADDITION END ---
      },

      debugShowCheckedModeBanner: false,
    );
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              } else if (userDocSnapshot.hasError) {
                return const Scaffold(body: Center(child: Text('Error fetching user data')));
              } else if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final data = userDocSnapshot.data!.data() as Map<String, dynamic>;
                final role = data['role'];
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
  } catch (e) {
    print('Error sending notification to $recipientUserId: $e');
  }
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
  for (String userId in recipientUserIds) {
    await sendNotification(
      recipientUserId: userId,
      title: title,
      body: body,
      type: type,
      projectId: projectId,
      itemId: itemId,
      senderName: senderName,
    );
  }
}

Future<List<String>> getAdminUids() async {
  try {
    final adminSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    return adminSnapshot.docs.map((doc) => doc.id).toList();
  } catch (e) {
    print('Error fetching admin UIDs: $e');
    return [];
  }
}