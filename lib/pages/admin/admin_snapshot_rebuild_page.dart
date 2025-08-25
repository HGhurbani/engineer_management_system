import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../theme/app_constants.dart';

class AdminSnapshotRebuildPage extends StatefulWidget {
  const AdminSnapshotRebuildPage({Key? key}) : super(key: key);

  @override
  State<AdminSnapshotRebuildPage> createState() => _AdminSnapshotRebuildPageState();
}

class _AdminSnapshotRebuildPageState extends State<AdminSnapshotRebuildPage> {
  bool _isLoading = false;
  bool _isLoadingProjects = false;
  List<Map<String, dynamic>> _projects = [];
  List<String> _selectedProjects = [];
  Map<String, Map<String, dynamic>> _projectStatus = {};
  String? _lastOperationResult;
  bool _showDiagnosticInfo = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoadingProjects = true);
    
    try {
      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .orderBy('name')
          .get();
      
      final projects = <Map<String, dynamic>>[];
      
      for (final doc in projectsSnapshot.docs) {
        final projectData = doc.data();
        projects.add({
          'id': doc.id,
          'name': projectData['name'] ?? 'غير مسمى',
          'clientName': projectData['clientName'] ?? 'غير معروف',
          'createdAt': projectData['createdAt'],
        });
      }
      
      setState(() {
        _projects = projects;
      });
      
      // فحص شامل لحالة Snapshots للمشاريع
      await _comprehensiveProjectsCheck();
      
    } catch (e) {
      _showErrorDialog('خطأ في تحميل المشاريع: $e');
    } finally {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _comprehensiveProjectsCheck() async {
    final status = <String, Map<String, dynamic>>{};
    
    try {
      // استخدام الدالة الجديدة للفحص الشامل
      final result = await FirebaseFunctions.instance
          .httpsCallable('comprehensiveProjectCheck')
          .call();
      
      if (result.data['success']) {
        final results = result.data['results'] as List;
        
        for (final projectResult in results) {
          status[projectResult['projectId']] = {
            'hasSnapshot': projectResult['hasSnapshot'],
            'hasData': projectResult['hasData'],
            'needsRebuild': projectResult['needsRebuild'],
            'rebuildReason': projectResult['rebuildReason'],
            'dataSummary': projectResult['dataSummary'],
            'collections': projectResult['collections'],
            'snapshotInfo': projectResult['snapshotInfo'],
            'diagnosticInfo': projectResult['diagnosticInfo'],
          };
        }
        
        // عرض إحصائيات عامة
        _showSuccessDialog(
          'تم فحص جميع المشاريع بنجاح\n\n'
          'إجمالي المشاريع: ${result.data['totalProjects']}\n'
          'المشاريع التي تحتوي على بيانات: ${result.data['projectsWithData']}\n'
          'المشاريع التي تحتوي على snapshots: ${result.data['projectsWithSnapshots']}\n'
          'المشاريع التي تحتاج إعادة بناء: ${result.data['projectsNeedingRebuild']}'
        );
      }
    } catch (e) {
      // إذا فشلت الدالة الجديدة، استخدم الطريقة القديمة
      print('Comprehensive check failed, falling back to individual checks: $e');
      await _checkProjectsSnapshots();
    }
    
    setState(() {
      _projectStatus = status;
    });
  }

  Future<void> _checkProjectsSnapshots() async {
    final status = <String, Map<String, dynamic>>{};
    
    for (final project in _projects) {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('checkSingleProjectSnapshot')
            .call({'projectId': project['id']});
        
        if (result.data['success']) {
          status[project['id']] = {
            'hasSnapshot': result.data['hasSnapshot'],
            'snapshotDate': result.data['snapshotDate'],
            'actualData': result.data['actualData'],
            'snapshotData': result.data['snapshotData'],
            'needsRebuild': _needsRebuild(result.data),
          };
        }
      } catch (e) {
        status[project['id']] = {
          'hasSnapshot': false,
          'error': e.toString(),
          'needsRebuild': true,
        };
      }
    }
    
    setState(() {
      _projectStatus = status;
    });
  }

  bool _needsRebuild(Map<String, dynamic> data) {
    if (!data['hasSnapshot']) return true;
    
    final actualData = data['actualData'];
    final snapshotData = data['snapshotData'];
    
    if (snapshotData == null) return true;
    
    // فحص إذا كانت البيانات الفعلية مختلفة عن Snapshot
    return actualData['entries'] != snapshotData['entries'] ||
           actualData['tests'] != snapshotData['tests'] ||
           actualData['materials'] != snapshotData['materials'];
  }

  Future<void> _rebuildAllSnapshots() async {
    final confirm = await _showConfirmDialog(
      'إعادة بناء جميع Snapshots',
      'هل أنت متأكد من إعادة بناء Snapshots لجميع المشاريع؟ قد تستغرق هذه العملية وقتاً طويلاً.',
    );
    
    if (!confirm) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('rebuildAllSnapshots')
          .call();
      
      if (result.data['success']) {
        setState(() {
          _lastOperationResult = result.data['message'];
        });
        _showSuccessDialog(result.data['message']);
        await _checkProjectsSnapshots();
      } else {
        _showErrorDialog('فشل في إعادة بناء Snapshots');
      }
    } catch (e) {
      _showErrorDialog('خطأ في إعادة بناء Snapshots: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rebuildSelectedSnapshots() async {
    if (_selectedProjects.isEmpty) {
      _showErrorDialog('يرجى اختيار مشروع واحد على الأقل');
      return;
    }
    
    final confirm = await _showConfirmDialog(
      'إعادة بناء Snapshots المحددة',
      'هل أنت متأكد من إعادة بناء Snapshots للمشاريع المحددة (${_selectedProjects.length} مشروع)؟',
    );
    
    if (!confirm) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('rebuildSelectedSnapshots')
          .call({'projectIds': _selectedProjects});
      
      if (result.data['success']) {
        setState(() {
          _lastOperationResult = result.data['message'];
        });
        _showSuccessDialog(result.data['message']);
        await _checkProjectsSnapshots();
      } else {
        _showErrorDialog('فشل في إعادة بناء Snapshots');
      }
    } catch (e) {
      _showErrorDialog('خطأ في إعادة بناء Snapshots: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectProjectsNeedingRebuild() {
    final needingRebuild = _projects
        .where((project) => _projectStatus[project['id']]?['needsRebuild'] == true)
        .map((project) => project['id'] as String)
        .toList();
    
    setState(() {
      _selectedProjects = needingRebuild;
    });
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نجح'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة Snapshots التقارير'),
        backgroundColor: AppConstants.primaryColor,
        actions: [
          IconButton(
            icon: Icon(_showDiagnosticInfo ? Icons.info : Icons.info_outline),
            onPressed: () {
              setState(() {
                _showDiagnosticInfo = !_showDiagnosticInfo;
              });
            },
            tooltip: 'إظهار/إخفاء المعلومات التشخيصية',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الأدوات
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _rebuildAllSnapshots,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة بناء الكل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || _selectedProjects.isEmpty 
                            ? null : _rebuildSelectedSnapshots,
                        icon: const Icon(Icons.build),
                        label: Text('إعادة بناء المحدد (${_selectedProjects.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _selectProjectsNeedingRebuild,
                        icon: const Icon(Icons.select_all),
                        label: const Text('اختيار المحتاجة إعادة بناء'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => setState(() => _selectedProjects.clear()),
                        icon: const Icon(Icons.clear),
                        label: const Text('إلغاء التحديد'),
                      ),
                    ),
                  ],
                ),
                if (_lastOperationResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'آخر عملية: $_lastOperationResult',
                      style: TextStyle(color: Colors.green[800]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // قائمة المشاريع
          Expanded(
            child: _isLoadingProjects
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadProjects,
                    child: ListView.builder(
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        final projectId = project['id'];
                        final status = _projectStatus[projectId];
                        final isSelected = _selectedProjects.contains(projectId);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: _isLoading ? null : (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedProjects.add(projectId);
                                } else {
                                  _selectedProjects.remove(projectId);
                                }
                              });
                            },
                            title: Text(
                              project['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('العميل: ${project['clientName']}'),
                                const SizedBox(height: 4),
                                if (status != null) ...[
                                  _buildStatusRow('حالة Snapshot:', 
                                      status['hasSnapshot'] ? 'موجود' : 'غير موجود',
                                      status['hasSnapshot'] ? Colors.green : Colors.red),
                                  if (status['hasSnapshot'] && status['snapshotInfo'] != null)
                                    _buildStatusRow('تاريخ Snapshot:', 
                                        _formatDate(status['snapshotInfo']['generatedAt']),
                                        Colors.grey),
                                  if (status['dataSummary'] != null) ...[
                                    _buildStatusRow('البيانات الفعلية:', 
                                        'إدخالات: ${status['dataSummary']['totalEntries']}, مراحل: ${status['dataSummary']['totalPhases']}, اختبارات: ${status['dataSummary']['totalTests']}, مواد: ${status['dataSummary']['totalMaterials']}',
                                        Colors.blue),
                                    if (status['snapshotInfo'] != null)
                                      _buildStatusRow('بيانات Snapshot:', 
                                          'إدخالات: ${status['snapshotInfo']['totalEntries']}, اختبارات: ${status['snapshotInfo']['totalTests']}, مواد: ${status['snapshotInfo']['totalMaterials']}',
                                          Colors.orange),
                                  ],
                                  if (status['needsRebuild'] == true)
                                    _buildStatusRow('الحالة:', 'يحتاج إعادة بناء', Colors.red),
                                  if (status['rebuildReason'] != null)
                                    _buildStatusRow('سبب إعادة البناء:', status['rebuildReason'], Colors.red),
                                  if (_showDiagnosticInfo && status['collections'] != null) ...[
                                    _buildStatusRow('المجموعات:', '${status['collections'].length} مجموعة تحتوي على بيانات', Colors.purple),
                                    if (status['collections'].isNotEmpty)
                                      ...status['collections'].take(3).map((collection) => 
                                        _buildStatusRow('  - ${collection['name']}:', '${collection['documentCount']} مستند', const Color.fromARGB(255, 113, 113, 113))
                                      ).toList(),
                                  ],
                                ] else ...[
                                  _buildStatusRow('الحالة:', 'جاري الفحص...', Colors.grey),
                                ],
                              ],
                            ),
                            secondary: status?['needsRebuild'] == true 
                                ? Icon(Icons.warning, color: Colors.orange[700])
                                : status?['hasSnapshot'] == true 
                                    ? Icon(Icons.check_circle, color: Colors.green[700])
                                    : Icon(Icons.error, color: Colors.red[700]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          
          // شريط التحميل
          if (_isLoading)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'غير معروف';
    
    try {
      final date = timestamp is Timestamp 
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }
}
