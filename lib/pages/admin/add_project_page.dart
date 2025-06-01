// lib/pages/admin/add_project_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // --- MODIFICATION: Added ---
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // For TextDirection

// --- MODIFICATION START: Import notification helper functions ---
// Make sure the path to your main.dart (or a dedicated notification service file) is correct.
// If you created a separate service file, import that instead.
import '../../main.dart'; // Assuming helper functions are in main.dart
// --- MODIFICATION END ---


// AppConstants (يفضل أن تكون في ملف مشترك، ولكن للتبسيط نضعها هنا مؤقتاً)
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;
}

class AddProjectPage extends StatefulWidget {
  final List<QueryDocumentSnapshot> availableEngineers;
  final List<QueryDocumentSnapshot> availableClients;

  const AddProjectPage({
    super.key,
    required this.availableEngineers,
    required this.availableClients,
  });

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<String> _selectedEngineerIds = [];
  String? _selectedClientId;
  bool _isLoading = false;

  // --- MODIFICATION START: Variable to store current admin's name ---
  String? _currentAdminName;
  // --- MODIFICATION END ---

  @override
  void initState() { // --- MODIFICATION: Added initState ---
    super.initState();
    _getCurrentAdminName(); // Fetch admin name when the page loads
  }

  // --- MODIFICATION START: Function to get current admin's name ---
  Future<void> _getCurrentAdminName() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (mounted && adminDoc.exists) {
          setState(() {
            _currentAdminName = (adminDoc.data() as Map<String, dynamic>)['name'] ?? 'المسؤول';
          });
        } else {
          if (mounted) {
            setState(() {
              _currentAdminName = 'المسؤول';
            });
          }
        }
      } catch (e) {
        print("Error fetching admin name: $e");
        if (mounted) {
          setState(() {
            _currentAdminName = 'المسؤول'; // Fallback name
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentAdminName = 'المسؤول'; // Fallback if no current user (should not happen if page is protected)
        });
      }
    }
  }
  // --- MODIFICATION END ---


  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showFeedbackSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedEngineerIds.isEmpty && widget.availableEngineers.isNotEmpty) {
      _showFeedbackSnackBar('الرجاء اختيار مهندس واحد على الأقل.', isError: true);
      return;
    }
    if (_selectedClientId == null && widget.availableClients.isNotEmpty) {
      _showFeedbackSnackBar('الرجاء اختيار العميل.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<Map<String, String>> assignedEngineersList = [];
      List<String> engineerUidsList = [];

      if (_selectedEngineerIds.isNotEmpty) {
        for (String engineerId in _selectedEngineerIds) {
          final engineerDoc = widget.availableEngineers.firstWhere(
                (doc) => doc.id == engineerId,
          );
          final engineerData = engineerDoc.data() as Map<String, dynamic>;
          assignedEngineersList.add({
            'uid': engineerId,
            'name': engineerData['name'] ?? 'مهندس غير مسمى',
          });
          engineerUidsList.add(engineerId);
        }
      }

      final clientDoc = widget.availableClients.firstWhere((doc) => doc.id == _selectedClientId);
      final clientData = clientDoc.data() as Map<String, dynamic>;
      final clientName = clientData['name'] ?? 'عميل غير مسمى';
      final String clientType = clientData['clientType'] ?? 'individual';


      // --- MODIFICATION START: Get new project ID and send notifications ---
      DocumentReference projectRef = await FirebaseFirestore.instance.collection('projects').add({
        'name': _nameController.text.trim(),
        'assignedEngineers': assignedEngineersList,
        'engineerUids': engineerUidsList,
        'clientId': _selectedClientId,
        'clientName': clientName,
        'clientType': clientType,
        'currentStage': 0,
        'currentPhaseName': 'لا توجد مراحل بعد',
        'status': 'نشط',
        'createdAt': FieldValue.serverTimestamp(),
        'generalNotes': '',
      });

      String newProjectId = projectRef.id; // Get the ID of the newly created project

      if (engineerUidsList.isNotEmpty) {
        await sendNotificationsToMultiple(
          recipientUserIds: engineerUidsList,
          title: "تم تعيينك لمشروع جديد",
          body: "لقد تم تعيينك لمشروع: ${_nameController.text.trim()}.",
          type: "project_assignment",
          projectId: newProjectId,
          senderName: _currentAdminName ?? "المسؤول", // Use fetched admin name
        );
      }
      // --- MODIFICATION END ---

      _showFeedbackSnackBar('تم إضافة المشروع بنجاح.', isError: false);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showFeedbackSnackBar('فشل إضافة المشروع: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة مشروع جديد', style: TextStyle(color: Colors.white)),
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
        body: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المشروع',
                    prefixIcon: Icon(Icons.work_outline_rounded, color: AppConstants.primaryColor),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال اسم المشروع.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.itemSpacing * 1.5),

                const Text(
                  'اختر المهندسين المسؤولين:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                if (widget.availableEngineers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
                    child: Text(
                      'لا يوجد مهندسون متاحون حالياً. يرجى إضافتهم أولاً من قسم إدارة المهندسين.',
                      style: TextStyle(color: AppConstants.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.25,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.textSecondary.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.availableEngineers.length,
                      itemBuilder: (ctx, index) {
                        final engineerDoc = widget.availableEngineers[index];
                        final engineer = engineerDoc.data() as Map<String, dynamic>;
                        final engineerId = engineerDoc.id;
                        final engineerName = engineer['name'] ?? 'مهندس غير مسمى';
                        final bool isSelected = _selectedEngineerIds.contains(engineerId);

                        return CheckboxListTile(
                          title: Text(engineerName, style: const TextStyle(color: AppConstants.textPrimary)),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!_selectedEngineerIds.contains(engineerId)) {
                                  _selectedEngineerIds.add(engineerId);
                                }
                              } else {
                                _selectedEngineerIds.remove(engineerId);
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
                if (widget.availableEngineers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: FormField<List<String>>(
                      initialValue: _selectedEngineerIds,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
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
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        )
                            : const SizedBox.shrink();
                      },
                    ),
                  ),

                const SizedBox(height: AppConstants.itemSpacing * 1.5),

                if (widget.availableClients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
                    child: Text(
                      'لا يوجد عملاء متاحون حالياً. يرجى إضافتهم أولاً من قسم إدارة العملاء.',
                      style: TextStyle(color: AppConstants.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'اختر العميل',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppConstants.primaryColor),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.availableClients.map((doc) {
                      final user = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(user['name'] ?? 'عميل غير مسمى'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClientId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'الرجاء اختيار العميل.';
                      }
                      return null;
                    },
                    isExpanded: true,
                    menuMaxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),

                const SizedBox(height: AppConstants.paddingLarge * 1.5),
                ElevatedButton.icon(
                  onPressed: (_isLoading || (widget.availableEngineers.isEmpty || widget.availableClients.isEmpty)) ? null : _submitProject,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  label: _isLoading
                      ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                      : const Text('إضافة المشروع', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
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