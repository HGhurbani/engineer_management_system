// lib/pages/admin/admin_project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // لا يزال مطلوبًا لرفع الصور
import 'dart:io'; // لا يزال مطلوبًا لـ File
import 'package:http/http.dart' as http; // لا يزال مطلوبًا لرفع الصور عبر PHP
import 'dart:convert'; // لا يزال مطلوبًا لـ jsonDecode
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;

import 'edit_assigned_engineers_page.dart'; // For TextDirection

// --- نسخ AppConstants هنا ---
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
        color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const String UPLOAD_URL = 'https://creditphoneqatar.com/eng-app/upload_image.php';
}
// --- نهاية نسخ AppConstants ---

class AdminProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const AdminProjectDetailsPage({super.key, required this.projectId});

  @override
  State<AdminProjectDetailsPage> createState() =>
      _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> with TickerProviderStateMixin { // إضافة TickerProviderStateMixin
  Key _projectFutureBuilderKey = UniqueKey();
  String? _currentUserRole;
  bool _isPageLoading = true;
  DocumentSnapshot? _projectDataSnapshot; // لتخزين بيانات المشروع بعد تحميلها
  List<QueryDocumentSnapshot> _phasesSnapshots = []; // لتخزين بيانات المراحل

  // متغيرات لحفظ حالة التبويب (Tabs)
  late TabController _tabController;

  // متغيرات لإدارة المهندسين (كما في السابق)
  List<QueryDocumentSnapshot> _allAvailableEngineers = [];
  List<String> _currentlySelectedEngineerIdsForEdit = [];
  final GlobalKey<FormState> _editEngineersFormKey = GlobalKey<FormState>();

  // قوائم المراحل والاختبارات (ستكون ثابتة مبدئياً)
  static const List<Map<String, dynamic>> predefinedPhasesStructure = [
    {
      'id': 'phase_01', // معرّف فريد لكل مرحلة
      'name': 'تأسيس الميدة',
      'subPhases': [
        {'id': 'sub_01_01', 'name': 'أعمال السباكة: تركيب سليفات لأنظمة الصرف الصحي'},
        {'id': 'sub_01_02', 'name': 'أعمال السباكة: تثبيت وتوازن أنابيب الصرف والتهوية الرأسية'},
        {'id': 'sub_01_03', 'name': 'أعمال السباكة: تمديد مواسير تغذية المياه'},
        {'id': 'sub_01_04', 'name': 'أعمال السباكة: تأمين وتسكير الفتحات باستخدام الشريط الأسود'},
        {'id': 'sub_01_05', 'name': 'أعمال الكهرباء: تأسيس مواسير لمسارات الكوابل (كيبل واحد لكل ماسورة)'},
        {'id': 'sub_01_06', 'name': 'أعمال الكهرباء: تمديد مواسير التيار الخفيف وتحديد مكان لوحة المفاتيح'},
        {'id': 'sub_01_07', 'name': 'أعمال الكهرباء: تأسيس سليف للطاقة الشمسية'},
        {'id': 'sub_01_08', 'name': 'أعمال الكهرباء: تأمين وتسكير المواسير والسليفات بالشريط الأسود'},
        {'id': 'sub_01_09', 'name': 'أعمال الكهرباء: تأريض الأعمدة'},
      ]
    },
    {
      'id': 'phase_02',
      'name': 'أعمال الصرف الصحي ٦ إنش',
      'subPhases': [
        {'id': 'sub_02_01', 'name': 'تحديد مواقع كراسي الحمامات وأنواعها'},
        {'id': 'sub_02_02', 'name': 'التأكد من ميول المواسير'},
        {'id': 'sub_02_03', 'name': 'فحص مواقع الصفايات'},
        {'id': 'sub_02_04', 'name': 'تأكيد مواقع الكلين آوت وأبعادها'},
        {'id': 'sub_02_05', 'name': 'إغلاق الفتحات بالكاب أو الشريط الأسود'},
        {'id': 'sub_02_06', 'name': 'تثبيت المواسير أرضياً'},
        {'id': 'sub_02_07', 'name': 'استخدام المنظف قبل الغراء'},
        {'id': 'sub_02_08', 'name': 'ضمان تطبيق الغراء بشكل صحيح'},
        {'id': 'sub_02_09', 'name': 'تركيب رداد عند نهاية الماسورة المرتبطة بشركة المياه'},
        {'id': 'sub_02_10', 'name': 'إجراء اختبار التسرب بالماء'},
      ]
    },
    // ... يمكنك إضافة بقية الـ 13 مرحلة هنا بنفس الطريقة
    {
      'id': 'phase_03',
      'name': 'تمديد مواسير السباكة في الحوائط',
      'subPhases': [
        {'id': 'sub_03_01', 'name': 'التأكد من التثبيت الجيد وتوازن المواسير'},
        {'id': 'sub_03_02', 'name': 'فحص الطول المناسب لكل خط'},
        {'id': 'sub_03_03', 'name': 'تأمين وتسكير الفتحات بالشريط الأسود أو القطن'},
      ]
    },
    {
      'id': 'phase_04',
      'name': 'كهرباء الدرج والعتبات',
      'subPhases': [
        {'id': 'sub_04_01', 'name': 'تحديد مواقع الإنارة حسب المخططات'},
        {'id': 'sub_04_02', 'name': 'تثبيت وتربيط المواسير بإحكام'},
        {'id': 'sub_04_03', 'name': 'إنارة أسفل الدرج'},
        {'id': 'sub_04_04', 'name': 'تمديد ماسورة لمفتاح مزدوج الاتجاه'},
      ]
    },
    {
      'id': 'phase_05',
      'name': 'أعمدة سور الفيلا الخارجي',
      'subPhases': [
        {'id': 'sub_05_01', 'name': 'تحديد موقع الإنتركم وإنارات السور'},
        {'id': 'sub_05_02', 'name': 'تثبيت المواسير جيداً'},
        {'id': 'sub_05_03', 'name': 'تركيب علب الكهرباء وتحديد المنسوب وتثبيتها'},
      ]
    },
    {
      'id': 'phase_06',
      'name': 'أعمال الأسقف',
      'subPhases': [
        {'id': 'sub_06_01', 'name': 'أعمال الكهرباء: تمديد المواسير وتثبيت العلب بشكل جيد'},
        {'id': 'sub_06_02', 'name': 'أعمال الكهرباء: تعليق المواسير في الجسور والحديد'},
        {'id': 'sub_06_03', 'name': 'أعمال السباكة: فحص مواقع سليفات الجسور للسباكة المعلقة'},
        // ... أكمل باقي المراحل الفرعية للأسقف
      ]
    },
    {
      'id': 'phase_07',
      'name': 'تمديد الإنارة في الجدران',
      'subPhases': [
        {'id': 'sub_07_01', 'name': 'أعمال الكهرباء: تمديد المواسير حسب توزيع الإنارة في المخطط'},
        {'id': 'sub_07_02', 'name': 'أعمال الكهرباء: الحد الأدنى ٢ متر لكل نقطة إنارة'},
      ]
    },
    {
      'id': 'phase_08',
      'name': 'مرحلة التمديدات',
      'subPhases': [
        {'id': 'sub_08_01', 'name': 'أعمال الكهرباء: تحديد نقاط مخارج الكهرباء'},
        {'id': 'sub_08_02', 'name': 'أعمال السباكة: تمديد مواسير التغذية بين الخزانات'},
        // ... أكمل باقي المراحل الفرعية للتمديدات
      ]
    },
    {
      'id': 'phase_09',
      'name': 'الصرف الصحي وتصريف الأمطار الداخلي',
      'subPhases': [
        {'id': 'sub_09_01', 'name': 'تعليق وتثبيت المواسير والقطع الصغيرة حسب الاستاندر'},
        // ... أكمل
      ]
    },
    {
      'id': 'phase_10',
      'name': 'أعمال الحوش',
      'subPhases': [
        {'id': 'sub_10_01', 'name': 'أعمال الكهرباء: توصيل تأريض الأعمدة'},
        {'id': 'sub_10_02', 'name': 'أعمال السباكة: تمديد نقاط الغسيل بالحوش بعد الصب'},
        // ... أكمل
      ]
    },
    {
      'id': 'phase_11',
      'name': 'الأعمال بعد اللياسة',
      'subPhases': [
        {'id': 'sub_11_01', 'name': 'أعمال السباكة: تركيب سيفون الكرسي المعلق بمنسوب ٠.٣٣ سم'},
        // ... أكمل
      ]
    },
    {
      'id': 'phase_12',
      'name': 'أعمال السطح بعد العزل',
      'subPhases': [
        {'id': 'sub_12_01', 'name': 'ربط تغذية الخزان العلوي من الأرضي فوق العزل'},
        {'id': 'sub_12_02', 'name': 'أعمال الكهرباء: استلام نقاط الإنارة من فني الجبسوم'},
        // ... أكمل
      ]
    },
    {
      'id': 'phase_13',
      'name': 'التفنيش والتشغيل',
      'subPhases': [
        {'id': 'sub_13_01', 'name': 'أعمال الكهرباء: تنظيف العلب جيداً'},
        {'id': 'sub_13_02', 'name': 'أعمال السباكة: تركيب الكراسي والمغاسل مع اختبار التثبيت'},
        // ... أكمل
      ]
    },
  ];

  static const List<Map<String, dynamic>> finalCommissioningTests = [
    {
      'section_id': 'tests_electricity',
      'section_name': 'أولاً: اختبارات الكهرباء (وفق كود IEC / NFPA / NEC)',
      'tests': [
        {'id': 'test_elec_01', 'name': 'اختبار مقاومة العزل: باستخدام جهاز الميجر بجهد 500/1000 فولت، والقيمة المقبولة ≥ 1 ميجا أوم.'},
        {'id': 'test_elec_02', 'name': 'اختبار الاستمرارية: فحص التوصيلات المغلقة والتأكد من سلامة الأسلاك.'},
        {'id': 'test_elec_03', 'name': 'اختبار مقاومة التأريض: باستخدام جهاز Earth Tester، والمقاومة المقبولة أقل من 5 أوم (يفضل < 1 أوم).'},
        {'id': 'test_elec_04', 'name': 'اختبار فرق الجهد: قياس الجهد بين المصدر والحمل والتأكد من ثباته.'},
        {'id': 'test_elec_05', 'name': 'اختبار قواطع الحماية (MCB/RCD): الضغط على زر الاختبار والتأكد من قطع التيار خلال المدة المسموحة.'},
        {'id': 'test_elec_06', 'name': 'اختبار تحميل الأحمال: تشغيل جميع الأحمال والتحقق من عدم وجود سخونة أو هبوط في الجهد.'},
        {'id': 'test_elec_07', 'name': 'اختبار الجهد والتيار: بقياس الفولت والأمبير عند نقاط متعددة.'},
        {'id': 'test_elec_08', 'name': 'اختبار أنظمة التيار الخفيف: فحص شبكات الإنترنت والتلفزيون والإنتركم.'},
        {'id': 'test_elec_09', 'name': 'فحص لوحات الكهرباء: التأكد من إحكام التوصيلات وتسميات الخطوط.'},
        {'id': 'test_elec_10', 'name': 'توثيق النتائج: تسجيل القراءات وتعريف الخطوط بلوحات الطبلون.'},
      ]
    },
    {
      'section_id': 'tests_water',
      'section_name': 'ثانياً: اختبارات تغذية المياه (وفق كود UPC / IPC)',
      'tests': [
        {'id': 'test_water_01', 'name': 'اختبار الضغط: باستخدام ساعة ضغط، ويُثبت الضغط لمدة 24 ساعة دون تسريب.'},
        {'id': 'test_water_02', 'name': 'اختبار التوصيلات: فحص التوصيلات النهائية للمغاسل والخلاطات والسخانات.'},
        {'id': 'test_water_03', 'name': 'اختبار عمل السخانات: التأكد من توفر ماء ساخن في جميع النقاط.'},
        {'id': 'test_water_04', 'name': 'اختبار تشغيل المضخة: للتحقق من توازن توزيع الماء.'},
        {'id': 'test_water_05', 'name': 'فحص سريان الماء: عند كافة المخارج النهائية (مغاسل، مطابخ، حمامات).'},
        {'id': 'test_water_06', 'name': 'اختبار الربط بين الخزانات: وتشغيل عوامة الخزان للتأكد من وظيفتها.'},
        {'id': 'test_water_07', 'name': 'توثيق النتائج: تسجيل بيانات الضغط والزمن لكل اختبار.'},
      ]
    },
  ];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // قسمين: المراحل، الاختبارات
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isPageLoading = true;
    });
    await _fetchCurrentUserRole();
    await _loadAllAvailableEngineers(); // تحميل قائمة المهندسين
    await _fetchProjectAndPhasesData(); // تحميل بيانات المشروع والمراحل
    if (mounted) {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        _currentUserRole = userDoc.data()?['role'] as String?;
      }
    }
  }

  Future<void> _loadAllAvailableEngineers() async {
    if (_allAvailableEngineers.isNotEmpty && mounted) return;
    try {
      final engSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();
      if (mounted) {
        _allAvailableEngineers = engSnap.docs;
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة المهندسين: $e', isError: true);
      }
    }
  }

  Future<void> _fetchProjectAndPhasesData() async {
    try {
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      if (mounted && projectDoc.exists) {
        _projectDataSnapshot = projectDoc;
        // لا نحتاج لجلب المراحل بشكل منفصل هنا إذا كنا سنعرضها من Firestore لاحقًا
        // أو إذا كنا سنعتمد على predefinedPhasesStructure للعرض فقط
      } else if (mounted) {
        _showFeedbackSnackBar(context, 'المشروع غير موجود.', isError: true);
        Navigator.pop(context); // العودة إذا لم يتم العثور على المشروع
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل بيانات المشروع: $e', isError: true);
      }
    }
  }


  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Future<void> _showEditAssignedEngineersDialog(Map<String, dynamic> projectDataMap) async {
    List<dynamic> currentProjectEngineersRaw = projectDataMap['assignedEngineers'] as List<dynamic>? ?? [];
    _currentlySelectedEngineerIdsForEdit = currentProjectEngineersRaw.map((eng) => eng['uid'].toString()).toList();
    List<String> initialSelectedEngineerIds = List.from(_currentlySelectedEngineerIdsForEdit);

    bool isLoadingDialog = false;

    if (_allAvailableEngineers.isEmpty && mounted) {
      await _loadAllAvailableEngineers(); // Ensure engineers are loaded
    }

    await showDialog(
      context: context,
      barrierDismissible: !isLoadingDialog,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                title: const Text('تعديل المهندسين المسؤولين', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary, fontSize: 22)),
                content: Form(
                  key: _editEngineersFormKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_allAvailableEngineers.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("جاري تحميل المهندسين...")))
                        else
                          Container(
                            constraints: BoxConstraints(maxHeight: MediaQuery.of(stfContext).size.height * 0.4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppConstants.textSecondary.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _allAvailableEngineers.length,
                              itemBuilder: (ctx, index) {
                                final engineerDoc = _allAvailableEngineers[index];
                                final engineer = engineerDoc.data() as Map<String, dynamic>;
                                final engineerId = engineerDoc.id;
                                final engineerName = engineer['name'] ?? 'مهندس غير مسمى';
                                final bool isSelected = _currentlySelectedEngineerIdsForEdit.contains(engineerId);

                                return CheckboxListTile(
                                  title: Text(engineerName, style: const TextStyle(color: AppConstants.textPrimary)),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        if (!_currentlySelectedEngineerIdsForEdit.contains(engineerId)) {
                                          _currentlySelectedEngineerIdsForEdit.add(engineerId);
                                        }
                                      } else {
                                        _currentlySelectedEngineerIdsForEdit.remove(engineerId);
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
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: FormField<List<String>>(
                            initialValue: _currentlySelectedEngineerIdsForEdit,
                            validator: (value) {
                              if (_allAvailableEngineers.isNotEmpty && (value == null || value.isEmpty)) {
                                return 'الرجاء اختيار مهندس واحد على الأقل.';
                              }
                              return null;
                            },
                            builder: (FormFieldState<List<String>> state) {
                              return state.hasError
                                  ? Padding(
                                padding: const EdgeInsets.only(top: 5.0),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(color: Theme.of(stfContext).colorScheme.error, fontSize: 12),
                                ),
                              )
                                  : const SizedBox.shrink();
                            },
                          ),
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
                      if (!_editEngineersFormKey.currentState!.validate()) return;
                      if (_allAvailableEngineers.isNotEmpty && _currentlySelectedEngineerIdsForEdit.isEmpty) {
                        _showFeedbackSnackBar(stfContext, 'الرجاء اختيار مهندس واحد على الأقل.', isError: true);
                        return;
                      }
                      setDialogState(() => isLoadingDialog = true);
                      await _saveAssignedEngineersChanges(widget.projectId, initialSelectedEngineerIds, projectDataMap['name'] ?? 'المشروع');
                      Navigator.pop(dialogContext);
                    },
                    icon: isLoadingDialog ? const SizedBox.shrink() : const Icon(Icons.save_alt_rounded, color: Colors.white),
                    label: isLoadingDialog
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
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


  Future<void> _saveAssignedEngineersChanges(String currentProjectId, List<String> initialEngineerIds, String projectName) async {
    List<Map<String, String>> updatedAssignedEngineersList = [];
    List<String> updatedEngineerUidsList = [];

    if (_currentlySelectedEngineerIdsForEdit.isNotEmpty) {
      for (String engineerId in _currentlySelectedEngineerIdsForEdit) {
        final engineerDoc = _allAvailableEngineers.firstWhere(
              (doc) => doc.id == engineerId,
        );
        final engineerData = engineerDoc.data() as Map<String, dynamic>;
        updatedAssignedEngineersList.add({
          'uid': engineerId,
          'name': engineerData['name'] ?? 'مهندس غير مسمى',
        });
        updatedEngineerUidsList.add(engineerId);
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(currentProjectId)
          .update({
        'assignedEngineers': updatedAssignedEngineersList,
        'engineerUids': updatedEngineerUidsList,
      });

      List<String> newlyAddedEngineerUids = _currentlySelectedEngineerIdsForEdit.where((uid) => !initialEngineerIds.contains(uid)).toList();
      if (newlyAddedEngineerUids.isNotEmpty) {
        // سنفترض أن الإشعار للمشروع ككل
        _sendNotificationToMultipleEngineers(
            projectId: currentProjectId,
            projectName: projectName,
            title: 'تم تعيينك لمشروع',
            body: 'لقد تم إضافتك كمهندس مسؤول لمشروع "$projectName".',
            recipientUids: newlyAddedEngineerUids,
            notificationType: 'engineer_assignment_project'
        );
      }

      _showFeedbackSnackBar(context, 'تم تحديث قائمة المهندسين بنجاح.', isError: false);
      if (mounted) {
        setState(() {
          _projectFutureBuilderKey = UniqueKey(); // لتحديث واجهة المشروع
        });
      }
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث قائمة المهندسين: $e', isError: true);
    }
  }

  // دالة إشعارات مجمعة جديدة
  Future<void> _sendNotificationToMultipleEngineers({
    required String projectId,
    required String projectName,
    required String title,
    required String body,
    required List<String> recipientUids,
    String phaseDocId = '', // اختياري
    required String notificationType,
  }) async {
    final notificationCollection = FirebaseFirestore.instance.collection('notifications');
    final currentUser = FirebaseAuth.instance.currentUser;
    String senderName = "النظام";
    if (currentUser != null) {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      senderName = senderDoc.data()?['name'] ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مهندس');
    }

    for (String userId in recipientUids) {
      try {
        await notificationCollection.add({
          'userId': userId,
          'projectId': projectId,
          'phaseDocId': phaseDocId,
          'title': title,
          'body': body,
          'type': notificationType,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'senderName': senderName,
        });
        print('Notification sent to $userId for project $projectName');
      } catch(e) {
        print('Failed to send notification to $userId: $e');
        if (mounted) _showFeedbackSnackBar(context, 'فشل إرسال إشعار للمهندس $userId: $e', isError: true);
      }
    }
  }



  // ... (بقية الدوال مثل _updateProjectCurrentPhaseStatus, _addPhaseDialog, _deletePhase, الخ، تبقى كما هي أو مع تعديلات طفيفة إذا لزم الأمر)
  // سيتم تبسيطها أو إزالتها مؤقتًا للتركيز على بنية الأقسام.

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('تفاصيل المشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22)),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      elevation: 4,
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'مراحل المشروع', icon: Icon(Icons.list_alt_rounded)),
          Tab(text: 'اختبارات التشغيل', icon: Icon(Icons.checklist_rtl_rounded)),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard(Map<String, dynamic> projectDataMap) {
    final projectName = projectDataMap['name'] ?? 'مشروع غير مسمى';
    final clientName = projectDataMap['clientName'] ?? 'غير محدد';
    final projectStatus = projectDataMap['status'] ?? 'غير محدد';
    final List<dynamic> assignedEngineersRaw = projectDataMap['assignedEngineers'] as List<dynamic>? ?? [];
    String engineersDisplay = "لم يتم تعيين مهندسين";
    if (assignedEngineersRaw.isNotEmpty) {
      engineersDisplay = assignedEngineersRaw.map((eng) => eng['name'] ?? 'غير معروف').join('، ');
      if (engineersDisplay.length > 70) {
        engineersDisplay = '${engineersDisplay.substring(0, 70)}...';
      }
    }

    IconData statusIcon;
    Color statusColor;
    switch (projectStatus) {
      case 'نشط': statusIcon = Icons.construction_rounded; statusColor = AppConstants.infoColor; break;
      case 'مكتمل': statusIcon = Icons.check_circle_outline_rounded; statusColor = AppConstants.successColor; break;
      case 'معلق': statusIcon = Icons.pause_circle_outline_rounded; statusColor = AppConstants.warningColor; break;
      default: statusIcon = Icons.help_outline_rounded; statusColor = AppConstants.textSecondary;
    }

    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingLarge),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
            const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
            _buildDetailRow(Icons.engineering_rounded, 'المهندسون:', engineersDisplay),
            _buildDetailRow(Icons.person_rounded, 'العميل:', clientName),
            _buildDetailRow(statusIcon, 'حالة المشروع:', projectStatus, valueColor: statusColor),
            const SizedBox(height: AppConstants.itemSpacing),
            // ... داخل _buildProjectSummaryCard في AdminProjectDetailsPage ...
            if (_currentUserRole == 'admin')
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.group_add_rounded, color: Colors.white, size: 18),
                  label: const Text('تعديل المهندسين', style: TextStyle(color: Colors.white)), // تم تعديل النص قليلاً
                  onPressed: () async {
                    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
                      _showFeedbackSnackBar(context, "بيانات المشروع غير متوفرة حالياً.", isError: true);
                      return;
                    }
                    if (_allAvailableEngineers.isEmpty && mounted) { // التأكد من تحميل المهندسين
                      _showFeedbackSnackBar(context, "جاري تحميل قائمة المهندسين، يرجى المحاولة مرة أخرى بعد قليل.", isError: false);
                      await _loadAllAvailableEngineers(); // محاولة تحميلهم إذا كانت فارغة
                      if (_allAvailableEngineers.isEmpty && mounted) { // التحقق مرة أخرى
                        _showFeedbackSnackBar(context, "لا يوجد مهندسون متاحون في النظام.", isError: true);
                        return;
                      }
                    }


                    final projectDataMap = _projectDataSnapshot!.data() as Map<String, dynamic>;
                    final List<dynamic> currentEngRaw = projectDataMap['assignedEngineers'] as List<dynamic>? ?? [];
                    final List<Map<String, dynamic>> currentEngTyped = currentEngRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

                    // الانتقال إلى صفحة تعديل المهندسين
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditAssignedEngineersPage(
                          projectId: widget.projectId,
                          projectName: projectDataMap['name'] ?? 'مشروع غير مسمى',
                          currentlyAssignedEngineers: currentEngTyped,
                          allAvailableEngineers: _allAvailableEngineers,
                        ),
                      ),
                    );

                    if (result == true && mounted) {
                      // إذا عادت الصفحة بنتيجة true، قم بتحديث بيانات المشروع في هذه الصفحة
                      setState(() {
                        _projectFutureBuilderKey = UniqueKey(); // لإعادة بناء FutureBuilder
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                  ),
                ),
              )
