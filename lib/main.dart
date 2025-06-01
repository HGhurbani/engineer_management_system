// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engineer_management_system/pages/admin/admin_attendance_page.dart';
import 'package:engineer_management_system/pages/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:engineer_management_system/pages/auth/login_page.dart';
import 'package:engineer_management_system/pages/admin/admin_dashboard.dart';
import 'package:engineer_management_system/pages/engineer/engineer_home.dart';
import 'package:engineer_management_system/pages/client/client_home.dart';
import 'package:engineer_management_system/pages/admin/admin_engineers_page.dart';
import 'package:engineer_management_system/pages/admin/admin_clients_page.dart';
import 'package:engineer_management_system/pages/admin/admin_employees_page.dart';
import 'package:engineer_management_system/pages/admin/admin_projects_page.dart';
import 'package:engineer_management_system/pages/admin/admin_project_details_page.dart';
import 'package:engineer_management_system/pages/engineer/project_details_page.dart';
import 'package:engineer_management_system/pages/admin/admin_settings_page.dart';
// Import for the new Part Request page
import 'package:engineer_management_system/pages/engineer/request_part_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) { // تحقق مما إذا كانت قائمة تطبيقات Firebase فارغة
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // إذا لم تكن فارغة، افترض أن التطبيق الافتراضي موجود بالفعل
    // يمكنك إضافة تسجيل (log) هنا إذا أردت للتأكد
    print('Firebase app [DEFAULT] already initialized.');
  }

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)), // استخدمنا لون مشابه للـ primaryColor الجديد
        useMaterial3: true,
        fontFamily: 'Tajawal', // <--- هنا يتم تعيين الخط الافتراضي للتطبيق
        appBarTheme: const AppBarTheme(
          color: Color(0xFF2563EB), // يمكنك استخدام AppConstants.primaryColor هنا إذا كانت معرفة
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // تطبيق الخط على عناوين AppBar أيضاً
        ),
        textTheme: const TextTheme( // يمكنك تخصيص أنماط النصوص المختلفة هنا إذا أردت
          bodyLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 16.0),
          bodyMedium: TextStyle(fontFamily: 'Tajawal', fontSize: 14.0),
          displayLarge: TextStyle(fontFamily: 'Tajawal', fontSize: 32.0, fontWeight: FontWeight.bold),
          // ... أضف المزيد من الأنماط حسب الحاجة
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)
            )
        ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w500)
            )
        ),
        // يمكنك أيضاً تخصيص الخط للـ FloatingActionButtonTheme, CardTheme, etc.
      ),
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
          final projectId = ModalRoute.of(context)!.settings.arguments as String;
          return AdminProjectDetailsPage(projectId: projectId);
        },
        '/projectDetails': (context) {
          final projectId = ModalRoute.of(context)!.settings.arguments as String;
          return ProjectDetailsPage(projectId: projectId);
        },
        '/admin/settings': (context) => const AdminSettingsPage(),
        '/admin/attendance': (context) => const AdminAttendancePage(),
        '/notifications': (context) => const NotificationsPage(),
        // New route for requesting parts
        '/engineer/request_part': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args != null && args.containsKey('engineerId') && args.containsKey('engineerName')) {
            return RequestPartPage(
              engineerId: args['engineerId'] as String,
              engineerName: args['engineerName'] as String,
            );
          }
          // Fallback or error handling if arguments are missing
          // You might want to redirect to login or show an error page
          print('Error: Missing arguments for /engineer/request_part route.');
          return const LoginPage(); // Or a dedicated error screen
        },
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
                return const LoginPage(); // Fallback for unknown role
              } else {
                // If user is authenticated but no document in 'users' collection,
                // might indicate an issue or a new user whose document creation failed.
                // For now, redirect to login. Consider more robust handling.
                print('User authenticated but no user document found in Firestore. UID: ${snapshot.data!.uid}');
                // Optionally sign out the user if their Firestore record is missing
                // FirebaseAuth.instance.signOut();
                return const LoginPage();
              }
            },
          );
        } else {
          return const LoginPage(); // No user logged in
        }
      },
    );
  }
}