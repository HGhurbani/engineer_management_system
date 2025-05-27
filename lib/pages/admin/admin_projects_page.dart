// lib/pages/admin/admin_projects_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Constants for consistent styling, aligned with the admin dashboard's style.
class AppConstants {
  // Primary colors
  static const Color primaryColor = Color(0xFF2563EB); // Modern blue
  static const Color primaryLight = Color(0xFF3B82F6); // Lighter blue

  // Status and feedback colors
  static const Color successColor = Color(0xFF10B981); // Emerald green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color infoColor = Color(0xFF3B82F6); // Blue // For general info or active states

  // UI element colors
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC); // Soft background
  static const Color deleteColor = errorColor;

  // Text colors
  static const Color textPrimary = Color(0xFF1F2937); // Dark gray
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray

  // Spacing and dimensions
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;

  // Shadows for depth
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}

class AdminProjectsPage extends StatefulWidget {
  const AdminProjectsPage({super.key});

  @override
  State<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends State<AdminProjectsPage> {
  List<QueryDocumentSnapshot> _availableEngineers = [];
  List<QueryDocumentSnapshot> _availableClients = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
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
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة المستخدمين: $e', isError: true);
      }
    }
  }

  Future<void> _showAddProjectDialog() async {
    final nameController = TextEditingController();
    String? selectedEngineerId;
    String? selectedClientId;
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: const Text(
                'إضافة مشروع جديد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textPrimary,
                  fontSize: 22,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStyledTextField(
                        controller: nameController,
                        labelText: 'اسم المشروع',
                        icon: Icons.work_outline_rounded,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledDropdown(
                        hint: 'اختر المهندس المسؤول',
                        value: selectedEngineerId,
                        items: _availableEngineers.map((doc) {
                          final user = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(user['name'] ?? 'مهندس غير مسمى'),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedEngineerId = value),
                        icon: Icons.engineering_outlined,
                        validator: (value) => value == null ? 'الرجاء اختيار مهندس' : null,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledDropdown(
                        hint: 'اختر العميل',
                        value: selectedClientId,
                        items: _availableClients.map((doc) {
                          final user = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(user['name'] ?? 'عميل غير مسمى'),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedClientId = value),
                        icon: Icons.person_outline_rounded,
                        validator: (value) => value == null ? 'الرجاء اختيار عميل' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
                ),
                const SizedBox(width: AppConstants.itemSpacing / 2),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() => isLoading = true);

                    try {
                      final engDoc = _availableEngineers.firstWhere((e) => e.id == selectedEngineerId);
                      final cliDoc = _availableClients.firstWhere((c) => c.id == selectedClientId);

                      final engineerName = (engDoc.data() as Map<String, dynamic>)['name'] ?? 'غير معروف';
                      final clientName = (cliDoc.data() as Map<String, dynamic>)['name'] ?? 'غير معروف';

                      await FirebaseFirestore.instance.collection('projects').add({
                        'name': nameController.text.trim(),
                        'engineerId': selectedEngineerId,
                        'engineerName': engineerName,
                        'clientId': selectedClientId,
                        'clientName': clientName,
                        'currentStage': 0, // Initial stage
                        'currentPhaseName': 'لا توجد مراحل بعد', // Default phase name
                        'status': 'نشط', // Default status
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      // The logic for adding 12 default phases was intentionally removed in the original code.
                      //

                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تم إضافة المشروع بنجاح.', isError: false);
                    } catch (e) {
                      _showFeedbackSnackBar(context, 'فشل إضافة المشروع: $e', isError: true);
                      Navigator.pop(dialogContext);
                    }
                  },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                      : const Text('إضافة المشروع', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteProject(String projectId, String projectName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف المشروع "$projectName" وجميع مراحله؟ هذا الإجراء لا يمكن التراجع عنه.'),
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
        // Delete all sub-phases within each phase, then phases, then the project
        final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
        final phasesSnapshot = await projectRef.collection('phases').get();
        for (final phaseDoc in phasesSnapshot.docs) { //
          final subPhasesSnapshot = await phaseDoc.reference.collection('subPhases').get();
          for (final subPhaseDoc in subPhasesSnapshot.docs) {
            await subPhaseDoc.reference.delete();
          }
          await phaseDoc.reference.delete(); //
        }
        await projectRef.delete(); //
        _showFeedbackSnackBar(context, 'تم حذف المشروع "$projectName" بنجاح.', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل حذف المشروع: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (snapshot.hasError) {
              return _buildErrorState('حدث خطأ: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }
            final projects = snapshot.data!.docs;
            return _buildProjectsList(projects);
          },
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
        final engineerName = data['engineerName'] ?? 'غير معروف';
        final clientName = data['clientName'] ?? 'غير معروف';
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
                  _buildProjectInfoRow(Icons.stairs_outlined, 'المرحلة الحالية:', '$currentStage - $currentPhaseName'),
                  _buildProjectInfoRow(Icons.engineering_outlined, 'المهندس:', engineerName),
                  _buildProjectInfoRow(Icons.person_outline_rounded, 'العميل:', clientName),
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
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddProjectDialog,
      backgroundColor: AppConstants.primaryColor,
      icon: const Icon(Icons.add_business_rounded, color: Colors.white),
      label: const Text('إضافة مشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      tooltip: 'إضافة مشروع جديد',
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
          const Text('انقر على زر "إضافة مشروع" لبدء الإضافة.', style: TextStyle(fontSize: 16, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'هذا الحقل مطلوب.';
        return validator?.call(value);
      },
    );
  }

  Widget _buildStyledDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
      ),
      isExpanded: true,
    );
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}