// ...
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Text('$label ', style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // --- قسم بناء واجهة المراحل ---
  Widget _buildPhasesTab() {
    // هنا سنقوم ببناء واجهة المراحل الرئيسية والفرعية
    // سيتم جلب بيانات إكمال المراحل والملاحظات والصور من Firestore
    // وسنقارنها مع predefinedPhasesStructure للعرض

    // مثال مبسط جداً لعرض المراحل الرئيسية
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: predefinedPhasesStructure.length,
      itemBuilder: (context, index) {
        final phaseStructure = predefinedPhasesStructure[index];
        final phaseId = phaseStructure['id'] as String;
        final phaseName = phaseStructure['name'] as String;
        final subPhasesStructure = phaseStructure['subPhases'] as List<Map<String, dynamic>>;

        // يجب جلب بيانات هذه المرحلة من Firestore إذا كانت موجودة
        // (مثل: هل هي مكتملة؟ ما هي الملاحظات؟ الصور؟)
        // هذا StreamBuilder مثال لجلب بيانات مرحلة واحدة، ستحتاج لتكراره أو تجميعه
        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('phases_status') // مجموعة فرعية جديدة لحالة المراحل
                .doc(phaseId) // استخدام معرّف المرحلة الثابت
                .snapshots(),
            builder: (context, phaseStatusSnapshot) {
              bool isCompleted = false;
              List<Map<String, dynamic>> notesAndImages = []; // {type: 'note'/'image', content: '...', engineerName: '...', timestamp: ...}

              if (phaseStatusSnapshot.hasData && phaseStatusSnapshot.data!.exists) {
                final statusData = phaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                isCompleted = statusData['completed'] ?? false;
                // جلب الملاحظات والصور من مجموعة فرعية أخرى مثلاً:
                // phases_status/{phaseId}/entries (entries يمكن أن تكون ملاحظات أو صور)
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                child: ExpansionTile(
                  key: PageStorageKey<String>(phaseId), // للحفاظ على حالة التوسيع
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? AppConstants.successColor : AppConstants.primaryColor,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phaseName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Text(isCompleted ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: isCompleted ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isCompleted))
                        IconButton(
                          icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                          tooltip: 'إضافة ملاحظة/صورة',
                          onPressed: () => _showAddNoteOrImageDialog(phaseId, phaseName),
                        ),
                      if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isCompleted))
                        Checkbox(
                          value: isCompleted,
                          activeColor: AppConstants.successColor,
                          onChanged: (value) {
                            _updatePhaseCompletionStatus(phaseId, phaseName, value ?? false);
                          },
                        ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingSmall),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // عرض الملاحظات والصور الحالية للمرحلة الرئيسية
                          // ... (سيتم بناؤه لاحقًا باستخدام StreamBuilder لـ entries) ...
                          if (notesAndImages.isEmpty && subPhasesStructure.isEmpty)
                            const Center(child: Text('لا توجد تفاصيل لهذه المرحلة.', style: TextStyle(fontStyle: FontStyle.italic, color: AppConstants.textSecondary))),

                          // المراحل الفرعية
                          if (subPhasesStructure.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppConstants.paddingSmall, right: AppConstants.paddingMedium), // مسافة بادئة للمراحل الفرعية
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: subPhasesStructure.map((subPhaseMap) {
                                  final subPhaseId = subPhaseMap['id'] as String;
                                  final subPhaseName = subPhaseMap['name'] as String;
                                  // جلب حالة المرحلة الفرعية من Firestore
                                  return StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('projects')
                                          .doc(widget.projectId)
                                          .collection('subphases_status') // مجموعة فرعية جديدة لحالة المراحل الفرعية
                                          .doc(subPhaseId)
                                          .snapshots(),
                                      builder: (context, subPhaseStatusSnapshot) {
                                        bool isSubCompleted = false;
                                        if (subPhaseStatusSnapshot.hasData && subPhaseStatusSnapshot.data!.exists) {
                                          isSubCompleted = (subPhaseStatusSnapshot.data!.data() as Map<String,dynamic>)['completed'] ?? false;
                                        }
                                        return ListTile(
                                          dense: true,
                                          leading: Icon(
                                            isSubCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                            color: isSubCompleted ? AppConstants.successColor : AppConstants.textSecondary,
                                          ),
                                          title: Text(subPhaseName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isSubCompleted ? TextDecoration.lineThrough : null)),
                                          trailing: (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isSubCompleted))
                                              ? Checkbox(
                                            value: isSubCompleted,
                                            activeColor: AppConstants.successColor,
                                            onChanged: (value) {
                                              _updateSubPhaseCompletionStatus(phaseId, subPhaseId, subPhaseName, value ?? false);
                                            },
                                          )
                                              : null,
                                          onTap: () {
                                            // يمكن إضافة نافذة لإضافة ملاحظات/صور للمرحلة الفرعية
                                            if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isSubCompleted)) {
                                              _showAddNoteOrImageDialog(phaseId, subPhaseName, subPhaseId: subPhaseId);
                                            }
                                          },
                                        );
                                      }
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }
        );
      },
    );
  }

  // --- قسم بناء واجهة اختبارات التشغيل ---
  Widget _buildTestsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: finalCommissioningTests.length,
      itemBuilder: (context, sectionIndex) {
        final section = finalCommissioningTests[sectionIndex];
        final sectionId = section['section_id'] as String;
        final sectionName = section['section_name'] as String;
        final tests = section['tests'] as List<Map<String, dynamic>>;

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          child: ExpansionTile(
            key: PageStorageKey<String>(sectionId),
            title: Text(sectionName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
            childrenPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: AppConstants.paddingSmall / 2),
            children: tests.map((test) {
              final testId = test['id'] as String;
              final testName = test['name'] as String;
              // جلب حالة هذا الاختبار من Firestore
              return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.projectId)
                      .collection('tests_status') // مجموعة فرعية جديدة لحالة الاختبارات
                      .doc(testId)
                      .snapshots(),
                  builder: (context, testStatusSnapshot) {
                    bool isTestCompleted = false;
                    String testNote = "";
                    String? testImageUrl;
                    String? engineerName;


                    if (testStatusSnapshot.hasData && testStatusSnapshot.data!.exists) {
                      final statusData = testStatusSnapshot.data!.data() as Map<String, dynamic>;
                      isTestCompleted = statusData['completed'] ?? false;
                      testNote = statusData['note'] ?? '';
                      testImageUrl = statusData['imageUrl'] as String?;
                      engineerName = statusData['engineerName'] as String?;
                    }

                    return ListTile(
                      title: Text(testName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isTestCompleted ? TextDecoration.lineThrough : null)),
                      leading: Icon(
                        isTestCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isTestCompleted ? AppConstants.successColor : AppConstants.textSecondary,
                        size: 20,
                      ),
                      trailing: (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isTestCompleted))
                          ? Checkbox(
                        value: isTestCompleted,
                        activeColor: AppConstants.successColor,
                        onChanged: (value) {
                          _updateTestStatus(testId, testName, value ?? false, currentNote: testNote, currentImageUrl: testImageUrl);
                        },
                      )
                          : null,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (engineerName != null && engineerName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("بواسطة: $engineerName", style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic)),
                            ),
                          if (testNote.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("ملاحظة: $testNote", style: const TextStyle(fontSize: 12, color: AppConstants.infoColor)),
                            ),
                          if (testImageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: InkWell(
                                onTap: () => _viewImageDialog(testImageUrl!),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image_outlined, size: 16, color: AppConstants.primaryLight),
                                    SizedBox(width: 4),
                                    Text("عرض الصورة", style: TextStyle(fontSize: 12, color: AppConstants.primaryLight, decoration: TextDecoration.underline)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isTestCompleted)) {
                          _updateTestStatus(testId, testName, !isTestCompleted, currentNote: testNote, currentImageUrl: testImageUrl);
                        }
                      },
                    );
                  }
              );
            }).toList(),
          ),
        );
      },
    );
  }


  Future<void> _updatePhaseCompletionStatus(String phaseId, String phaseName, bool newStatus) async {
    // هذه الدالة لتحديث حالة إكمال المرحلة الرئيسية في Firestore
    try {
      final phaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases_status')
          .doc(phaseId);

      final currentUser = FirebaseAuth.instance.currentUser;
      String engineerName = "غير معروف";
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        engineerName = userDoc.data()?['name'] ?? 'مهندس';
      }


      await phaseDocRef.set({
        'completed': newStatus,
        'name': phaseName, // حفظ اسم المرحلة لسهولة الاستعلام لاحقاً إذا أردت
        'lastUpdatedByUid': currentUser?.uid,
        'lastUpdatedByName': engineerName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // إرسال إشعار للمسؤول والعميل
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final projectData = projectDoc.data();
      final projectName = projectData?['name'] ?? 'المشروع';
      final clientUid = projectData?['clientId'] as String?;
      final List<dynamic> assignedEngineersRaw = projectData?['assignedEngineers'] as List<dynamic>? ?? [];
      final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => e['uid'].toString()).toList();

      if (newStatus) { // فقط عند الإكمال
        _sendNotificationToMultipleEngineers(
            projectId: widget.projectId,
            projectName: projectName,
            title: 'تحديث مشروع: مرحلة مكتملة',
            body: 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة.',
            recipientUids: ['admin_user_id_placeholder'], // يجب استبداله بـ UIDs للمسؤولين الفعليين
            notificationType: 'phase_completed_admin',
            phaseDocId: phaseId
        );
        if (clientUid != null) {
          _sendNotificationToMultipleEngineers(
              projectId: widget.projectId,
              projectName: projectName,
              title: 'تحديث مشروع: مرحلة مكتملة',
              body: 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة. يمكنك الآن مراجعتها.',
              recipientUids: [clientUid],
              notificationType: 'phase_completed_client',
              phaseDocId: phaseId
          );
        }
        // إشعار المهندسين الآخرين إذا كان مهندس هو من أكملها
        if (_currentUserRole == 'engineer') {
          final otherEngineers = assignedEngineerUids.where((uid) => uid != currentUser?.uid).toList();
          if (otherEngineers.isNotEmpty) {
            _sendNotificationToMultipleEngineers(
                projectId: widget.projectId,
                projectName: projectName,
                title: 'تحديث مشروع: مرحلة مكتملة',
                body: 'المرحلة "$phaseName" في مشروع "$projectName" أصبحت مكتملة بواسطة المهندس $engineerName.',
                recipientUids: otherEngineers,
                notificationType: 'phase_completed_other_engineers',
                phaseDocId: phaseId
            );
          }
        }
      }


      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة "$phaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة: $e', isError: true);
    }
  }

  Future<void> _updateSubPhaseCompletionStatus(String mainPhaseId, String subPhaseId, String subPhaseName, bool newStatus) async {
    // لتحديث حالة إكمال المرحلة الفرعية
    try {
      final subPhaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('subphases_status')
          .doc(subPhaseId);

      final currentUser = FirebaseAuth.instance.currentUser;
      String engineerName = "غير معروف";
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        engineerName = userDoc.data()?['name'] ?? 'مهندس';
      }

      await subPhaseDocRef.set({
        'completed': newStatus,
        'mainPhaseId': mainPhaseId, // لربطها بالمرحلة الرئيسية
        'name': subPhaseName,
        'lastUpdatedByUid': currentUser?.uid,
        'lastUpdatedByName': engineerName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final projectData = projectDoc.data();
      final projectName = projectData?['name'] ?? 'المشروع';
      final clientUid = projectData?['clientId'] as String?;
      final List<dynamic> assignedEngineersRaw = projectData?['assignedEngineers'] as List<dynamic>? ?? [];
      final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => e['uid'].toString()).toList();

      if (newStatus) {
        _sendNotificationToMultipleEngineers(
            projectId: widget.projectId,
            projectName: projectName,
            title: 'تحديث مشروع: مرحلة فرعية مكتملة',
            body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectName" أصبحت مكتملة.',
            recipientUids: ['admin_user_id_placeholder'], // للمسؤولين
            notificationType: 'subphase_completed_admin',
            phaseDocId: mainPhaseId // نرسل معرف المرحلة الرئيسية
        );
        if (clientUid != null) {
          _sendNotificationToMultipleEngineers(
              projectId: widget.projectId,
              projectName: projectName,
              title: 'تحديث مشروع: مرحلة فرعية مكتملة',
              body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectName" أصبحت مكتملة.',
              recipientUids: [clientUid],
              notificationType: 'subphase_completed_client',
              phaseDocId: mainPhaseId
          );
        }
        if (_currentUserRole == 'engineer') {
          final otherEngineers = assignedEngineerUids.where((uid) => uid != currentUser?.uid).toList();
          if (otherEngineers.isNotEmpty) {
            _sendNotificationToMultipleEngineers(
                projectId: widget.projectId,
                projectName: projectName,
                title: 'تحديث مشروع: مرحلة فرعية مكتملة',
                body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectName" أصبحت مكتملة بواسطة المهندس $engineerName.',
                recipientUids: otherEngineers,
                notificationType: 'subphase_completed_other_engineers',
                phaseDocId: mainPhaseId
            );
          }
        }
      }
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة الفرعية "$subPhaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة الفرعية: $e', isError: true);
    }
  }

  Future<void> _updateTestStatus(String testId, String testName, bool newStatus, {String? currentNote, String? currentImageUrl}) async {
    // لتحديث حالة إكمال الاختبار
    final noteController = TextEditingController(text: currentNote ?? "");
    String? tempImageUrl = currentImageUrl; // لتخزين الصورة مؤقتًا أثناء التعديل
    File? pickedImageFile;
    bool isUploading = false;

    final currentUser = FirebaseAuth.instance.currentUser;
    String engineerName = "غير معروف";
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      engineerName = userDoc.data()?['name'] ?? 'مهندس';
    }


    bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: !isUploading,
        builder: (dialogContext) {
          return StatefulBuilder(builder: (stfContext, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: Text('تحديث حالة الاختبار: $testName'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        title: const Text('مكتمل'),
                        value: newStatus,
                        onChanged: (val) => setDialogState(() => newStatus = val ?? false),
                        activeColor: AppConstants.successColor,
                      ),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (tempImageUrl != null)
                        Column(
                          children: [
                            const Text("الصورة الحالية:"),
                            Image.network(tempImageUrl!, height: 100),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, color: AppConstants.errorColor),
                              label: const Text("حذف الصورة الحالية", style: TextStyle(color: AppConstants.errorColor)),
                              onPressed: () => setDialogState(() => tempImageUrl = null),
                            )
                          ],
                        ),
                      if (pickedImageFile != null)
                        Image.file(pickedImageFile!, height: 100),
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(pickedImageFile == null && tempImageUrl == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة'),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (picked != null) {
                            setDialogState(() => pickedImageFile = File(picked.path));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                  ElevatedButton(
                    onPressed: isUploading ? null : () => Navigator.pop(dialogContext, true),
                    child: isUploading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2,)) : const Text('حفظ'),
                  ),
                ],
              ),
            );
          });
        }
    );

    if (confirmed == true) {
      setState(() => isUploading = true); // حالة تحميل عامة للصفحة
      String? finalImageUrl = tempImageUrl; // ابدأ بالصورة الحالية
      if (pickedImageFile != null) { // إذا تم اختيار صورة جديدة، ارفعها
        try {
          final ref = FirebaseStorage.instance.ref().child('project_tests/${widget.projectId}/$testId/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(pickedImageFile!);
          finalImageUrl = await ref.getDownloadURL();
        } catch (e) {
          _showFeedbackSnackBar(context, 'فشل رفع صورة الاختبار: $e', isError: true);
          setState(() => isUploading = false);
          return;
        }
      }
      setState(() => isUploading = false);


      try {
        final testDocRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('tests_status')
            .doc(testId);

        await testDocRef.set({
          'completed': newStatus,
          'name': testName, // حفظ اسم الاختبار
          'note': noteController.text.trim(),
          'imageUrl': finalImageUrl, // حفظ رابط الصورة
          'lastUpdatedByUid': currentUser?.uid,
          'lastUpdatedByName': engineerName,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _showFeedbackSnackBar(context, 'تم تحديث حالة الاختبار "$testName".', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل تحديث حالة الاختبار: $e', isError: true);
      }
    }
  }

  Future<void> _showAddNoteOrImageDialog(String phaseId, String phaseOrSubPhaseName, {String? subPhaseId}) async {
    final noteController = TextEditingController();
    File? pickedImageFile;
    bool isUploading = false;
    final formKey = GlobalKey<FormState>();

    String dialogTitle = subPhaseId == null
        ? 'إضافة ملاحظة/صورة للمرحلة: $phaseOrSubPhaseName'
        : 'إضافة ملاحظة/صورة للمرحلة الفرعية: $phaseOrSubPhaseName';

    String collectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';


    await showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: Text(dialogTitle),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'الملاحظة (اختياري إذا أضفت صورة)'),
                        maxLines: 3,
                        validator: (value) {
                          if ((value == null || value.isEmpty) && pickedImageFile == null) {
                            return 'الرجاء إدخال ملاحظة أو إضافة صورة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (pickedImageFile != null)
                        Image.file(pickedImageFile!, height: 150, fit: BoxFit.contain),
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(pickedImageFile == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة'),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (picked != null) {
                            setDialogState(() {
                              pickedImageFile = File(picked.path);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() => isUploading = true);
                    String? imageUrl;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    String engineerName = "غير معروف";
                    if (currentUser != null) {
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                      engineerName = userDoc.data()?['name'] ?? 'مهندس';
                    }

                    if (pickedImageFile != null) {
                      try {
                        final refPath = subPhaseId == null
                            ? 'project_phases/${widget.projectId}/$phaseId/entries/${DateTime.now().millisecondsSinceEpoch}.jpg'
                            : 'project_subphases/${widget.projectId}/$subPhaseId/entries/${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final ref = FirebaseStorage.instance.ref().child(refPath);
                        await ref.putFile(pickedImageFile!);
                        imageUrl = await ref.getDownloadURL();
                      } catch (e) {
                        if (mounted) _showFeedbackSnackBar(dialogContext, 'فشل رفع الصورة: $e', isError: true);
                        setDialogState(() => isUploading = false);
                        return;
                      }
                    }

                    try {
                      await FirebaseFirestore.instance.collection(collectionPath).add({
                        'type': imageUrl != null ? 'image_with_note' : 'note',
                        'note': noteController.text.trim(),
                        'imageUrl': imageUrl,
                        'engineerUid': currentUser?.uid,
                        'engineerName': engineerName,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تمت إضافة الإدخال بنجاح.', isError: false);
                    } catch (e) {
                      if (mounted) _showFeedbackSnackBar(dialogContext, 'فشل إضافة الإدخال: $e', isError: true);
                    } finally {
                      setDialogState(() => isUploading = false);
                    }
                  },
                  child: isUploading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _viewImageDialog(String imageUrl) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: InteractiveViewer( // للسماح بالتكبير والتصغير
          panEnabled: false, // تعطيل التحريك إذا لم يكن ضرورياً
          boundaryMargin: EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : Center(child: CircularProgressIndicator()),
            errorBuilder: (ctx, err, st) => Center(child: Text("فشل تحميل الصورة")),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("إغلاق"),
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isPageLoading || _currentUserRole == null || _projectDataSnapshot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المشروع', style: TextStyle(color: Colors.white)), backgroundColor: AppConstants.primaryColor),
        body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }

    final projectDataMap = _projectDataSnapshot!.data() as Map<String, dynamic>;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingSmall), // تقليل الـ padding هنا
              child: _buildProjectSummaryCard(projectDataMap),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPhasesTab(),
                  _buildTestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}