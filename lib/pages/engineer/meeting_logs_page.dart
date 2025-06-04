import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'engineer_home.dart';

class MeetingLogsPage extends StatefulWidget {
  final String engineerId;
  const MeetingLogsPage({Key? key, required this.engineerId}) : super(key: key);

  @override
  State<MeetingLogsPage> createState() => _MeetingLogsPageState();
}

class _MeetingLogsPageState extends State<MeetingLogsPage> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محاضر الاجتماعات', style: TextStyle(color: Colors.white)),
          backgroundColor: AppConstants.primaryColor,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('meeting_logs')
              .where('engineerId', isEqualTo: widget.engineerId)
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('فشل تحميل المحاضر'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد محاضر'));
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final title = data['title'] ?? '';
                final description = data['description'] ?? '';
                final type = data['type'] ?? '';
                final date = (data['date'] as Timestamp?)?.toDate();
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text('$description\n${date != null ? date.toString().split(' ')[0] : ''} - ${type == 'client' ? 'عميل' : 'موظفين'}'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddLogDialog,
          backgroundColor: AppConstants.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddLogDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    String? type;

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة محضر'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'التفاصيل'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'client', child: Text('مع العميل')),
                    DropdownMenuItem(value: 'employee', child: Text('مع الموظفين')),
                  ],
                  onChanged: (val) => type = val,
                  decoration: const InputDecoration(labelText: 'النوع'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty || type == null) return;
                  await FirebaseFirestore.instance.collection('meeting_logs').add({
                    'engineerId': widget.engineerId,
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'type': type,
                    'date': Timestamp.now(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                child: const Text('إضافة', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}
