// lib/pages/admin/admin_evaluations_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart'; // استيراد مكتبة الرسوم البيانية

// استيراد النماذج والإعدادات ومربع الحوار
import '../../models/evaluation_models.dart'; // تم تحديث هذا الملف
import 'evaluation_settings_dialog.dart';
import '../../main.dart'; // لاستخدام دوال الإشعارات getAdminUids

// تأكد من وجود هذا الملف في مشروعك بنفس المسار أو قم بتعديله.
// lib/config/app_constants.dart
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB); // Modern blue
  static const Color primaryLight = Color(0xFF3B82F6); // Lighter blue
  static const Color primaryDark = Color(0xFF1976D2);

  static const Color successColor = Color(0xFF66BB6A); // أخضر
  static const Color errorColor = Color(0xFFEF5350);   // أحمر
  static const Color warningColor = Color(0xFFFFCA28); // أصفر
  static const Color infoColor = Color(0xFF26C6DA);    // أزرق سماوي

  static const Color backgroundColor = Color(0xFFF5F5F5); // خلفية فاتحة
  static const Color cardColor = Colors.white;         // لون البطاقات

  static const Color textPrimary = Color(0xFF333333);  // لون النص الأساسي
  static const Color textSecondary = Color(0xFF757575); // لون النص الثانوي
  static const Color dividerColor = Color(0xFFEEEEEE); // لون الخط الفاصل

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  static const double itemSpacing = 16.0; // تباعد قياسي بين العناصر

  static const double borderRadius = 12.0; // حواف دائرية قياسية

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
}


class AdminEvaluationsPage extends StatefulWidget {
  const AdminEvaluationsPage({super.key});

  @override
  State<AdminEvaluationsPage> createState() => _AdminEvaluationsPageState();
}

