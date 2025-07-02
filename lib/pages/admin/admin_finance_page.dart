// lib/pages/admin/admin_finance_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/finance_models.dart';
import '../../theme/app_constants.dart';

/// A simple dashboard for managing financial requests, debts and purchases.
class AdminFinancePage extends StatefulWidget {
  const AdminFinancePage({super.key});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage> {
  late final CollectionReference requestsRef;
  late final CollectionReference debtsRef;
  late final CollectionReference purchasesRef;

  @override
  void initState() {
    super.initState();
    requestsRef = FirebaseFirestore.instance.collection('financial_requests');
    debtsRef = FirebaseFirestore.instance.collection('debts');
    purchasesRef = FirebaseFirestore.instance.collection('purchases');
  }

  Future<void> approveRequest(String id) async {
    await requestsRef.doc(id).update({'status': 'approved'});
  }

  Future<void> rejectRequest(String id) async {
    await requestsRef.doc(id).update({'status': 'rejected'});
  }

  Widget _buildRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: requestsRef.where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات قيد المراجعة'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final request = FinancialRequest.fromFirestore(docs[index]);
            return ListTile(
              title: Text(request.description),
              subtitle: Text('${request.amount.toStringAsFixed(2)} - ${request.type}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: AppConstants.successColor),
                    onPressed: () => approveRequest(request.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppConstants.deleteColor),
                    onPressed: () => rejectRequest(request.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDebts() {
    return StreamBuilder<QuerySnapshot>(
      stream: debtsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد مديونيات')); 
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final debt = DebtEntry.fromFirestore(docs[index]);
            return ListTile(
              title: Text(debt.customerName),
              subtitle: Text('المتبقي: ${debt.remaining.toStringAsFixed(2)}'),
            );
          },
        );
      },
    );
  }

  Widget _buildPurchases() {
    return StreamBuilder<QuerySnapshot>(
      stream: purchasesRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد مشتريات')); 
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final purchase = PurchaseRecord.fromFirestore(docs[index]);
            return ListTile(
              title: Text(purchase.description),
              subtitle: Text('التكلفة: ${purchase.cost.toStringAsFixed(2)}'),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الوحدة المالية'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الطلبات'),
              Tab(text: 'المديونيات'),
              Tab(text: 'المشتريات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Widgets are built lazily using functions below
            _RequestsTab(),
            _DebtsTab(),
            _PurchasesTab(),
          ],
        ),
      ),
    );
  }
}

/// Wrappers to allow using functions defined above in TabBarView
class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminFinancePageState>()!;
    return state._buildRequests();
  }
}

class _DebtsTab extends StatelessWidget {
  const _DebtsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminFinancePageState>()!;
    return state._buildDebts();
  }
}

class _PurchasesTab extends StatelessWidget {
  const _PurchasesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminFinancePageState>()!;
    return state._buildPurchases();
  }
}

