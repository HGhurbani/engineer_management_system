// lib/pages/admin/admin_clients_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:ui' as ui; // For TextDirection
import 'add_project_page.dart';

class AdminClientsPage extends StatefulWidget {
  const AdminClientsPage({super.key});

  @override
  State<AdminClientsPage> createState() => _AdminClientsPageState();
}

class _AdminClientsPageState extends State<AdminClientsPage> {
  // Map to store display names for client types
  final Map<String, String> _clientTypeDisplay = {
    'individual': 'فردي',
    'company': 'شركة',
  };

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<QueryDocumentSnapshot> _filterClients(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final query = _searchQuery.toLowerCase();
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final email = data['email']?.toString().toLowerCase() ?? '';
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  Future<bool> _isPhoneNumberUnique(String phone, {String? excludeUid}) async {
    if (phone.isEmpty) return true;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'client')
        .where('phone', isEqualTo: phone)
        .get();
    if (snap.docs.isEmpty) return true;
    if (excludeUid != null) {
      return snap.docs.every((doc) => doc.id == excludeUid);
    }
    return false;
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textDirection: ui.TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'البحث في العملاء...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteClient(String uid, String email) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من رغبتك في حذف العميل $email؟ هذا الإجراء لا يمكن التراجع عنه.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppConstants.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.deleteColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                ),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        // Consider associated data: Before deleting the user, you might want to handle projects
        // or other data linked to this client (e.g., unassign them or delete related records).
        // This example only deletes the user document.

        // Optional: Delete user from Firebase Authentication (requires backend function or re-authentication)
        // This is a more complex operation. For now, we only delete from Firestore.
        // User? userToDelete = await FirebaseAuth.instance.userChanges().firstWhere((user) => user?.uid == uid);
        // if (userToDelete != null) {
        //   // Requires recent login for the user being deleted, or Admin SDK
        // }

        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        _showFeedbackSnackBar(context, 'تم حذف العميل $email من قاعدة البيانات بنجاح.', isError: false);
      } catch (e) {
        _showFeedbackSnackBar(context, 'فشل حذف العميل: $e', isError: true);
      }
    }
  }

  Future<void> _createProjectForClient(QueryDocumentSnapshot clientDoc) async {
    try {
      final engSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProjectPage(
            availableEngineers: engSnap.docs,
            availableClients: [clientDoc],
            initialClientId: clientDoc.id,
            defaultProjectName:
                (clientDoc.data() as Map<String, dynamic>)['name'] ?? '',
            lockClientSelection: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(
            context, 'فشل تحميل بيانات المهندسين: $e',
            isError: true);
      }
    }
  }

  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedClientType = 'individual'; // Default client type
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading, // Prevent dismissal while loading
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: const Text(
                'إضافة عميل جديد',
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
                    children: [
                      _buildStyledTextField(
                        controller: nameController,
                        labelText: 'الاسم الكامل',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: emailController,
                        labelText: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'صيغة بريد إلكتروني غير صحيحة.';
                          }
                          return null;
                        },
                        isRequired: false,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: phoneController,
                        labelText: 'رقم الهاتف',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !RegExp(r'^\d{7,}$').hasMatch(value)) {
                            return 'رقم هاتف غير صالح';
                          }
                          return null;
                        },
                        isRequired: false,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: passwordController,
                        labelText: 'كلمة المرور',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && value.length < 6) {
                            return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
                          }
                          return null;
                        },
                        isRequired: false,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      // Client Type Dropdown
                      _buildStyledDropdown<String>(
                        hint: 'نوع العميل',
                        value: selectedClientType,
                        items: _clientTypeDisplay.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedClientType = value;
                          });
                        },
                        icon: Icons.business_center_outlined, // Or Icons.person_outline for individual
                        validator: (value) => value == null ? 'الرجاء اختيار نوع العميل.' : null,
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
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isLoading = true);

                          final phone = phoneController.text.trim();
                          if (phone.isNotEmpty &&
                              !await _isPhoneNumberUnique(phone)) {
                            _showFeedbackSnackBar(
                                dialogContext, 'رقم الهاتف مستخدم بالفعل.',
                                isError: true);
                            if (mounted) {
                              setDialogState(() => isLoading = false);
                            }
                            return;
                          }

                          try {
                            if (emailController.text.trim().isNotEmpty &&
                                passwordController.text.trim().isNotEmpty) {
                              UserCredential userCred = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                              );

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userCred.user!.uid)
                                  .set({
                                'uid': userCred.user!.uid,
                                'email': emailController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'name': nameController.text.trim(),
                                'role': 'client',
                                'clientType': selectedClientType,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .add({
                                'name': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'role': 'client',
                                'clientType': selectedClientType,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            Navigator.pop(dialogContext);
                            _showFeedbackSnackBar(context, 'تم إضافة العميل بنجاح.',
                                isError: false);
                          } on FirebaseAuthException catch (e) {
                            _showFeedbackSnackBar(dialogContext,
                                _getFirebaseErrorMessage(e.code),
                                isError: true);
                          } catch (e) {
                            _showFeedbackSnackBar(dialogContext, 'فشل الإضافة: $e',
                                isError: true);
                          } finally {
                            if (mounted) setDialogState(() => isLoading = false);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.person_add_alt_1, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Text('إضافة العميل', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // New method to show the edit client dialog
  Future<void> _showEditClientDialog(DocumentSnapshot clientDoc) async {
    final clientData = clientDoc.data() as Map<String, dynamic>;
    final String currentUid = clientDoc.id;

    final nameController = TextEditingController(text: clientData['name'] ?? '');
    final emailController = TextEditingController(text: clientData['email'] ?? '');
    final phoneController = TextEditingController(text: clientData['phone'] ?? '');
    // Password is not edited here for security reasons.
    String? selectedClientType = clientData['clientType'] ?? 'individual';

    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
        context: context,
        barrierDismissible: !isLoading,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                title: const Text('تعديل بيانات العميل', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary, fontSize: 22)),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStyledTextField(
                          controller: nameController,
                          labelText: 'الاسم الكامل',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        _buildStyledTextField(
                          controller: emailController,
                          labelText: 'البريد الإلكتروني',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'صيغة بريد إلكتروني غير صحيحة.';
                            }
                            return null;
                          },
                          isRequired: false,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        _buildStyledTextField(
                          controller: phoneController,
                          labelText: 'رقم الهاتف',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value != null && value.isNotEmpty && !RegExp(r'^\d{7,}$').hasMatch(value)) {
                              return 'رقم هاتف غير صالح';
                            }
                            return null;
                          },
                          isRequired: false,
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        _buildStyledDropdown<String>(
                          hint: 'نوع العميل',
                          value: selectedClientType,
                          items: _clientTypeDisplay.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedClientType = value;
                            });
                          },
                          icon: Icons.business_center_outlined,
                          validator: (value) => value == null ? 'الرجاء اختيار نوع العميل.' : null,
                        ),
                        // const SizedBox(height: AppConstants.itemSpacing),
                        // const Text(
                        //   "ملاحظة: لتغيير كلمة المرور أو البريد الإلكتروني الخاص بالمصادقة، يجب إجراء ذلك من خلال وحدة تحكم Firebase أو طلب إعادة تعيين من المستخدم.",
                        //   style: TextStyle(fontSize: 12, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                        // ),
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
                    onPressed: isLoading ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);

                      final phone = phoneController.text.trim();
                      if (phone.isNotEmpty &&
                          !await _isPhoneNumberUnique(phone, excludeUid: currentUid)) {
                        _showFeedbackSnackBar(
                            dialogContext, 'رقم الهاتف مستخدم بالفعل.',
                            isError: true);
                        if (mounted) {
                          setDialogState(() => isLoading = false);
                        }
                        return;
                      }
                      try {
                        await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'clientType': selectedClientType,
                          // 'updatedAt': FieldValue.serverTimestamp(), // Optional: track updates
                        });
                        Navigator.pop(dialogContext);
                        _showFeedbackSnackBar(context, 'تم تحديث بيانات العميل بنجاح.', isError: false);
                      } catch (e) {
                        _showFeedbackSnackBar(dialogContext, 'فشل تحديث البيانات: $e', isError: true);
                      } finally {
                        if(mounted) setDialogState(() => isLoading = false);
                      }
                    },
                    icon: isLoading ? const SizedBox.shrink() : const Icon(Icons.save_alt_rounded, color: Colors.white),
                    label: isLoading
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
        )
    );
  }

  Future<void> _showAddCredentialsDialog(DocumentSnapshot clientDoc) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              title: const Text(
                'إضافة بيانات الدخول',
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
                    children: [
                      _buildStyledTextField(
                        controller: emailController,
                        labelText: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'هذا الحقل مطلوب.';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'صيغة بريد إلكتروني غير صحيحة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      _buildStyledTextField(
                        controller: passwordController,
                        labelText: 'كلمة المرور',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'هذا الحقل مطلوب.';
                          }
                          if (value.length < 6) {
                            return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
                          }
                          return null;
                        },
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
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isLoading = true);

                          try {
                            final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );

                            final clientData = clientDoc.data() as Map<String, dynamic>;
                            clientData['email'] = emailController.text.trim();
                            clientData['uid'] = userCred.user!.uid;

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userCred.user!.uid)
                                .set(clientData);

                            final oldId = clientDoc.id;
                            final projectsSnap = await FirebaseFirestore.instance
                                .collection('projects')
                                .where('clientId', isEqualTo: oldId)
                                .get();
                            for (final doc in projectsSnap.docs) {
                              await doc.reference.update({'clientId': userCred.user!.uid});
                            }

                            await clientDoc.reference.delete();

                            Navigator.pop(dialogContext);
                            _showFeedbackSnackBar(context, 'تم إضافة بيانات الدخول بنجاح.', isError: false);
                          } on FirebaseAuthException catch (e) {
                            _showFeedbackSnackBar(dialogContext, _getFirebaseErrorMessage(e.code), isError: true);
                          } catch (e) {
                            _showFeedbackSnackBar(dialogContext, 'فشل الإضافة: $e', isError: true);
                          } finally {
                            if (mounted) setDialogState(() => isLoading = false);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save, color: Colors.white),
                  label: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('حفظ', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'client')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState('حدث خطأ: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final clients = _filterClients(snapshot.data!.docs);
                  return _buildClientsList(clients);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'إدارة العملاء',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
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
    );
  }

  Widget _buildClientsList(List<QueryDocumentSnapshot> clients) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final clientDoc = clients[index]; // Get the DocumentSnapshot
        final data = clientDoc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'اسم غير متوفر';
        final email = data['email'] ?? 'بريد غير متوفر';
        final clientTypeKey = data['clientType'] ?? 'individual'; // Default if not set
        final clientTypeDisplay = _clientTypeDisplay[clientTypeKey] ?? clientTypeKey; // Get display name
        final uid = clientDoc.id;

        IconData clientIcon = clientTypeKey == 'company' ? Icons.business_rounded : Icons.person_outline_rounded;

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
          elevation: 2,
          shadowColor: AppConstants.primaryColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppConstants.primaryLight.withOpacity(0.15),
                  child: Icon(clientIcon, size: 30, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: AppConstants.itemSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppConstants.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4), // Space before client type
                      Text(
                        'النوع: $clientTypeDisplay', // Display client type
                        style: TextStyle(
                            fontSize: 13,
                            color: AppConstants.textSecondary.withOpacity(0.8),
                            fontStyle: FontStyle.italic
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_business_outlined, color: AppConstants.primaryColor),
                  onPressed: () => _createProjectForClient(clientDoc),
                  tooltip: 'إنشاء مشروع لهذا العميل',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditClientDialog(clientDoc);
                        break;
                      case 'delete':
                        _deleteClient(uid, email);
                        break;
                      case 'add_credentials':
                        _showAddCredentialsDialog(clientDoc);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(Icons.edit_outlined, color: AppConstants.infoColor),
                          SizedBox(width: 8),
                          Text('تعديل العميل'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline, color: AppConstants.deleteColor),
                          SizedBox(width: 8),
                          Text('حذف العميل'),
                        ],
                      ),
                    ),
                    if ((data['email'] == null || (data['email'] as String).isEmpty))
                      PopupMenuItem(
                        value: 'add_credentials',
                        child: Row(
                          children: const [
                            Icon(Icons.lock_open, color: AppConstants.primaryColor),
                            SizedBox(width: 8),
                            Text('إضافة بيانات الدخول'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddClientDialog,
      backgroundColor: AppConstants.primaryColor,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'إضافة عميل',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      tooltip: 'إضافة عميل جديد',
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: AppConstants.textSecondary),
            const SizedBox(height: AppConstants.itemSpacing),
            const Text(
              'عذراً، حدث خطأ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 16, color: AppConstants.textSecondary),
              textAlign: TextAlign.center,
            ),
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
          Icon(Icons.people_outline, size: 100, color: AppConstants.textSecondary.withOpacity(0.5)),
          const SizedBox(height: AppConstants.itemSpacing),
          const Text(
            'لا يوجد عملاء بعد',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'انقر على زر "إضافة عميل" لبدء الإضافة.',
            style: TextStyle(fontSize: 16, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppConstants.textSecondary), // Added for consistency
        prefixIcon: Icon(icon, color: AppConstants.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.textSecondary, width: 1), // Default border
        ),
        enabledBorder: OutlineInputBorder( // Border when not focused
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: BorderSide(color: AppConstants.textSecondary.withOpacity(0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder( // Border when focused
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder( // Border when error
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder( // Border when error and focused
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1.5),
        ),
        filled: true, // Added for better visual separation
        fillColor: AppConstants.cardColor.withOpacity(0.7), // Slightly transparent fill
        contentPadding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium -2, horizontal: AppConstants.paddingSmall),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'هذا الحقل مطلوب.';
        }
        if (validator != null && value != null && value.isNotEmpty) {
          return validator(value);
        }
        return null;
      },
    );
  }

  // Helper for styled DropdownButtonFormField
  Widget _buildStyledDropdown<T>({
    required String hint,
    T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
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
          borderSide: BorderSide(color: AppConstants.textSecondary.withOpacity(0.5), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: BorderSide(color: AppConstants.textSecondary.withOpacity(0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1.5),
        ),
        filled: true,
        fillColor: AppConstants.cardColor.withOpacity(0.7),
        contentPadding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium - 4, horizontal: AppConstants.paddingSmall).copyWith(left:12), // Adjust padding
      ),
      isExpanded: true,
      alignment: AlignmentDirectional.centerStart,
    );
  }


  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
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

  String _getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً.';
      default:
        return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }
  }
}