class _AdminEvaluationsPageState extends State<AdminEvaluationsPage> {
  String? _selectedEngineerId;
  List<DocumentSnapshot> _engineers = [];
  String _selectedPeriodType = 'monthly'; // 'monthly', 'yearly'
  DateTime _selectedDate = DateTime.now(); // لليوم أو الشهر أو السنة المحددة
  EvaluationSettings? _evaluationSettings;
  bool _isLoadingInitialData = true;
  bool _isProcessingManualEvaluation = false;


  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoadingInitialData = true);
    await Future.wait([
      _loadEngineers(),
      _loadEvaluationSettings(),
    ]);
    if (mounted) {
      setState(() => _isLoadingInitialData = false);
    }
  }

  Future<void> _loadEngineers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['engineer', 'employee'])
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _engineers = snapshot.docs;
          if (_selectedEngineerId == null && _engineers.isNotEmpty) {
            _selectedEngineerId = _engineers.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة الموظفين: $e', isError: true);
      }
    }
  }

  Future<void> _loadEvaluationSettings() async {
    try {
      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
          .collection('evaluation_settings')
          .doc('weights')
          .get();

      if (settingsDoc.exists) {
        if (mounted) {
          setState(() {
            _evaluationSettings = EvaluationSettings.fromFirestore(settingsDoc);
          });
        }
      } else {
        // إنشاء إعدادات افتراضية إذا لم تكن موجودة
        final defaultSettings = EvaluationSettings(
          workingHoursWeight: 40.0,
          tasksCompletedWeight: 30.0,
          activityRateWeight: 20.0,
          productivityWeight: 10.0,
          enableMonthlyEvaluation: true,
          enableYearlyEvaluation: false,
          sendNotifications: true,
        );
        await FirebaseFirestore.instance.collection('evaluation_settings').doc('weights').set(defaultSettings.toFirestore());
        if (mounted) {
          setState(() {
            _evaluationSettings = defaultSettings;
          });
        }
      }
    } catch (e) {
      print('Error loading evaluation settings: $e');
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل إعدادات التقييم.', isError: true);
      }
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)), // حواف أكثر دائرية
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
        duration: const Duration(seconds: 3), // مدة عرض أطول قليلاً
      ),
    );
  }

  String _getPeriodIdentifier(DateTime date, String periodType) {
    if (periodType == 'monthly') {
      return DateFormat('yyyy-MM').format(date);
    } else { // yearly
      return DateFormat('yyyy').format(date);
    }
  }

  Future<Map<String, dynamic>> _calculateEvaluationMetrics(String engineerId, DateTime date, String periodType) async {
    double totalWorkingHours = 0.0;
    int completedTasks = 0;
    int totalEntries = 0;

    DateTime startPeriod, endPeriod;
    if (periodType == 'monthly') {
      startPeriod = DateTime(date.year, date.month, 1);
      endPeriod = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    } else { // yearly
      startPeriod = DateTime(date.year, 1, 1);
      endPeriod = DateTime(date.year, 12, 31, 23, 59, 59);
    }

    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('userId', isEqualTo: engineerId)
        .where('timestamp', isGreaterThanOrEqualTo: startPeriod)
        .where('timestamp', isLessThanOrEqualTo: endPeriod)
        .orderBy('timestamp', descending: false)
        .get();

    DateTime? checkInTime;
    for (var doc in attendanceSnapshot.docs) {
      final record = doc.data();
      final type = record['type'] as String?;
      final timestamp = (record['timestamp'] as Timestamp?)?.toDate();

      if (type == 'check_in' && timestamp != null) {
        checkInTime = timestamp;
      } else if (type == 'check_out' && timestamp != null && checkInTime != null) {
        totalWorkingHours += timestamp.difference(checkInTime).inMinutes / 60.0;
        checkInTime = null;
      }
    }

    final projectsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .where('engineerUids', arrayContains: engineerId)
        .get();

    for (var projectDoc in projectsSnapshot.docs) {
      final projectId = projectDoc.id;

      final subPhasesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('subphases_status')
          .where('lastUpdatedByUid', isEqualTo: engineerId)
          .where('completed', isEqualTo: true)
          .get();
      completedTasks += subPhasesSnapshot.docs.where((doc) {
        final timestamp = (doc.data()['lastUpdatedAt'] as Timestamp?)?.toDate();
        return timestamp != null && timestamp.isAfter(startPeriod) && timestamp.isBefore(endPeriod);
      }).length;

      final testsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('tests_status')
          .where('lastUpdatedByUid', isEqualTo: engineerId)
          .where('completed', isEqualTo: true)
          .get();
      completedTasks += testsSnapshot.docs.where((doc) {
        final timestamp = (doc.data()['lastUpdatedAt'] as Timestamp?)?.toDate();
        return timestamp != null && timestamp.isAfter(startPeriod) && timestamp.isBefore(endPeriod);
      }).length;

      final mainPhaseEntriesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('phases_status')
          .get();
      for(var mainPhaseDoc in mainPhaseEntriesSnapshot.docs) {
        final entries = await mainPhaseDoc.reference.collection('entries')
            .where('engineerUid', isEqualTo: engineerId)
            .get();
        totalEntries += entries.docs.where((doc) {
          final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null && timestamp.isAfter(startPeriod) && timestamp.isBefore(endPeriod);
        }).length;
      }

      final subPhaseEntriesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('subphases_status')
          .get();
      for(var subPhaseDoc in subPhaseEntriesSnapshot.docs) {
        final entries = await subPhaseDoc.reference.collection('entries')
            .where('engineerUid', isEqualTo: engineerId)
            .get();
        totalEntries += entries.docs.where((doc) {
          final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null && timestamp.isAfter(startPeriod) && timestamp.isBefore(endPeriod);
        }).length;
      }
    }

    double targetWorkingHours = periodType == 'monthly' ? 160.0 : 1920.0;
    int targetTasks = periodType == 'monthly' ? 10 : 120;
    int targetEntries = periodType == 'monthly' ? 50 : 600;

    double workingHoursScore = (totalWorkingHours / targetWorkingHours).clamp(0.0, 1.0) * 100;
    double tasksCompletedScore = (completedTasks / targetTasks).clamp(0.0, 1.0) * 100;
    double activityRateScore = (totalEntries / targetEntries).clamp(0.0, 1.0) * 100;
    double productivityScore = ((completedTasks / (totalWorkingHours > 0 ? totalWorkingHours : 1)) / (targetTasks / targetWorkingHours)).clamp(0.0, 1.0) * 100;

    return {
      'rawMetrics': {
        'actualWorkingHours': totalWorkingHours,
        'completedTasks': completedTasks,
        'totalEntries': totalEntries,
      },
      'criteriaScores': {
        'workingHours': workingHoursScore,
        'tasksCompleted': tasksCompletedScore,
        'activityRate': activityRateScore,
        'productivity': productivityScore,
      },
    };
  }

  Future<void> _triggerManualEvaluation() async {
    if (_selectedEngineerId == null) {
      _showFeedbackSnackBar(context, 'الرجاء اختيار موظف للتقييم.', isError: true);
      return;
    }
    if (_evaluationSettings == null) {
      _showFeedbackSnackBar(context, 'إعدادات التقييم غير محملة.', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _isProcessingManualEvaluation = true);

    try {
      final engineerData = _engineers.firstWhere((doc) => doc.id == _selectedEngineerId).data() as Map<String, dynamic>?;
      final engineerName = engineerData?['name'] as String? ?? 'غير معروف';
      final periodIdentifier = _getPeriodIdentifier(_selectedDate, _selectedPeriodType);

      final metrics = await _calculateEvaluationMetrics(_selectedEngineerId!, _selectedDate, _selectedPeriodType);

      final criteriaScores = metrics['criteriaScores'] as Map<String, double>? ?? {};
      final rawMetrics = metrics['rawMetrics'] as Map<String, dynamic>? ?? {};

      double totalScore = (
          (criteriaScores['workingHours']! * (_evaluationSettings?.workingHoursWeight ?? 0.0)) +
              (criteriaScores['tasksCompleted']! * (_evaluationSettings?.tasksCompletedWeight ?? 0.0)) +
              (criteriaScores['activityRate']! * (_evaluationSettings?.activityRateWeight ?? 0.0)) +
              (criteriaScores['productivity']! * (_evaluationSettings?.productivityWeight ?? 0.0))
      ) / 100;

      final evaluationDocId = '${_selectedEngineerId}_$periodIdentifier';

      await FirebaseFirestore.instance.collection('evaluations').doc(evaluationDocId).set(
        EngineerEvaluation(
          engineerId: _selectedEngineerId!,
          engineerName: engineerName,
          periodType: _selectedPeriodType,
          periodIdentifier: periodIdentifier,
          totalScore: totalScore.clamp(0.0, 100.0),
          criteriaScores: criteriaScores,
          rawMetrics: rawMetrics,
          evaluationDate: DateTime.now(),
        ).toFirestore(),
        SetOptions(merge: true),
      );

      _showFeedbackSnackBar(context, 'تم إجراء التقييم يدوياً بنجاح.', isError: false);

      if (_evaluationSettings?.sendNotifications ?? false) {
        // تأكد من وجود دالة sendNotification في AppConstants أو مكان آخر يمكن الوصول إليه
        // وإلا قد تحتاج إلى إعادة هيكلة هذه الدالة أو تضمينها هنا.
        // مثال افتراضي:
        // await AppConstants.sendNotification(
        await sendNotification(
          recipientUserId: _selectedEngineerId!,
          title: "تم إصدار تقييم جديد",
          body: "تم إصدار تقييم أدائك ${ _selectedPeriodType == 'monthly' ? 'للشهر' : 'للسنة' } $periodIdentifier. النتيجة: ${totalScore.toStringAsFixed(1)}%",
          type: "engineer_evaluation",
          itemId: evaluationDocId,
          senderName: "نظام التقييم",
        );
      }
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل إجراء التقييم اليدوي: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingManualEvaluation = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoadingInitialData
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : Column(
          children: [
            _buildFiltersAndActions(),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: (_selectedEngineerId != null && _getPeriodIdentifier(_selectedDate, _selectedPeriodType).isNotEmpty) ?
                FirebaseFirestore.instance
                    .collection('evaluations')
                    .doc('${_selectedEngineerId}_${_getPeriodIdentifier(_selectedDate, _selectedPeriodType)}')
                    .snapshots() : null,
                builder: (context, snapshot) {
                  if (_selectedEngineerId == null) {
                    // شاشة الترحيب والتوجيه الجديدة
                    return _buildWelcomeAndGuidanceState();
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState('حدث خطأ في تحميل التقييم: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return _buildEmptyState('لا توجد بيانات تقييم للموظف في الفترة المحددة.', icon: Icons.person_off_rounded);
                  }

                  final evaluation = EngineerEvaluation.fromFirestore(snapshot.data!);
                  return _buildEvaluationDetails(evaluation);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'لوحة تقييم الموظفين',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),      ),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConstants.primaryDark, AppConstants.primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 8,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 28),
          tooltip: 'إعدادات التقييم',
          onPressed: _showEvaluationSettingsDialog,
        ),
        const SizedBox(width: AppConstants.paddingSmall),
      ],
    );
  }

  Widget _buildFiltersAndActions() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Card(
        elevation: AppConstants.cardShadow[0].blurRadius + 2, // ظل أوضح للبطاقة
        shadowColor: AppConstants.primaryColor.withOpacity(0.15), // ظل أقوى
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge), // مسافة داخلية أكبر
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // لمحاذاة العناوين لليمين
            children: [

              // اختيار الموظف
              _buildStyledDropdown<String>(
                hint: _engineers.isEmpty ? 'لا يوجد موظفون متاحون' : 'اختر الموظف للتقييم',
                value: _selectedEngineerId,
                items: _engineers.map((doc) {
                  final user = doc.data() as Map<String, dynamic>?;
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(user?['name'] ?? 'موظف غير مسمى'),
                  );
                }).toList(),
                onChanged: _engineers.isEmpty ? null : (value) {
                  if (mounted) {
                    setState(() => _selectedEngineerId = value);
                  }
                },
                icon: Icons.engineering_rounded,
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              // اختيار نوع الفترة (شهري/سنوي)
              Row(
                children: [
                  Expanded(
                    child: _buildStyledDropdown<String>(
                      hint: 'نوع فترة التقييم',
                      value: _selectedPeriodType,
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                        DropdownMenuItem(value: 'yearly', child: Text('سنوي')),
                      ],
                      onChanged: (value) {
                        if (mounted) {
                          setState(() => _selectedPeriodType = value ?? 'monthly');
                        }
                      },
                      icon: Icons.calendar_today_rounded,
                    ),
                  ),
                  const SizedBox(width: AppConstants.itemSpacing),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateForPeriod(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تاريخ الفترة',
                          labelStyle: const TextStyle(color: AppConstants.textSecondary),
                          prefixIcon: const Icon(Icons.date_range_rounded, color: AppConstants.primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                          ),
                          filled: true,
                          fillColor: AppConstants.cardColor.withOpacity(0.8), // لون تعبئة أوضح
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedPeriodType == 'monthly'
                                  ? DateFormat('MMMM yyyy', 'ar').format(_selectedDate) // تنسيق الشهر والسنة
                                  : DateFormat('yyyy', 'ar').format(_selectedDate),
                              style: const TextStyle(fontSize: 16, color: AppConstants.textPrimary, fontWeight: FontWeight.w500),
                            ),
                            const Icon(Icons.calendar_month_rounded, color: AppConstants.primaryColor), // أيقونة أوضح
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.itemSpacing * 1.5), // مسافة أكبر قبل الزر
              ElevatedButton.icon(
                onPressed: _selectedEngineerId == null || _isProcessingManualEvaluation
                    ? null
                    : _triggerManualEvaluation,
                icon: _isProcessingManualEvaluation
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
                    : const Icon(Icons.bar_chart_rounded, color: Colors.white),
                label: Text(
                  _isProcessingManualEvaluation
                      ? 'جاري إنشاء التقييم...'
                      : 'إنشاء تقييم يدوي الآن',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  minimumSize: const Size(double.infinity, 50), // ارتفاع أكبر للزر
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged, // يمكن أن يكون null
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
        labelStyle: const TextStyle(color: AppConstants.textSecondary),
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: AppConstants.cardColor.withOpacity(0.8), // لون تعبئة أوضح
      ),
      isExpanded: true,
    );
  }

  Future<void> _selectDateForPeriod(BuildContext context) async {
    if (_selectedPeriodType == 'monthly') {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppConstants.primaryColor,
                onPrimary: Colors.white,
                onSurface: AppConstants.textPrimary,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: AppConstants.primaryColor),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    } else { // yearly
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("اختر السنة"),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 5)),
                selectedDate: _selectedDate,
                onChanged: (DateTime pickedDate) {
                  if (mounted) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                  }
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildEvaluationDetails(EngineerEvaluation evaluation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        children: [
          _buildOverallScoreCard(evaluation.totalScore, evaluation.evaluationDate),
          const SizedBox(height: AppConstants.itemSpacing * 1.5), // تباعد أكبر
          _buildCriteriaScoresCard(evaluation.criteriaScores),
          const SizedBox(height: AppConstants.itemSpacing * 1.5), // تباعد أكبر
          _buildRawMetricsCard(evaluation.rawMetrics),
          const SizedBox(height: AppConstants.itemSpacing * 1.5), // تباعد أكبر
          _buildHistoricalPerformanceChart(evaluation.engineerId, evaluation.periodType),
        ],
      ),
    );
  }

  Widget _buildOverallScoreCard(double score, DateTime evaluationDate) {
    String feedback;
    Color color;
    if (score >= 90) {
      feedback = 'ممتاز جداً';
      color = AppConstants.successColor;
    } else if (score >= 80) {
      feedback = 'ممتاز';
      color = Colors.lightGreen;
    } else if (score >= 70) {
      feedback = 'جيد جداً';
      color = AppConstants.infoColor;
    } else if (score >= 60) {
      feedback = 'جيد';
      color = AppConstants.warningColor;
    } else {
      feedback = 'بحاجة لتحسين';
      color = AppConstants.errorColor;
    }

    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius + 2, // ظل أوضح
      shadowColor: color.withOpacity(0.3), // ظل أقوى
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius + 4)), // حواف أكثر دائرية
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge * 1.2), // مسافة داخلية أكبر
        child: Column(
          children: [
            const Text(
              'التقييم العام للموظف',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            const SizedBox(height: AppConstants.itemSpacing * 1.5),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160, // حجم أكبر للدائرة
                  height: 160,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12, // سمك أكبر للدائرة
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '${score.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)), // حجم خط أكبر
                ),
              ],
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(
              feedback,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'تاريخ التقييم: ${DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(evaluationDate)}', // تنسيق تاريخ أوضح
              style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaScoresCard(Map<String, double> criteriaScores) {
    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقييم المعايير الفردية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            const Divider(height: AppConstants.itemSpacing * 1.5),
            _buildCriterionRow('ساعات العمل:', criteriaScores['workingHours'] ?? 0.0),
            _buildCriterionRow('المهام المكتملة:', criteriaScores['tasksCompleted'] ?? 0.0),
            _buildCriterionRow('معدل النشاط:', criteriaScores['activityRate'] ?? 0.0),
            _buildCriterionRow('الإنتاجية العامة:', criteriaScores['productivity'] ?? 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildCriterionRow(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppConstants.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(score > 70 ? AppConstants.successColor : AppConstants.warningColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          Text(
            '${score.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildRawMetricsCard(Map<String, dynamic> rawMetrics) {
    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المقاييس الأولية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            const Divider(height: AppConstants.itemSpacing * 1.5),
            _buildRawMetricRow('ساعات العمل الفعلية:', '${rawMetrics['actualWorkingHours']?.toStringAsFixed(1) ?? '0.0'} ساعة'),
            _buildRawMetricRow('المهام المكتملة:', '${rawMetrics['completedTasks']?.toString() ?? '0'} مهمة'),
            _buildRawMetricRow('عدد الإدخالات/النشاط:', '${rawMetrics['totalEntries']?.toString() ?? '0'} إدخال'),
          ],
        ),
      ),
    );
  }

  Widget _buildRawMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalPerformanceChart(String engineerId, String periodType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('evaluations')
          .where('engineerId', isEqualTo: engineerId)
          .where('periodType', isEqualTo: periodType)
          .orderBy('evaluationDate', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
          );
        }
        if (snapshot.hasError) {
          return _buildErrorState('فشل تحميل الأداء التاريخي: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد بيانات تاريخية كافية لعرض الرسم البياني.', icon: Icons.bar_chart_outlined);
        }

        final List<EngineerEvaluation> evaluations = snapshot.data!.docs
            .map((doc) => EngineerEvaluation.fromFirestore(doc))
            .toList()
            .reversed
            .toList();

        if (evaluations.length < 2) {
          return _buildEmptyState(
            'تحتاج إلى تقييمين على الأقل لعرض الرسم البياني التاريخي لأداء الموظف.',
            icon: Icons.timeline_rounded,
          );
        }

        return Card(
          elevation: AppConstants.cardShadow[0].blurRadius,
          shadowColor: AppConstants.primaryColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأداء التاريخي (آخر 6 فترات)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                ),
                const Divider(height: AppConstants.itemSpacing * 1.5),
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 20,
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: AppConstants.dividerColor,
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return const FlLine(
                            color: AppConstants.dividerColor,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < evaluations.length) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8.0,
                                  child: Text(
                                    periodType == 'monthly'
                                        ? DateFormat('MMM yy', 'ar').format(evaluations[index].evaluationDate)
                                        : DateFormat('yyyy', 'ar').format(evaluations[index].evaluationDate),
                                    style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 25,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: AppConstants.dividerColor, width: 1),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(evaluations.length, (i) {
                            return FlSpot(i.toDouble(), evaluations[i].totalScore);
                          }),
                          isCurved: true,
                          color: AppConstants.primaryColor,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 4,
                              color: AppConstants.primaryDark,
                              strokeWidth: 1.5,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppConstants.primaryColor.withOpacity(0.4),
                                AppConstants.primaryLight.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      minX: 0,
                      maxX: (evaluations.length - 1).toDouble(),
                      minY: 0,
                      maxY: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // شاشة الترحيب والتوجيه الجديدة
  Widget _buildWelcomeAndGuidanceState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_rounded, size: 100, color: AppConstants.primaryColor.withOpacity(0.6)),
            const SizedBox(height: AppConstants.itemSpacing * 2),
            Text(
              'مرحباً بك في لوحة تقييم الأداء',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(
              'للبدء، يرجى اختيار موظف من القائمة أعلاه ثم تحديد الفترة الزمنية (شهرية أو سنوية) لعرض أو إنشاء التقييم الخاص به.',
              style: TextStyle(fontSize: 16, color: AppConstants.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.itemSpacing * 2),
            ElevatedButton.icon(
              onPressed: () {
                // يمكن هنا فتح قائمة الموظفين بشكل تلقائي أو توجيه المستخدم
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('الرجاء استخدام قائمة "اختر الموظف للتقييم" في الأعلى.'),
                    backgroundColor: AppConstants.infoColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                    margin: const EdgeInsets.all(AppConstants.paddingMedium),
                  ),
                );
              },
              icon: Icon(Icons.arrow_upward_rounded, color: Colors.white),
              label: Text('ابدأ باختيار موظف', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {IconData icon = Icons.info_outline}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppConstants.textSecondary.withOpacity(0.4)),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(
              message,
              style: const TextStyle(fontSize: 18, color: AppConstants.textSecondary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 70, color: AppConstants.errorColor),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.textPrimary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _showEvaluationSettingsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: EvaluationSettingsDialog(
          currentSettings: _evaluationSettings ?? EvaluationSettings(
            workingHoursWeight: 40.0, tasksCompletedWeight: 30.0,
            activityRateWeight: 20.0, productivityWeight: 10.0,
            enableMonthlyEvaluation: true, enableYearlyEvaluation: false,
            sendNotifications: true,
          ),
        ),
      ),
    );

    if (result == true) {
      _loadEvaluationSettings(); // إعادة تحميل الإعدادات بعد الحفظ
    }
  }
}