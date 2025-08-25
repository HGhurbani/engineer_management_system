import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/report_snapshot_manager.dart';
import '../../utils/enhanced_pdf_generator.dart';
import '../../utils/smart_report_cache_manager.dart';
import '../../utils/advanced_cache_manager.dart';

class AdminSnapshotManagementPage extends StatefulWidget {
  const AdminSnapshotManagementPage({Key? key}) : super(key: key);

  @override
  State<AdminSnapshotManagementPage> createState() => _AdminSnapshotManagementPageState();
}

class _AdminSnapshotManagementPageState extends State<AdminSnapshotManagementPage> {
  bool _isLoading = false;
  String _currentStatus = '';
  double _currentProgress = 0.0;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _snapshotStats = [];
  bool _isCreatingSnapshots = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadSnapshotStats();
  }

  /// تحميل جميع المشاريع
  Future<void> _loadProjects() async {
    try {
      setState(() {
        _isLoading = true;
        _currentStatus = 'جاري تحميل المشاريع...';
      });

      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .get();

      _projects = projectsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'مشروع غير مسمى',
          'clientName': data['clientName'] ?? 'غير معروف',
          'projectType': data['projectType'] ?? 'غير محدد',
          'status': data['status'] ?? 'غير محدد',
          'createdAt': data['createdAt'],
          'lastUpdated': data['lastUpdated'],
        };
      }).toList();

      setState(() {
        _isLoading = false;
        _currentStatus = 'تم تحميل ${_projects.length} مشروع';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentStatus = 'خطأ في تحميل المشاريع: $e';
      });
    }
  }

  /// تحميل إحصائيات Snapshots
  Future<void> _loadSnapshotStats() async {
    try {
      final stats = await ReportSnapshotManager.getSnapshotStats();
      setState(() {
        _snapshotStats = [
          {'title': 'إجمالي Snapshots', 'value': stats['totalSnapshots']?.toString() ?? '0'},
          {'title': 'Snapshots شاملة', 'value': stats['fullSnapshots']?.toString() ?? '0'},
          {'title': 'Snapshots لفترات محددة', 'value': stats['timeRangeSnapshots']?.toString() ?? '0'},
          {'title': 'إجمالي حجم البيانات', 'value': '${stats['totalDataSize']?.toString() ?? '0'} عنصر'},
        ];
      });
    } catch (e) {
      print('Error loading snapshot stats: $e');
    }
  }

  /// إنشاء Snapshots لجميع المشاريع
  Future<void> _createSnapshotsForAllProjects() async {
    if (_projects.isEmpty) {
      _showSnackBar('لا توجد مشاريع لإنشاء Snapshots لها', isError: true);
      return;
    }

    setState(() {
      _isCreatingSnapshots = true;
      _currentProgress = 0.0;
      _currentStatus = 'بدء إنشاء Snapshots لجميع المشاريع...';
    });

    try {
      // تهيئة أنظمة التخزين المؤقت
      await SmartReportCacheManager.initialize();
      await AdvancedCacheManager.initialize();

      int completedProjects = 0;
      int totalProjects = _projects.length;

      for (final project in _projects) {
        try {
          setState(() {
            _currentStatus = 'جاري إنشاء Snapshot للمشروع: ${project['name']}';
            _currentProgress = completedProjects / totalProjects;
          });

          // إنشاء Snapshot شامل للمشروع
          await _createComprehensiveSnapshot(project['id']);

          completedProjects++;
          setState(() {
            _currentProgress = completedProjects / totalProjects;
          });

          // تأخير قصير لتجنب الضغط على Firebase
          await Future.delayed(const Duration(milliseconds: 500));

        } catch (e) {
          print('Error creating snapshot for project ${project['id']}: $e');
          // الاستمرار مع المشاريع الأخرى
        }
      }

      setState(() {
        _isCreatingSnapshots = false;
        _currentStatus = 'تم إنشاء Snapshots لجميع المشاريع بنجاح!';
        _currentProgress = 1.0;
      });

      _showSnackBar('تم إنشاء Snapshots لجميع المشاريع بنجاح!', isError: false);
      
      // تحديث الإحصائيات
      await _loadSnapshotStats();

    } catch (e) {
      setState(() {
        _isCreatingSnapshots = false;
        _currentStatus = 'حدث خطأ: $e';
      });
      _showSnackBar('حدث خطأ في إنشاء Snapshots: $e', isError: true);
    }
  }

  /// إنشاء Snapshot شامل لمشروع واحد
  Future<void> _createComprehensiveSnapshot(String projectId) async {
    try {
      // استخدام النظام المحسن لإنشاء Snapshot شامل
      final enhancedResult = await EnhancedPdfGenerator.generateComprehensiveReport(
        projectId: projectId,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now(),
        generatedBy: 'النظام الإداري',
        generatedByRole: 'المسؤول',
        onStatusUpdate: (status) {
          // تحديث الحالة للمشروع الحالي
          setState(() {
            _currentStatus = 'جاري إنشاء Snapshot شامل: $status';
          });
        },
        onProgress: (progress) {
          // تحديث التقدم للمشروع الحالي
          setState(() {
            _currentProgress = progress;
          });
        },
        forceRefresh: true, // إجبار إنشاء Snapshot جديد
      );

      // حفظ Snapshot في جدول report_snapshots
      await _saveSnapshotToFirestore(projectId, enhancedResult);

    } catch (e) {
      print('Error creating comprehensive snapshot for project $projectId: $e');
      rethrow;
    }
  }

  /// حفظ Snapshot في Firestore
  Future<void> _saveSnapshotToFirestore(String projectId, dynamic enhancedResult) async {
    try {
      // إنشاء Snapshot شامل
      final snapshot = {
        'projectId': projectId,
        'reportMetadata': {
          'generatedAt': FieldValue.serverTimestamp(),
          'isFullReport': true,
          'totalDataSize': 0, // سيتم تحديثه لاحقاً
          'generatedBy': 'النظام الإداري',
          'generatedByRole': 'المسؤول',
          'snapshotType': 'comprehensive',
          'version': '2.0',
        },
        'phasesData': [],
        'testsData': [],
        'materialsData': [],
        'imagesData': [],
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // حفظ في جدول report_snapshots
      await FirebaseFirestore.instance
          .collection('report_snapshots')
          .doc(projectId)
          .set(snapshot, SetOptions(merge: true));

      print('Snapshot saved successfully for project: $projectId');

    } catch (e) {
      print('Error saving snapshot to Firestore: $e');
      rethrow;
    }
  }

  /// إنشاء Snapshots لفترات زمنية محددة
  Future<void> _createTimeRangeSnapshots() async {
    if (_projects.isEmpty) {
      _showSnackBar('لا توجد مشاريع لإنشاء Snapshots لها', isError: true);
      return;
    }

    setState(() {
      _isCreatingSnapshots = true;
      _currentStatus = 'إنشاء Snapshots لفترات زمنية محددة...';
    });

    try {
      final now = DateTime.now();
      final periods = [
        {'name': 'آخر أسبوع', 'start': now.subtract(const Duration(days: 7)), 'end': now},
        {'name': 'آخر شهر', 'start': now.subtract(const Duration(days: 30)), 'end': now},
        {'name': 'آخر 3 أشهر', 'start': now.subtract(const Duration(days: 90)), 'end': now},
      ];

      int totalSnapshots = _projects.length * periods.length;
      int completedSnapshots = 0;

      for (final project in _projects) {
        for (final period in periods) {
          try {
            setState(() {
              _currentStatus = 'إنشاء Snapshot للمشروع: ${project['name']} - ${period['name']}';
              _currentProgress = completedSnapshots / totalSnapshots;
            });

            // إنشاء Snapshot للفترة الزمنية
            await _createTimeRangeSnapshot(
              project['id'],
              period['start'] as DateTime,
              period['end'] as DateTime,
              period['name'] as String,
            );

            completedSnapshots++;
            setState(() {
              _currentProgress = completedSnapshots / totalSnapshots;
            });

            // تأخير قصير
            await Future.delayed(const Duration(milliseconds: 300));

          } catch (e) {
            print('Error creating time range snapshot: $e');
          }
        }
      }

      setState(() {
        _isCreatingSnapshots = false;
        _currentStatus = 'تم إنشاء Snapshots للفترات الزمنية بنجاح!';
        _currentProgress = 1.0;
      });

      _showSnackBar('تم إنشاء Snapshots للفترات الزمنية بنجاح!', isError: false);
      await _loadSnapshotStats();

    } catch (e) {
      setState(() {
        _isCreatingSnapshots = false;
        _currentStatus = 'حدث خطأ: $e';
      });
      _showSnackBar('حدث خطأ في إنشاء Snapshots للفترات الزمنية: $e', isError: true);
    }
  }

  /// إنشاء Snapshot لفترة زمنية محددة
  Future<void> _createTimeRangeSnapshot(
    String projectId,
    DateTime startDate,
    DateTime endDate,
    String periodName,
  ) async {
    try {
      // استخدام ReportSnapshotManager لإنشاء Snapshot
      final snapshot = await ReportSnapshotManager.getReportSnapshot(
        projectId: projectId,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: true,
        onStatusUpdate: (status) {
          setState(() {
            _currentStatus = 'إنشاء Snapshot للفترة $periodName: $status';
          });
        },
        onProgress: (progress) {
          setState(() {
            _currentProgress = progress;
          });
        },
      );

      if (snapshot != null) {
        // حفظ Snapshot في Firestore
        final timeRangeId = '${projectId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
        await FirebaseFirestore.instance
            .collection('report_snapshots')
            .doc(timeRangeId)
            .set({
          ...snapshot,
          'projectId': projectId,
          'periodName': periodName,
          'startDate': startDate,
          'endDate': endDate,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        print('Time range snapshot saved: $timeRangeId');
      }

    } catch (e) {
      print('Error creating time range snapshot: $e');
      rethrow;
    }
  }

  /// تنظيف Snapshots القديمة
  Future<void> _cleanupOldSnapshots() async {
    try {
      setState(() {
        _currentStatus = 'جاري تنظيف Snapshots القديمة...';
      });

      await ReportSnapshotManager.cleanupOldSnapshots();

      setState(() {
        _currentStatus = 'تم تنظيف Snapshots القديمة بنجاح!';
      });

      _showSnackBar('تم تنظيف Snapshots القديمة بنجاح!', isError: false);
      await _loadSnapshotStats();

    } catch (e) {
      setState(() {
        _currentStatus = 'حدث خطأ في التنظيف: $e';
      });
      _showSnackBar('حدث خطأ في تنظيف Snapshots القديمة: $e', isError: true);
    }
  }

  /// عرض رسالة تأكيد
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة Snapshots التقارير'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إحصائيات عامة
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إحصائيات Snapshots',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: _snapshotStats.map((stat) {
                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                stat['value'] ?? '0',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                stat['title'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingSnapshots ? null : _createSnapshotsForAllProjects,
                    icon: const Icon(Icons.create),
                    label: const Text('إنشاء Snapshots شاملة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingSnapshots ? null : _createTimeRangeSnapshots,
                    icon: const Icon(Icons.schedule),
                    label: const Text('إنشاء Snapshots للفترات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingSnapshots ? null : _cleanupOldSnapshots,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('تنظيف Snapshots القديمة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingSnapshots ? null : _loadSnapshotStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث الإحصائيات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // شريط التقدم والحالة
            if (_isCreatingSnapshots || _currentStatus.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStatus,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (_isCreatingSnapshots) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _currentProgress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_currentProgress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // قائمة المشاريع
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المشاريع (${_projects.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _projects.length,
                              itemBuilder: (context, index) {
                                final project = _projects[index];
                                return ListTile(
                                  title: Text(project['name'] ?? 'مشروع غير مسمى'),
                                  subtitle: Text(
                                    'العميل: ${project['clientName'] ?? 'غير معروف'} | النوع: ${project['projectType'] ?? 'غير محدد'}',
                                  ),
                                  trailing: Chip(
                                    label: Text(project['status'] ?? 'غير محدد'),
                                    backgroundColor: _getStatusColor(project['status']),
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    // يمكن إضافة عرض تفاصيل المشروع هنا
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// الحصول على لون الحالة
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'مكتمل':
      case 'completed':
        return Colors.green;
      case 'قيد التنفيذ':
      case 'in progress':
        return Colors.orange;
      case 'معلق':
      case 'suspended':
        return Colors.red;
      case 'مخطط':
      case 'planned':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
