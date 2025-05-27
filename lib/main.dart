// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engineer_management_system/pages/admin/admin_attendance_page.dart';
import 'package:engineer_management_system/pages/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

import 'package:engineer_management_system/pages/auth/login_page.dart'; // Import your login page
import 'package:engineer_management_system/pages/admin/admin_dashboard.dart'; // Import admin dashboard
import 'package:engineer_management_system/pages/engineer/engineer_home.dart'; // Import engineer home
import 'package:engineer_management_system/pages/client/client_home.dart'; // Import client home
import 'package:engineer_management_system/pages/admin/admin_engineers_page.dart'; // Import admin engineers page
import 'package:engineer_management_system/pages/admin/admin_clients_page.dart'; // Import admin clients page
import 'package:engineer_management_system/pages/admin/admin_employees_page.dart'; // Import admin employees page
import 'package:engineer_management_system/pages/admin/admin_projects_page.dart'; // Import admin projects page
import 'package:engineer_management_system/pages/admin/admin_project_details_page.dart'; // Import admin project details page
import 'package:engineer_management_system/pages/engineer/project_details_page.dart'; // Import engineer project details page
import 'package:engineer_management_system/pages/admin/admin_settings_page.dart'; // NEW: Import AdminSettingsPage


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engineer Management System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0056D8)), // Primary Color
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          color: Color(0xFF0056D8), // Set AppBar color consistently
          iconTheme: IconThemeData(color: Colors.white), // Set icon color
        ),
      ),
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => const AuthWrapper(), // Handle redirection based on auth state
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
        '/projectDetails': (context) { // This route is used by engineers
          final projectId = ModalRoute.of(context)!.settings.arguments as String;
          return ProjectDetailsPage(projectId: projectId);
        },
        '/admin/settings': (context) => const AdminSettingsPage(), // NEW: Add settings route
        '/admin/attendance': (context) => const AdminAttendancePage(),
        '/notifications': (context) => const NotificationsPage(),
      },
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}

// A wrapper widget to handle initial authentication state and redirect
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
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData) {
          // User is logged in, fetch role and redirect
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              } else if (userDocSnapshot.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text('Error fetching user data'),
                  ),
                );
              } else if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final role = userDocSnapshot.data!['role'];
                if (role == 'admin') {
                  return const AdminDashboard();
                } else if (role == 'engineer') {
                  return const EngineerHome();
                } else if (role == 'client') {
                  return const ClientHome();
                } else {
                  // Unknown role, redirect to login
                  return const LoginPage();
                }
              } else {
                // User document not found, redirect to login
                return const LoginPage();
              }
            },
          );
        } else {
          // No user is logged in, show login page
          return const LoginPage();
        }
      },
    );
  }
}

// Remove MyHomePage and _MyHomePageState as they are part of the default Flutter demo.
// Your application's entry point is now managed by AuthWrapper.