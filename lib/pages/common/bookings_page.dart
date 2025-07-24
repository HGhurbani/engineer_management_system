import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as ui;
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../theme/app_constants.dart';
import '../../main.dart'; // Ensure main.dart is imported for sendNotification, getAdminUids

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
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: const Text(
              'إضافة حجز',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'عنوان الحجز',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppConstants.textSecondary, size: 20),
                          const SizedBox(width: AppConstants.paddingSmall),
                          Expanded(
                            child: Text(
                              selectedDate == null
                                  ? 'اختر التاريخ'
                                  : DateFormat('yyyy/MM/dd', 'ar').format(selectedDate!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: now,
                                firstDate: now,
                                lastDate: DateTime(now.year + 1),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: Theme.of(context).colorScheme.copyWith(
                                        primary: AppConstants.primaryColor, // Header background color
                                        onPrimary: Colors.white, // Header text color
                                        onSurface: AppConstants.textPrimary, // Body text color
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppConstants.primaryColor, // Button text color
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.edit_calendar, color: AppConstants.primaryColor),
                            label: const Text('تحديد', style: TextStyle(color: AppConstants.primaryColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (_role == 'admin' || _role == 'engineer' || _role == 'client')
                        DropdownButtonFormField<String>(
                          value: selectedUserId,
                          decoration: InputDecoration(
                            labelText: _role == 'client' ? 'اختر المهندس' : 'اختر المستخدم',
                            labelStyle: TextStyle(color: AppConstants.textSecondary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                              borderSide: const BorderSide(color: AppConstants.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                              borderSide: const BorderSide(color: AppConstants.primaryColor),
                            ),
                          ),
                          isExpanded: true,
                          items: _users.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(data['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedUserId = value),
                        ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      TextField(
                        maxLines: 3,
                        onChanged: (v) => note = v,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty || selectedDate == null) {
                    _showFeedbackSnackBar(context, 'الرجاء إدخال عنوان وتاريخ الحجز.', isError: true);
                    return;
                  }
                  String status = 'confirmed';
                  if (_role == 'client') status = 'pending';

                  try {
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
                    _showFeedbackSnackBar(context, 'تم إضافة الحجز بنجاح.', isError: false);
                  } catch (e) {
                    _showFeedbackSnackBar(context, 'فشل إضافة الحجز: $e', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge, vertical: AppConstants.paddingSmall),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmBooking(Booking booking) async {
    try {
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
      _showFeedbackSnackBar(context, 'تم تأكيد الحجز بنجاح.', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تأكيد الحجز: $e', isError: true);
    }
  }

  Future<void> _showEditBookingDialog(Booking booking) async {
    final titleController = TextEditingController(text: booking.title);
    DateTime? selectedDate = booking.date;
    String? selectedUserId = _role == 'client'
        ? booking.engineerId
        : (_role == 'engineer' ? booking.clientId : null);
    String? note = booking.note;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: const Text(
              'تعديل الحجز',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'عنوان الحجز',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppConstants.textSecondary, size: 20),
                          const SizedBox(width: AppConstants.paddingSmall),
                          Expanded(
                            child: Text(
                              DateFormat('yyyy/MM/dd', 'ar').format(selectedDate!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate!,
                                firstDate: now,
                                lastDate: DateTime(now.year + 1),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: Theme.of(context).colorScheme.copyWith(
                                        primary: AppConstants.primaryColor,
                                        onPrimary: Colors.white,
                                        onSurface: AppConstants.textPrimary,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.edit_calendar, color: AppConstants.primaryColor),
                            label: const Text('تحديد', style: TextStyle(color: AppConstants.primaryColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (_role == 'admin' || _role == 'engineer' || _role == 'client')
                        DropdownButtonFormField<String>(
                          value: selectedUserId,
                          decoration: InputDecoration(
                            labelText: _role == 'client' ? 'اختر المهندس' : 'اختر المستخدم',
                            labelStyle: TextStyle(color: AppConstants.textSecondary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                              borderSide: const BorderSide(color: AppConstants.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                              borderSide: const BorderSide(color: AppConstants.primaryColor),
                            ),
                          ),
                          isExpanded: true,
                          items: _users.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(data['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedUserId = value),
                        ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      TextField(
                        controller: TextEditingController(text: note)
                          ..selection = TextSelection.collapsed(offset: note?.length ?? 0),
                        maxLines: 3,
                        onChanged: (v) => note = v,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          labelStyle: TextStyle(color: AppConstants.textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                            borderSide: const BorderSide(color: AppConstants.primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty || selectedDate == null) {
                    _showFeedbackSnackBar(context, 'الرجاء إدخال عنوان وتاريخ الحجز.', isError: true);
                    return;
                  }
                  try {
                    await _firestore.collection('bookings').doc(booking.id).update({
                      'title': titleController.text,
                      'date': Timestamp.fromDate(selectedDate!),
                      'engineerId': _role == 'client'
                          ? selectedUserId
                          : (_role == 'engineer' ? _uid : selectedUserId),
                      'clientId': _role == 'engineer'
                          ? selectedUserId
                          : (_role == 'client' ? _uid : selectedUserId),
                      'note': note,
                    });
                    if (mounted) Navigator.pop(context);
                    _showFeedbackSnackBar(context, 'تم تحديث الحجز بنجاح.', isError: false);
                  } catch (e) {
                    _showFeedbackSnackBar(context, 'فشل تحديث الحجز: $e', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge, vertical: AppConstants.paddingSmall),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteBooking(String bookingId) async {
    // Show confirmation dialog before deleting
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف', style: TextStyle(color: AppConstants.textPrimary)),
          content: const Text('هل أنت متأكد أنك تريد حذف هذا الحجز؟', style: TextStyle(color: AppConstants.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.deleteColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('bookings').doc(bookingId).delete();
        _showFeedbackSnackBar(context, 'تم حذف الحجز بنجاح.', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل حذف الحجز: $e', isError: true);
      }
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              )));
    }
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(

            'إدارة الحجوزات',
          ),
          centerTitle: true,
          // AppBarTheme from main.dart already applies primaryColor, iconTheme, and titleTextStyle
          // Removing flexibleSpace with LinearGradient to be consistent with global AppBarTheme if not explicitly defined there.
          // The global AppBarTheme specifies 'color: AppConstants.primaryDark', so we don't need `backgroundColor` here.
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addBooking,
          backgroundColor: AppConstants.accentColor, // Using accentColor for FloatingActionButton
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('إضافة حجز', style: TextStyle(color: Colors.white)),
          tooltip: 'إضافة حجز',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _bookingsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            final bookings = snapshot.data!.docs.map((e) => Booking.fromDoc(e)).toList();
            if (bookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note_outlined, size: 80, color: AppConstants.textLight),
                    const SizedBox(height: AppConstants.paddingMedium),
                    Text(
                      'لا توجد حجوزات حالياً',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppConstants.textSecondary),
                    ),
                    const SizedBox(height: AppConstants.paddingSmall),
                    Text(
                      'اضغط على زر الإضافة لإنشاء حجز جديد.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppConstants.textLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final b = bookings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                  color: AppConstants.cardColor,
                  elevation: 0, // Control elevation for a flatter design if desired, or keep 2
                  shadowColor: AppConstants.cardShadow[0].color, // Use defined shadow color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    side: const BorderSide(color: AppConstants.dividerColor, width: 0.5), // Subtle border
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event, color: AppConstants.primaryColor, size: 24),
                            const SizedBox(width: AppConstants.paddingSmall),
                            Expanded(
                              child: Text(
                                b.title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textPrimary,
                                ),
                              ),
                            ),
                            if (b.createdBy == _uid)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditBookingDialog(b);
                                  } else if (value == 'delete') {
                                    _deleteBooking(b.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, color: AppConstants.infoColor, size: 20),
                                        SizedBox(width: AppConstants.paddingSmall),
                                        Text('تعديل', style: TextStyle(color: AppConstants.textPrimary)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: AppConstants.deleteColor, size: 20),
                                        SizedBox(width: AppConstants.paddingSmall),
                                        Text('حذف', style: TextStyle(color: AppConstants.deleteColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        Row(
                          children: [
                            Icon(Icons.date_range, color: AppConstants.textSecondary, size: 18),
                            const SizedBox(width: AppConstants.paddingSmall / 2),
                            Text(
                              'التاريخ: ${DateFormat('yyyy/MM/dd', 'ar').format(b.date)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppConstants.textSecondary),
                            ),
                            const SizedBox(width: AppConstants.itemSpacing),
                            Icon(Icons.schedule, color: AppConstants.textSecondary, size: 18),
                            const SizedBox(width: AppConstants.paddingSmall / 2),
                            Text(
                              'الوقت: ${DateFormat('HH:mm', 'ar').format(b.date)}', // Assuming date also contains time
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppConstants.textSecondary),
                            ),
                          ],
                        ),
                        if (b.note != null && b.note!.isNotEmpty) ...[
                          const SizedBox(height: AppConstants.paddingSmall),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes, color: AppConstants.textSecondary, size: 18),
                              const SizedBox(width: AppConstants.paddingSmall / 2),
                              Expanded(
                                child: Text(
                                  'ملاحظات: ${b.note}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppConstants.textLight),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppConstants.paddingSmall),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: AppConstants.textSecondary, size: 18),
                                const SizedBox(width: AppConstants.paddingSmall / 2),
                                Text(
                                  b.status == 'pending' ? 'بانتظار الموافقة' : 'مؤكد',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: b.status == 'pending' ? AppConstants.warningColor : AppConstants.successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_role == 'admin' && b.status == 'pending')
                              ElevatedButton.icon(
                                onPressed: () => _confirmBooking(b),
                                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                label: const Text('تأكيد الحجز', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.successColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall)),
                                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: 4),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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