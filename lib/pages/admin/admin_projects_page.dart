// lib/pages/admin/admin_projects_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'add_project_page.dart'; // For TextDirection

// Constants (تبقى كما هي)
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color deleteColor = errorColor;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;
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
  bool _isLoadingUsers = true; // لتتبع حالة تحميل المستخدمين عند بدء الصفحة

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

  Future<void> _showAddProjectDialog() async {
    // إذا كانت القوائم لا تزال تُحمّل أو فارغة تمامًا بعد المحاولة الأولى،
    // قد يكون من الأفضل عدم فتح النافذة وإعلام المستخدم.
    if (_isLoadingUsers) {
      _showFeedbackSnackBar(context, 'جاري تحميل بيانات المستخدمين، يرجى الانتظار...', isError: false);
      return;
    }
    // إذا كانت القوائم فارغة بعد انتهاء التحميل، أعلم المستخدم
    if (_availableEngineers.isEmpty && _availableClients.isEmpty) {
      _showFeedbackSnackBar(context, 'يجب إضافة مهندسين وعملاء أولاً قبل إضافة مشروع.', isError: true);
      return;
    }
    if (_availableEngineers.isEmpty) {
      _showFeedbackSnackBar(context, 'لا يوجد مهندسون متاحون. يرجى إضافتهم أولاً.', isError: true);
      return;
    }
    if (_availableClients.isEmpty) {
      _showFeedbackSnackBar(context, 'لا يوجد عملاء متاحون. يرجى إضافتهم أولاً.', isError: true);
      return;
    }


    final nameController = TextEditingController();
    String? selectedClientIdInDialog;
    List<String> dialogSelectedEngineerIds = []; // متغير محلي للنافذة
    final formKey = GlobalKey<FormState>();
    bool isLoadingDialog = false;

    // لا حاجة لاستدعاء _loadUsers() هنا مرة أخرى إذا كان initState يقوم بذلك
    // وإذا كان زر الإضافة معطلاً أثناء _isLoadingUsers

    await showDialog(
      context: context,
      barrierDismissible: !isLoadingDialog,
      builder: (dialogContext) { // استخدام dialogContext بشكل ثابت
        return StatefulBuilder(
          builder: (stfDialogContext, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStyledTextField(
                          controller: nameController,
                          labelText: 'اسم المشروع',
                          icon: Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        const Text(
                          'اختر المهندسين المسؤولين:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        // قائمة المهندسين
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(stfDialogContext).size.height * 0.25,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppConstants.textSecondary.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                          ),
                          child: _availableEngineers.isEmpty
                              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("لا يوجد مهندسون متاحون.")))
                              : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableEngineers.length,
                            itemBuilder: (ctx, index) {
                              final engineerDoc = _availableEngineers[index];
                              final engineer = engineerDoc.data() as Map<String, dynamic>;
                              final engineerId = engineerDoc.id;
                              final engineerName = engineer['name'] ?? 'مهندس غير مسمى';
                              final bool isSelected = dialogSelectedEngineerIds.contains(engineerId);

                              return CheckboxListTile(
                                title: Text(engineerName, style: const TextStyle(color: AppConstants.textPrimary)),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      if (!dialogSelectedEngineerIds.contains(engineerId)) {
                                        dialogSelectedEngineerIds.add(engineerId);
                                      }
                                    } else {
                                      dialogSelectedEngineerIds.remove(engineerId);
                                    }
                                  });
                                },
                                activeColor: AppConstants.primaryColor,
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                              );
                            },
                          ),
                        ),
                        // مدقق المهندسين
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: FormField<List<String>>(
                            initialValue: dialogSelectedEngineerIds, // مهم للتحقق الأولي
                            validator: (value) {
                              // التحقق فقط إذا كان هناك مهندسون متاحون أصلاً
                              if (_availableEngineers.isNotEmpty && (value == null || value.isEmpty)) {
                                return 'الرجاء اختيار مهندس واحد على الأقل.';
                              }
                              return null;
                            },
                            builder: (FormFieldState<List<String>> fieldState) {
                              return fieldState.hasError
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 5.0),
                                child: Text(
                                  fieldState.errorText!,
                                  style: TextStyle(color: Theme.of(stfDialogContext).colorScheme.error, fontSize: 12),
                                ),
                              )
                                  : const SizedBox.shrink();
                            },
                          ),
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        // قائمة العملاء
                        _buildStyledDropdown(
                            contextForTheme: stfDialogContext, // تمرير context النافذة للـ theme
                            hint: 'اختر العميل',
                            value: selectedClientIdInDialog,
                            items: _availableClients.map((doc) {
                              final user = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(user['name'] ?? 'عميل غير مسمى'),
                              );
                            }).toList(),
                            onChanged: (value) => setDialogState(() => selectedClientIdInDialog = value),
                            icon: Icons.person_outline_rounded,
                            validator: (value) {
                              if (_availableClients.isNotEmpty && value == null) {
                                return 'الرجاء اختيار عميل.';
                              }
                              return null;
                            }
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
                    onPressed: isLoadingDialog
                        ? null
                        : () async {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      // لا حاجة للتحقق اليدوي من dialogSelectedEngineerIds و selectedClientIdInDialog هنا
                      // لأن الـ FormField validator يجب أن يكون قد قام بذلك.

                      setDialogState(() => isLoadingDialog = true);

                      try {
                        List<Map<String, String>> assignedEngineersList = [];
                        List<String> engineerUidsList = [];

                        if (dialogSelectedEngineerIds.isNotEmpty) {
                          for (String engineerIdInLoop in dialogSelectedEngineerIds) {
                            final engineerDoc = _availableEngineers.firstWhere(
                                  (doc) => doc.id == engineerIdInLoop,
                            );
                            final engineerData = engineerDoc.data() as Map<String, dynamic>;
                            assignedEngineersList.add({
                              'uid': engineerIdInLoop,
                              'name': engineerData['name'] ?? 'مهندس غير مسمى',
                            });
                            engineerUidsList.add(engineerIdInLoop);
                          }
                        }

                        final cliDoc = _availableClients.firstWhere((c) => c.id == selectedClientIdInDialog);
                        final clientName = (cliDoc.data() as Map<String, dynamic>)['name'] ?? 'غير معروف';

                        await FirebaseFirestore.instance.collection('projects').add({
                          'name': nameController.text.trim(),
                          'assignedEngineers': assignedEngineersList,
                          'engineerUids': engineerUidsList,
                          'clientId': selectedClientIdInDialog,
                          'clientName': clientName,
                          'currentStage': 0,
                          'currentPhaseName': 'لا توجد مراحل بعد',
                          'status': 'نشط',
                          'createdAt': FieldValue.serverTimestamp(),
                          'generalNotes': '',
                        });

                        Navigator.pop(dialogContext); // إغلاق النافذة بعد النجاح
                        // استخدام context الصفحة الرئيسية لإظهار SnackBar
                        _showFeedbackSnackBar(context, 'تم إضافة المشروع بنجاح.', isError: false);
                      } catch (e) {
                        _showFeedbackSnackBar(dialogContext, 'فشل إضافة المشروع: $e', isError: true, useDialogContext: true);
                      } finally {
                        setDialogState(() => isLoadingDialog = false);
                      }
                    },
                    icon: isLoadingDialog
                        ? const SizedBox.shrink()
                        : const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                    label: isLoadingDialog
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                        : const Text('إضافة المشروع', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProject(String projectId, String projectName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
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
              if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingUsers) {
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
          onPressed: _isLoadingUsers ? null : _loadUsers, // تعطيل أثناء التحميل
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
          if (engineersDisplay.length > 50) { // تحديد طول معين قبل الاقتطاع
            engineersDisplay = '${engineersDisplay.substring(0, 50)}...';
          }
        }

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
                  _buildProjectInfoRow(Icons.engineering_outlined, 'المهندسون:', engineersDisplay),
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

// داخل _AdminProjectsPageState
// ...

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: (_isLoadingUsers || _availableEngineers.isEmpty || _availableClients.isEmpty)
          ? null
          : () async {
        // الانتقال إلى صفحة الإضافة الجديدة وتمرير البيانات
        final result = await Navigator.push<bool>( // استخدام bool لتتبع نتيجة الإضافة
          context,
          MaterialPageRoute(
            builder: (context) => AddProjectPage(
              availableEngineers: _availableEngineers,
              availableClients: _availableClients,
            ),
          ),
        );
        // يمكنك تحديث قائمة المشاريع هنا إذا عادت الصفحة بنتيجة إيجابية
        if (result == true && mounted) {
          // لا حاجة لاستدعاء _loadUsers() هنا بالضرورة لأن StreamBuilder سيحدث تلقائيًا
          // ولكن إذا كنت تريد تحديث قوائم المهندسين/العملاء أيضًا، يمكنك استدعاؤها
          // أو يمكنك الاعتماد على RefreshIndicator
          print("Project added successfully, list should refresh via StreamBuilder.");
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

// ... بقية الكود في AdminProjectsPage

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
          if (_availableEngineers.isEmpty || _availableClients.isEmpty && !_isLoadingUsers) // لا تعرض هذه الرسالة إذا كان التحميل جارياً
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'هذا الحقل مطلوب.';
        return validator?.call(value);
      },
    );
  }

  Widget _buildStyledDropdown<T>({
    required BuildContext contextForTheme, // لإعطاء Theme.of السياق الصحيح
    required String hint,
    T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items.isEmpty ? [DropdownMenuItem(value: null, child: Text("لا يوجد خيارات", style: TextStyle(color: AppConstants.textSecondary.withOpacity(0.7))))] : items,
      onChanged: items.isEmpty ? null : onChanged,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
        ),
      ),
      isExpanded: true,
      menuMaxHeight: MediaQuery.of(contextForTheme).size.height * 0.3,
      disabledHint: items.isEmpty ? const Text("لا يوجد خيارات متاحة") : null,
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
    // استخدام السياق الصحيح لإظهار SnackBar
    // إذا كنا نريد إظهاره فوق الـ Dialog, نستخدم سياق الـ Dialog (stfDialogContext)
    // إذا كنا نريد إظهاره على الصفحة الرئيسية, نستخدم سياق الصفحة (this.context)
    ScaffoldMessenger.of(useDialogContext ? scaffoldOrDialogContext : context).showSnackBar(snackBar);
  }
}