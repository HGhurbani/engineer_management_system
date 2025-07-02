// lib/models/finance_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a sales or spare part order that requires financial approval.
class FinancialRequest {
  final String id;
  final String type; // e.g. "sale", "sparePart"
  final String description;
  final double amount;
  final String status; // pending, approved, rejected

  FinancialRequest({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.status,
  });

  factory FinancialRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FinancialRequest(
      id: doc.id,
      type: data['type'] as String? ?? '',
      description: data['description'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'description': description,
      'amount': amount,
      'status': status,
    };
  }
}

/// Represents a debt entry with payments and remaining balance.
class DebtEntry {
  final String id;
  final String customerName;
  final double total;
  final double paid;

  DebtEntry({
    required this.id,
    required this.customerName,
    required this.total,
    required this.paid,
  });

  double get remaining => total - paid;

  factory DebtEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DebtEntry(
      id: doc.id,
      customerName: data['customerName'] as String? ?? '',
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      paid: (data['paid'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerName': customerName,
      'total': total,
      'paid': paid,
    };
  }
}

/// Represents a purchase linked to maintenance or production cost.
class PurchaseRecord {
  final String id;
  final String description;
  final double cost;
  final String relatedProjectId;

  PurchaseRecord({
    required this.id,
    required this.description,
    required this.cost,
    required this.relatedProjectId,
  });

  factory PurchaseRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PurchaseRecord(
      id: doc.id,
      description: data['description'] as String? ?? '',
      cost: (data['cost'] as num?)?.toDouble() ?? 0.0,
      relatedProjectId: data['relatedProjectId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'cost': cost,
      'relatedProjectId': relatedProjectId,
    };
  }
}

