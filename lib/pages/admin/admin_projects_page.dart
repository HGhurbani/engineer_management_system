import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Constants for consistent styling and text (يمكنك وضعها في ملف منفصل)
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح
  static const Color deleteColor = Colors.redAccent; // لون لزر الحذف

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class AdminProjectsPage extends StatefulWidget {
  const AdminProjectsPage({super.key});

  @override
  State<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends State<AdminProjectsPage> {
  // قوائم المهندسين والعملاء المتاحين لاختيارهم في المشروع
  List<QueryDocumentSnapshot> _availableEngineers = [];
  List<QueryDocumentSnapshot> _availableClients = [];

  @override
  void initState() {
    super.initState();
    _loadUsers(); // تحميل المستخدمين عند تهيئة الصفحة
  }

  // دالة لتحميل قائمة المهندسين والعملاء من Firestore
  Future<void> _loadUsers() async {
    try {
      final engSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name') // ترتيب المهندسين أبجدياً
          .get();

      final cliSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'client')
          .orderBy('name') // ترتيب العملاء أبجدياً
          .get();

      setState(() {
        _availableEngineers = engSnap.docs;
        _availableClients = cliSnap.docs;
      });
    } catch (e) {
      _showErrorSnackBar(context, 'فشل تحميل قائمة المستخدمين: $e');
    }
  }

  // دالة لعرض نافذة إضافة مشروع جديد
  Future<void> _showAddProjectDialog() async {
    final nameController = TextEditingController();
    String? selectedEngineerId;
    String? selectedClientId;
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
    bool isLoading = false; // حالة تحميل داخل الـ dialog

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
                  color: AppConstants.primaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration('اسم المشروع', Icons.work_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال اسم المشروع.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      // Dropdown لاختيار المهندس المسؤول
                      _availableEngineers.isEmpty
                          ? const Text(
                        'لا يوجد مهندسون متاحون.',
                        style: TextStyle(color: AppConstants.secondaryTextColor),
                      )
                          : DropdownButtonFormField<String>(
                        decoration: _inputDecoration('المهندس المسؤول', Icons.engineering_outlined),
                        hint: const Text('اختر مهندسًا'),
                        value: selectedEngineerId,
                        items: _availableEngineers.map((engineer) {
                          final name = (engineer.data() as Map<String, dynamic>)['name'] as String? ?? 'اسم غير متوفر';
                          return DropdownMenuItem<String>(
                            value: engineer.id,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedEngineerId = val;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء اختيار المهندس المسؤول.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      // Dropdown لاختيار العميل
                      _availableClients.isEmpty
                          ? const Text(
                        'لا يوجد عملاء متاحون.',
                        style: TextStyle(color: AppConstants.secondaryTextColor),
                      )
                          : DropdownButtonFormField<String>(
                        decoration: _inputDecoration('العميل', Icons.person_outline),
                        hint: const Text('اختر عميلاً'),
                        value: selectedClientId,
                        items: _availableClients.map((client) {
                          final name = (client.data() as Map<String, dynamic>)['name'] as String? ?? 'اسم غير متوفر';
                          return DropdownMenuItem<String>(
                            value: client.id,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedClientId = val;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء اختيار العميل.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء', style: TextStyle(color: AppConstants.secondaryTextColor)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (!_formKey.currentState!.validate()) return;

                    // تحقق إضافي في حالة كان DropdownButtonFormField لا يحتوي على validator
                    if (selectedEngineerId == null || selectedClientId == null) {
                      _showErrorSnackBar(dialogContext, 'الرجاء اختيار المهندس والعميل.');
                      return;
                    }

                    setDialogState(() {
                      isLoading = true;
                    });

                    try {
                      final eng = _availableEngineers.firstWhere((e) => e.id == selectedEngineerId);
                      final cli = _availableClients.firstWhere((e) => e.id == selectedClientId);

                      final engineerName = (eng.data() as Map<String, dynamic>)['name'] as String? ?? 'غير معروف';
                      final clientName = (cli.data() as Map<String, dynamic>)['name'] as String? ?? 'غير معروف';

                      final docRef = await FirebaseFirestore.instance.collection('projects').add({
                        'name': nameController.text.trim(),
                        'engineerId': selectedEngineerId,
                        'engineerName': engineerName,
                        'clientId': selectedClientId,
                        'clientName': clientName,
                        'currentStage': 0, // المرحلة تبدأ من 0 أو أي قيمة تدل على عدم وجود مراحل بعد
                        'currentPhaseName': 'لا توجد مراحل بعد', // اسم المرحلة الحالية الافتراضي
                        'status': 'نشط',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      // تم إزالة جزء إنشاء الـ 12 مرحلة الافتراضية هنا
                      // for (int i = 1; i <= 12; i++) {
                      //   await docRef.collection('phases').doc(i.toString().padLeft(2, '0')).set({
                      //     'number': i,
                      //     'note': '',
                      //     'imageUrl': null,
                      //     'image360Url': null,
                      //     'completed': false,
                      //     'createdAt': FieldValue.serverTimestamp(),
                      //   });
                      // }

                      Navigator.pop(dialogContext); // إغلاق الـ dialog
                      _showSuccessSnackBar(context, 'تم إضافة المشروع "${nameController.text.trim()}" بنجاح. يمكنك الآن إضافة المراحل إليه.');
                    } catch (e) {
                      setDialogState(() { isLoading = false; });
                      _showErrorSnackBar(context, 'فشل إضافة المشروع: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('إضافة', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // دالة لحذف المشروع
  Future<void> _deleteProject(String projectId, String projectName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف المشروع "$projectName"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, true);
                try {
                  // حذف جميع مراحل المشروع الفرعية أولاً (مهم جداً)
                  final phasesSnapshot = await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(projectId)
                      .collection('phases')
                      .get();
                  for (final doc in phasesSnapshot.docs) {
                    await doc.reference.delete();
                  }

                  // ثم حذف مستند المشروع الرئيسي
                  await FirebaseFirestore.instance.collection('projects').doc(projectId).delete();
                  _showSuccessSnackBar(context, 'تم حذف المشروع "$projectName" بنجاح.');
                } catch (e) {
                  _showErrorSnackBar(context, 'فشل حذف المشروع: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deleteColor),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لإنشاء InputDecoration موحد
  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppConstants.secondaryTextColor),
      prefixIcon: Icon(icon, color: AppConstants.primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.accentColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        borderSide: const BorderSide(color: AppConstants.errorColor, width: 2),
      ),
      filled: true,
      fillColor: AppConstants.cardColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
    );
  }

  // دالة مساعدة لعرض SnackBar للأخطاء
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  // دالة مساعدة لعرض SnackBar للنجاح
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'جميع المشاريع',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: AppConstants.primaryColor,
          elevation: 4,
          centerTitle: true,
        ),
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
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
                  style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.work, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Text(
                      'لا توجد مشاريع حتى الآن.',
                      style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                    ),
                  ],
                ),
              );
            }

            final projects = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(AppConstants.padding / 2),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final data = project.data() as Map<String, dynamic>;
                final name = data['name'] as String? ?? 'اسم مشروع غير متوفر';
                final currentStage = data['currentStage'] as int? ?? 1; // Assuming default if not set
                final currentPhaseName = data['currentPhaseName'] as String? ?? 'غير محددة'; // Get phase name
                final engineerName = data['engineerName'] as String? ?? 'غير معروف';
                final clientName = data['clientName'] as String? ?? 'غير معروف';
                final status = data['status'] as String? ?? 'غير محدد'; // حالة المشروع

                // تحديد لون بناءً على حالة المشروع
                Color statusColor = AppConstants.secondaryTextColor;
                IconData statusIcon = Icons.info_outline;
                if (status == 'نشط') {
                  statusColor = Colors.green.shade600;
                  statusIcon = Icons.play_circle_fill_outlined;
                } else if (status == 'مكتمل') {
                  statusColor = Colors.blue.shade600;
                  statusIcon = Icons.check_circle_outline;
                } else if (status == 'معلق') {
                  statusColor = Colors.orange.shade600;
                  statusIcon = Icons.pause_circle_outline;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.2),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المرحلة الحالية: $currentStage - $currentPhaseName', // Display current phase name
                          style: TextStyle(
                            fontSize: 14,
                            color: AppConstants.secondaryTextColor,
                          ),
                        ),
                        Text(
                          'المهندس: $engineerName',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.secondaryTextColor.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'العميل: $clientName',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.secondaryTextColor.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    isThreeLine: true, // مهم لجعل الـ subtitle يأخذ عدة أسطر
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppConstants.deleteColor),
                          onPressed: () async {
                            await _deleteProject(project.id, name);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/admin/projectDetails',
                        arguments: project.id,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddProjectDialog,
          backgroundColor: AppConstants.primaryColor,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'إضافة مشروع',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          tooltip: 'إضافة مشروع جديد',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}