// lib/pages/admin/add_project_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // --- MODIFICATION: Added ---
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:ui' as ui; // For TextDirection

// --- MODIFICATION START: Import notification helper functions ---
// Make sure the path to your main.dart (or a dedicated notification service file) is correct.
// If you created a separate service file, import that instead.
import '../../main.dart'; // Assuming helper functions are in main.dart
// --- MODIFICATION END ---


// AppConstants (يفضل أن تكون في ملف مشترك، ولكن للتبسيط نضعها هنا مؤقتاً)

class AddProjectPage extends StatefulWidget {
  final List<QueryDocumentSnapshot> availableEngineers;
  final List<QueryDocumentSnapshot> availableClients;
  final String? initialClientId;
  final String? defaultProjectName;
  final bool lockClientSelection;

  const AddProjectPage({
    super.key,
    required this.availableEngineers,
    required this.availableClients,
    this.initialClientId,
    this.defaultProjectName,
    this.lockClientSelection = false,
  });

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();
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
    if (widget.initialClientId != null) {
      _selectedClientId = widget.initialClientId;
      try {
        final doc = widget.availableClients.firstWhere(
          (d) => d.id == widget.initialClientId,
        );
        final data = doc.data() as Map<String, dynamic>;
        _clientController.text = data['name'] ?? '';
      } catch (_) {}
    }
    if (widget.defaultProjectName != null) {
      _nameController.text = widget.defaultProjectName!;
    }
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
    _clientController.dispose();
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
                  TextFormField(
                    controller: _clientController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'اختر العميل',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppConstants.primaryColor),
                      border: OutlineInputBorder(),
                    ),
                    onTap: widget.lockClientSelection
                        ? null
                        : () async {
                            final result = await showSearch<QueryDocumentSnapshot>(
                              context: context,
                              delegate: ClientSearchDelegate(widget.availableClients),
                            );
                            if (result != null) {
                              setState(() {
                                _selectedClientId = result.id;
                                final data = result.data() as Map<String, dynamic>;
                                _clientController.text = data['name'] ?? '';
                              });
                            }
                          },
                    validator: (value) {
                      if (_selectedClientId == null) {
                        return 'الرجاء اختيار العميل.';
                      }
                      return null;
                    },
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

class ClientSearchDelegate extends SearchDelegate<QueryDocumentSnapshot> {
  final List<QueryDocumentSnapshot> clients;

  ClientSearchDelegate(this.clients);

  @override
  String? get searchFieldLabel => 'ابحث عن عميل';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final filtered = clients.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString();
      return name.contains(query);
    }).toList();

    return ListView(
      children: filtered.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? '';
        return ListTile(
          title: Text(name),
          onTap: () => close(context, doc),
        );
      }).toList(),
    );
  }
}
