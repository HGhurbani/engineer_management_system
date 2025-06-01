// lib/pages/engineer/request_part_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engineer_management_system/pages/engineer/engineer_home.dart'; // For AppConstants
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class RequestPartPage extends StatefulWidget {
  final String engineerId;
  final String engineerName;

  const RequestPartPage({
    super.key,
    required this.engineerId,
    required this.engineerName,
  });

  @override
  State<RequestPartPage> createState() => _RequestPartPageState();
}

class _RequestPartPageState extends State<RequestPartPage> {
  final _formKey = GlobalKey<FormState>();
  final _partNameController = TextEditingController();
  final _quantityController = TextEditingController();

  String? _selectedProjectId;
  String? _selectedProjectName;
  List<DocumentSnapshot> _assignedProjects = [];
  bool _isLoadingProjects = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAssignedProjects();
  }

  Future<void> _fetchAssignedProjects() async {
    if (!mounted) return;
    setState(() => _isLoadingProjects = true);
    try {
      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('engineerUids', arrayContains: widget.engineerId)
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _assignedProjects = projectsSnapshot.docs;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProjects = false);
        _showFeedbackSnackBar('فشل تحميل المشاريع: $e', isError: true);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProjectId == null) {
      _showFeedbackSnackBar('الرجاء اختيار المشروع.', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('partRequests').add({
        'partName': _partNameController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'projectId': _selectedProjectId,
        'projectName': _selectedProjectName,
        'engineerId': widget.engineerId,
        'engineerName': widget.engineerName,
        'status': 'معلق', // Pending
        'requestedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showFeedbackSnackBar('تم إرسال طلب القطعة بنجاح.', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar('فشل إرسال الطلب: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showFeedbackSnackBar(String message, {required bool isError}) {
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

  @override
  void dispose() {
    _partNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلب قطعة جديدة', style: TextStyle(color: Colors.white)),
          backgroundColor: AppConstants.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.primaryColor, AppConstants.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: _isLoadingProjects
            ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
            : Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _partNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم القطعة المطلوبة',
                    prefixIcon: Icon(Icons.settings_input_component_outlined, color: AppConstants.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال اسم القطعة.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'الكمية المطلوبة',
                    prefixIcon: Icon(Icons.format_list_numbered_rtl_outlined, color: AppConstants.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال الكمية.';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'الرجاء إدخال كمية صحيحة أكبر من الصفر.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                if (_assignedProjects.isEmpty && !_isLoadingProjects)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
                    child: Text(
                      'لم يتم تعيينك على أي مشاريع حالياً لطلب قطع لها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppConstants.textSecondary),
                    ),
                  )
                else if (_assignedProjects.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'اختر المشروع',
                      prefixIcon: Icon(Icons.work_outline_rounded, color: AppConstants.primaryColor),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedProjectId,
                    hint: const Text('حدد المشروع'),
                    isExpanded: true,
                    items: _assignedProjects.map((doc) {
                      final projectData = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(projectData['name'] ?? 'مشروع غير مسمى'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final selectedDoc = _assignedProjects.firstWhere((doc) => doc.id == value);
                        final selectedData = selectedDoc.data() as Map<String, dynamic>;
                        setState(() {
                          _selectedProjectId = value;
                          _selectedProjectName = selectedData['name'];
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'الرجاء اختيار المشروع.';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: AppConstants.paddingLarge * 1.5),
                ElevatedButton.icon(
                  onPressed: _isSubmitting || _assignedProjects.isEmpty ? null : _submitRequest,
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: _isSubmitting
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                      : const Text('إرسال الطلب', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                    disabledBackgroundColor: AppConstants.textSecondary.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium / 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}