import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'engineer_home.dart';

class EmployeesTab extends StatelessWidget {
  final String engineerId;
  const EmployeesTab({Key? key, required this.engineerId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('engineerId', isEqualTo: engineerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('فشل تحميل الموظفين'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد موظفون'));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final employeeName = data['name'] ?? 'موظف';
            final employeeEmail = data['email'] ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
              child: ListTile(
                title: Text(employeeName, style: const TextStyle(color: AppConstants.textPrimary)),
                subtitle: Text(employeeEmail, style: const TextStyle(color: AppConstants.textSecondary)),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'check_in') _recordAttendance(context, docs[index].id, 'check_in');
                    if (value == 'check_out') _recordAttendance(context, docs[index].id, 'check_out');
                    if (value == 'assign') _showAssignDialog(context);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'check_in', child: Text('تسجيل حضور')),
                    PopupMenuItem(value: 'check_out', child: Text('تسجيل انصراف')),
                    PopupMenuItem(value: 'assign', child: Text('إضافة للمراحل/الاختبارات')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _recordAttendance(BuildContext context, String employeeId, String type, {String? projectId}) async {
    try {
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': employeeId,
        'type': type,
        'timestamp': Timestamp.now(),
        'recordedBy': engineerId,
        if (projectId != null) 'projectId': projectId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(type == 'check_in' ? 'تم تسجيل الحضور' : 'تم تسجيل الانصراف'),
          backgroundColor: AppConstants.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ'), backgroundColor: AppConstants.errorColor),
      );
    }
  }

  void _showAssignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعيين الموظف'),
          content: const Text('هذه وظيفة تجريبية لإضافة الموظف للمراحل أو الاختبارات.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }
}
