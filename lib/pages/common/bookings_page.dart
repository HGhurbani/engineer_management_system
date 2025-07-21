import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../theme/app_constants.dart';
import '../../main.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _role;
  String? _uid;
  bool _loading = true;

  List<DocumentSnapshot> _users = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _uid = user.uid;
    final userDoc = await _firestore.collection('users').doc(_uid).get();
    _role = userDoc['role'];

    if (_role == 'admin') {
      final snapshot = await _firestore.collection('users').get();
      _users = snapshot.docs;
    } else if (_role == 'engineer') {
      final snapshot = await _firestore.collection('users').where('role', isEqualTo: 'client').get();
      _users = snapshot.docs;
    } else if (_role == 'client') {
      final snapshot = await _firestore.collection('users').where('role', isEqualTo: 'engineer').get();
      _users = snapshot.docs;
    }

    if (mounted) setState(() => _loading = false);
  }

  Stream<QuerySnapshot> _bookingsStream() {
    if (_role == 'admin') {
      return _firestore.collection('bookings').orderBy('date', descending: true).snapshots();
    } else if (_role == 'engineer') {
      return _firestore.collection('bookings').where('engineerId', isEqualTo: _uid).orderBy('date', descending: true).snapshots();
    } else {
      return _firestore.collection('bookings').where('clientId', isEqualTo: _uid).orderBy('date', descending: true).snapshots();
    }
  }

  Future<void> _addBooking() async {
    final titleController = TextEditingController();
    DateTime? selectedDate;
    String? selectedUserId;
    String? note;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة حجز'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'عنوان الحجز'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(selectedDate == null ? 'اختر التاريخ' : DateFormat('yyyy/MM/dd').format(selectedDate!)),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: now.subtract(const Duration(days: 0)),
                              lastDate: DateTime(now.year + 1),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('تحديد'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_role == 'admin' || _role == 'engineer' || _role == 'client')
                      DropdownButton<String>(
                        value: selectedUserId,
                        isExpanded: true,
                        hint: Text(_role == 'client' ? 'اختر المهندس' : 'اختر المستخدم'),
                        items: _users.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => selectedUserId = value),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 3,
                      onChanged: (v) => note = v,
                      decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || selectedDate == null) return;
                String status = 'confirmed';
                if (_role == 'client') status = 'pending';
                await _firestore.collection('bookings').add({
                  'title': titleController.text,
                  'date': Timestamp.fromDate(selectedDate!),
                  'createdBy': _uid,
                  'createdByRole': _role,
                  'engineerId': _role == 'client' ? selectedUserId : (_role == 'engineer' ? _uid : selectedUserId),
                  'clientId': _role == 'engineer' ? selectedUserId : (_role == 'client' ? _uid : selectedUserId),
                  'status': status,
                  'note': note,
                  'createdAt': FieldValue.serverTimestamp(),
                }).then((doc) async {
                  if (_role == 'admin') {
                    if (selectedUserId != null) {
                      await sendNotification(
                        recipientUserId: selectedUserId!,
                        title: 'حجز جديد',
                        body: titleController.text,
                        type: 'booking_new',
                        senderName: 'المدير',
                      );
                    }
                  } else if (_role == 'engineer') {
                    final admins = await getAdminUids();
                    await sendNotificationsToMultiple(
                      recipientUserIds: admins,
                      title: 'حجز جديد من مهندس',
                      body: titleController.text,
                      type: 'booking_new',
                      senderName: 'مهندس',
                    );
                    if (selectedUserId != null) {
                      await sendNotification(
                        recipientUserId: selectedUserId!,
                        title: 'حجز جديد',
                        body: titleController.text,
                        type: 'booking_new',
                        senderName: 'مهندس',
                      );
                    }
                  } else if (_role == 'client') {
                    final admins = await getAdminUids();
                    await sendNotificationsToMultiple(
                      recipientUserIds: admins,
                      title: 'طلب حجز جديد',
                      body: titleController.text,
                      type: 'booking_request',
                      senderName: 'عميل',
                    );
                  }
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmBooking(Booking booking) async {
    await _firestore.collection('bookings').doc(booking.id).update({'status': 'confirmed'});
    if (booking.engineerId != null) {
      await sendNotification(
        recipientUserId: booking.engineerId!,
        title: 'تأكيد الحجز',
        body: booking.title,
        type: 'booking_confirmed',
      );
    }
    if (booking.clientId != null) {
      await sendNotification(
        recipientUserId: booking.clientId!,
        title: 'تأكيد الحجز',
        body: booking.title,
        type: 'booking_confirmed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحجوزات'),
        backgroundColor: AppConstants.primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBooking,
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _bookingsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookings = snapshot.data!.docs.map((e) => Booking.fromDoc(e)).toList();
          if (bookings.isEmpty) {
            return const Center(child: Text('لا توجد حجوزات'));
          }
          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(b.title),
                  subtitle: Text(DateFormat('yyyy/MM/dd').format(b.date)),
                  trailing: _role == 'admin' && b.status == 'pending'
                      ? TextButton(
                          onPressed: () => _confirmBooking(b),
                          child: const Text('تأكيد'),
                        )
                      : Text(b.status == 'pending' ? 'بانتظار الموافقة' : 'مؤكد'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
