import 'package:engineer_management_system/pages/admin/admin_clients_page.dart';
import 'package:engineer_management_system/pages/admin/admin_employees_page.dart';
import 'package:engineer_management_system/pages/admin/admin_engineers_page.dart';
import 'package:engineer_management_system/pages/admin/admin_project_details_page.dart';
import 'package:engineer_management_system/pages/admin/admin_projects_page.dart';
import 'package:engineer_management_system/pages/engineer/edit_phase_page.dart';
import 'package:engineer_management_system/pages/engineer/project_details_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// استورد صفحاتك:
import 'pages/auth/login_page.dart';
import 'pages/admin/admin_dashboard.dart';
import 'pages/engineer/engineer_home.dart';
import 'pages/client/client_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electro App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/projectDetails': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String;
          return ProjectDetailsPage(projectId: args);
        },
        '/admin': (context) => const AdminDashboard(),
        '/admin/engineers': (context) => const AdminEngineersPage(),
        '/admin/clients': (context) => const AdminClientsPage(),
        '/admin/employees': (context) => const AdminEmployeesPage(),
        '/admin/projectDetails': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String;
          return AdminProjectDetailsPage(projectId: args);
        },
        '/admin/projects': (context) => const AdminProjectsPage(),
        '/engineer': (context) => const EngineerHome(),
        '/client': (context) => const ClientHome(),
        '/editPhase': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return EditPhasePage(
            projectId: args['projectId'],
            phaseId: args['phaseId'],
            phaseData: args['phaseData'],
          );
        }
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // المستخدم غير مسجل دخول
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // المستخدم مسجل دخول، نتحقق من نوعه
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final role = userSnapshot.data!['role'];

            if (role == 'admin') {
              return const AdminDashboard();
            } else if (role == 'engineer') {
              return const EngineerHome();
            } else if (role == 'client') {
              return const ClientHome();
            } else {
              return const Scaffold(body: Center(child: Text('نوع المستخدم غير معروف')));
            }
          },
        );
      },
    );
  }
}
