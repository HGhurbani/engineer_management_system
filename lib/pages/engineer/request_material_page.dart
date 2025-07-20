// lib/pages/engineer/request_material_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:engineer_management_system/pages/engineer/engineer_home.dart'; // For AppConstants
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../../main.dart';
import '../../theme/app_constants.dart';
import '../../models/material_item.dart';

class RequestMaterialPage extends StatefulWidget {
  final String engineerId;
  final String engineerName;
  final String? initialProjectId;
  final String? initialProjectName;

  const RequestMaterialPage({
    super.key,
    required this.engineerId,
    required this.engineerName,
    this.initialProjectId,
    this.initialProjectName,
  });

  @override
  State<RequestMaterialPage> createState() => _RequestMaterialPageState();
}

class _RequestMaterialPageState extends State<RequestMaterialPage> {
  final _formKey = GlobalKey<FormState>();

  /// Controllers for multiple requested items
  final List<TextEditingController> _materialControllers = [TextEditingController()];
  final List<TextEditingController> _quantityControllers = [TextEditingController()];
  final List<MaterialItem?> _selectedMaterials = [null];

  List<MaterialItem> _materials = [];
  bool _loadingMaterials = true;

  String? _selectedProjectId;
  String? _selectedProjectName;
  List<DocumentSnapshot> _assignedProjects = [];
  bool _isLoadingProjects = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProjectId != null) {
      _selectedProjectId = widget.initialProjectId;
      _selectedProjectName = widget.initialProjectName;
      _isLoadingProjects = false;
    } else {
      _fetchAssignedProjects();
    }
    _fetchMaterials();
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

  Future<void> _fetchMaterials() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('materials')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _materials = snap.docs
              .map((d) => MaterialItem.fromFirestore(
                  d.id, d.data() as Map<String, dynamic>))
              .toList();
          _loadingMaterials = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMaterials = false);
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
      // Collect requested items as a list of maps
      final List<Map<String, dynamic>> items = [];
      for (int i = 0; i < _materialControllers.length; i++) {
        final selected = _selectedMaterials.length > i ? _selectedMaterials[i] : null;
        final name = selected != null
            ? selected.name
            : _materialControllers[i].text.trim();
        final qty = int.tryParse(_quantityControllers[i].text.trim()) ?? 1;
        final imageUrl = selected?.imageUrl ?? '';
        items.add({'name': name, 'quantity': qty, 'imageUrl': imageUrl});
      }

      await FirebaseFirestore.instance.collection('partRequests').add({
        // Store first item for backwards compatibility
        'partName': items.isNotEmpty ? items.first['name'] : '',
        'quantity': items.isNotEmpty ? items.first['quantity'] : 0,
        'items': items,
        'projectId': _selectedProjectId,
        'projectName': _selectedProjectName,
        'engineerId': widget.engineerId,
        'engineerName': widget.engineerName,
        'status': 'معلق', // Pending
        'requestedAt': FieldValue.serverTimestamp(),
      });
      final List<String> adminUids = await getAdminUids(); // جلب جميع الـ UIDs للمسؤولين

      if (adminUids.isNotEmpty) {
        final itemSummary = items
            .map((e) => '${e['name']} (${e['quantity']})')
            .join('، ');
        await sendNotificationsToMultiple(
          recipientUserIds: adminUids,
          title: 'طلب مواد جديد',
          body:
              'المهندس ${widget.engineerName} طلب: $itemSummary لمشروع "${_selectedProjectName ?? 'غير محدد'}".',
          type: 'part_request_new',
          projectId: _selectedProjectId,
          itemId: null, // لا يوجد itemId محدد لطلب المواد بعد، يمكن تحديثه لاحقاً
          senderName: widget.engineerName,
        );
      }
      if (mounted) {
        _showFeedbackSnackBar('تم إرسال طلب المواد بنجاح.', isError: false);
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
    for (final c in _materialControllers) {
      c.dispose();
    }
    for (final c in _quantityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلب مواد جديد', style: TextStyle(color: Colors.white)),
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
                ...List.generate(_materialControllers.length, (index) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _loadingMaterials
                                ? const Center(child: CircularProgressIndicator())
                                : Autocomplete<MaterialItem>(
                                    optionsBuilder: (text) {
                                      final q = text.text.toLowerCase();
                                      return _materials.where((m) => m.name.toLowerCase().contains(q));
                                    },
                                    displayStringForOption: (opt) => opt.name,
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      if (_materialControllers.length > index) {
                                        _materialControllers[index] = controller;
                                      }
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'اسم المادة المطلوبة',
                                          prefixIcon: Icon(Icons.settings_input_component_outlined, color: AppConstants.primaryColor),
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'الرجاء إدخال اسم المادة.';
                                          }
                                          return null;
                                        },
                                      );
                                    },
                                    onSelected: (opt) {
                                      if (_selectedMaterials.length > index) {
                                        _selectedMaterials[index] = opt;
                                      }
                                    },
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _quantityControllers[index],
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
                          ),
                          const SizedBox(width: 4),
                          if (_materialControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppConstants.errorColor),
                              onPressed: () {
                                setState(() {
                                  _materialControllers.removeAt(index).dispose();
                                  _quantityControllers.removeAt(index).dispose();
                                  if (_selectedMaterials.length > index) {
                                    _selectedMaterials.removeAt(index);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                    ],
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _materialControllers.add(TextEditingController());
                        _quantityControllers.add(TextEditingController());
                        _selectedMaterials.add(null);
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline, color: AppConstants.primaryColor),
                    label: const Text('إضافة مادة'),
                  ),
                ),
                const SizedBox(height: AppConstants.itemSpacing),
                if (widget.initialProjectId == null &&
                    _assignedProjects.isEmpty &&
                    !_isLoadingProjects)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
                    child: Text(
                      'لم يتم تعيينك على أي مشاريع حالياً لطلب مواد لها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppConstants.textSecondary),
                    ),
                  )
                else if (widget.initialProjectId == null &&
                    _assignedProjects.isNotEmpty)
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
                  onPressed: _isSubmitting ||
                          (widget.initialProjectId == null &&
                              _assignedProjects.isEmpty)
                      ? null
                      : _submitRequest,
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