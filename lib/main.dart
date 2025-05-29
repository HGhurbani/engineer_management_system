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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
                return const LoginPage(); // User document not found
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