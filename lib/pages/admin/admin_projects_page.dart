// lib/pages/admin/admin_projects_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:ui' as ui;

import 'add_project_page.dart';


class AdminProjectsPage extends StatefulWidget {
  const AdminProjectsPage({super.key});

  @override
  State<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends State<AdminProjectsPage> {
  List<QueryDocumentSnapshot> _availableEngineers = [];
  List<QueryDocumentSnapshot> _availableClients = [];
  bool _isLoadingUsers = true;

  // --- MODIFICATION START ---
  final Map<String, String> _clientTypeDisplayMap = {
    'individual': 'فردي',
    'company': 'شركة',
  };
  // --- MODIFICATION END ---

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      final engSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();

      final cliSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'client')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _availableEngineers = engSnap.docs;
          _availableClients = cliSnap.docs;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة المستخدمين: $e', isError: true);
      }
    }
  }

  Future<void> _deleteProject(String projectId, String projectName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف المشروع "$projectName" وجميع مراحله؟ هذا الإجراء لا يمكن التراجع عنه.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.deleteColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
        // Consider deleting subcollections like phases_status, subphases_status, tests_status, entries as well.
        // This example only deletes main phases and their subPhases for brevity.
        final phasesSnapshot = await projectRef.collection('phases').get();
        for (final phaseDoc in phasesSnapshot.docs) {
          final subPhasesSnapshot = await phaseDoc.reference.collection('subPhases').get();
          for (final subPhaseDoc in subPhasesSnapshot.docs) {
            await subPhaseDoc.reference.delete();
          }
          await phaseDoc.reference.delete();
        }
        await projectRef.delete();
        if(mounted) _showFeedbackSnackBar(context, 'تم حذف المشروع "$projectName" بنجاح.', isError: false);
      } catch (e) {
        if(mounted) _showFeedbackSnackBar(context, 'فشل حذف المشروع: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoadingUsers
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : RefreshIndicator(
          onRefresh: _loadUsers,
          color: AppConstants.primaryColor,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingUsers) { // Only show main loader if users are also loading
                return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
              }
              if (snapshot.hasError) {
                return _buildErrorState('حدث خطأ أثناء جلب المشاريع: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }
              final projects = snapshot.data!.docs;
              return _buildProjectsList(projects);
            },
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'إدارة المشاريع',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22),
      ),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 4,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'تحديث القوائم',
          onPressed: _isLoadingUsers ? null : _loadUsers,
        ),
      ],
    );
  }

  Widget _buildProjectsList(List<QueryDocumentSnapshot> projects) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final data = project.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'اسم مشروع غير متوفر';
        final currentStage = data['currentStage'] ?? 0;
        final currentPhaseName = data['currentPhaseName'] ?? 'غير محددة';
        final List<dynamic> assignedEngineersRaw = data['assignedEngineers'] as List<dynamic>? ?? [];
        String engineersDisplay = "لم يتم تعيين مهندسين";
        if (assignedEngineersRaw.isNotEmpty) {
          engineersDisplay = assignedEngineersRaw.map((eng) => eng['name'] ?? 'غير معروف').join('، ');
          if (engineersDisplay.length > 50) {
            engineersDisplay = '${engineersDisplay.substring(0, 50)}...';
          }
        }

        final clientName = data['clientName'] ?? 'غير معروف';
        // --- MODIFICATION START ---
        final String clientTypeKey = data['clientType'] ?? 'individual'; // Default if not set
        final String clientTypeDisplay = _clientTypeDisplayMap[clientTypeKey] ?? clientTypeKey;
        // --- MODIFICATION END ---
        final status = data['status'] ?? 'غير محدد';

        IconData statusIcon;
        Color statusColor;

        switch (status) {
          case 'نشط':
            statusIcon = Icons.construction_rounded;
            statusColor = AppConstants.infoColor;
            break;
          case 'مكتمل':
            statusIcon = Icons.check_circle_outline_rounded;
            statusColor = AppConstants.successColor;
            break;
          case 'معلق':
            statusIcon = Icons.pause_circle_outline_rounded;
            statusColor = AppConstants.warningColor;
            break;
          default:
            statusIcon = Icons.help_outline_rounded;
            statusColor = AppConstants.textSecondary;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
          elevation: 3,
          shadowColor: AppConstants.primaryColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/admin/projectDetails', arguments: project.id),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 28),
                      const SizedBox(width: AppConstants.itemSpacing / 2),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, color: AppConstants.deleteColor, size: 26),
                        onPressed: () => _deleteProject(project.id, name),
                        tooltip: 'حذف المشروع',
                      ),
                    ],
                  ),
                  const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
                  // _buildProjectInfoRow(Icons.stairs_outlined, 'المرحلة الحالية:', '$currentStage - $currentPhaseName'),
                  _buildProjectInfoRow(Icons.engineering_outlined, 'المهندسون:', engineersDisplay),
                  _buildProjectInfoRow(Icons.person_outline_rounded, 'العميل:', clientName),
                  // --- MODIFICATION START ---
                  _buildProjectInfoRow(Icons.business_center_outlined, 'نوع العميل:', clientTypeDisplay),
                  // --- MODIFICATION END ---
                  _buildProjectInfoRow(statusIcon, 'الحالة:', status, valueColor: statusColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: (_isLoadingUsers || _availableEngineers.isEmpty || _availableClients.isEmpty)
          ? null
          : () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => AddProjectPage(
              availableEngineers: _availableEngineers,
              availableClients: _availableClients,
            ),
          ),
        );
        if (result == true && mounted) {
          // List will refresh via StreamBuilder automatically
        }
      },
      backgroundColor: (_isLoadingUsers || _availableEngineers.isEmpty || _availableClients.isEmpty)
          ? AppConstants.textSecondary.withOpacity(0.5)
          : AppConstants.primaryColor,
      icon: const Icon(Icons.add_business_rounded, color: Colors.white),
      label: const Text('إضافة مشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      tooltip: (_isLoadingUsers || _availableEngineers.isEmpty || _availableClients.isEmpty)
          ? 'يرجى الانتظار أو إضافة مهندسين وعملاء أولاً'
          : 'إضافة مشروع جديد',
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 80, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.itemSpacing),
            const Text('عذراً، حدث خطأ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(errorMessage, style: const TextStyle(fontSize: 16, color: AppConstants.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.paddingMedium),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined, size: 100, color: AppConstants.textSecondary.withOpacity(0.5)),
          const SizedBox(height: AppConstants.itemSpacing),
          const Text('لا توجد مشاريع بعد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
          const SizedBox(height: 8),
          if (_availableEngineers.isEmpty || _availableClients.isEmpty && !_isLoadingUsers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge, vertical: AppConstants.paddingSmall),
              child: Text(
                _availableEngineers.isEmpty && _availableClients.isEmpty ? 'ملاحظة: يجب إضافة مهندسين وعملاء أولاً قبل إضافة المشاريع.' :
                _availableEngineers.isEmpty ? 'ملاحظة: يجب إضافة مهندسين أولاً قبل إضافة المشاريع.' :
                'ملاحظة: يجب إضافة عملاء أولاً قبل إضافة المشاريع.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppConstants.warningColor.withOpacity(0.9)),
              ),
            ),
          const Text('انقر على زر "إضافة مشروع" لبدء الإضافة (إذا كان مفعّلاً).', style: TextStyle(fontSize: 16, color: AppConstants.textSecondary)),
          const SizedBox(height: AppConstants.paddingMedium),
          ElevatedButton.icon(
            onPressed: _isLoadingUsers ? null : _loadUsers,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('تحديث القوائم', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
          )
        ],
      ),
    );
  }

  void _showFeedbackSnackBar(BuildContext scaffoldOrDialogContext, String message, {required bool isError, bool useDialogContext = false}) {
    final SnackBar snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
    );
    ScaffoldMessenger.of(useDialogContext ? scaffoldOrDialogContext : context).showSnackBar(snackBar);
  }
}