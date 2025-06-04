import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class AdminMeetingLogsPage extends StatelessWidget {
  const AdminMeetingLogsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محاضر الاجتماعات', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF2563EB),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('meeting_logs')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
            }
            if (snapshot.hasError) return const Center(child: Text('حدث خطأ'));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد محاضر'));
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final title = data['title'] ?? '';
                final desc = data['description'] ?? '';
                final type = data['type'] ?? '';
                final date = (data['date'] as Timestamp?)?.toDate();
                final engineerId = data['engineerId'] ?? '';
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(
                      '$desc\n${date != null ? date.toString().split(' ')[0] : ''} - ${type == 'client' ? 'عميل' : 'موظفين'} - $engineerId',
                    ),
                    isThreeLine: true,
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
