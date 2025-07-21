import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String title;
  final DateTime date;
  final String createdBy;
  final String createdByRole;
  final String? engineerId;
  final String? clientId;
  final String status;
  final String? note;

  Booking({
    required this.id,
    required this.title,
    required this.date,
    required this.createdBy,
    required this.createdByRole,
    this.engineerId,
    this.clientId,
    this.status = 'pending',
    this.note,
  });

  factory Booking.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      createdByRole: data['createdByRole'] ?? '',
      engineerId: data['engineerId'],
      clientId: data['clientId'],
      status: data['status'] ?? 'pending',
      note: data['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'engineerId': engineerId,
      'clientId': clientId,
      'status': status,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
