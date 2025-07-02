import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/app_constants.dart';
import '../../models/material_item.dart';

class AdminMaterialsPage extends StatefulWidget {
  const AdminMaterialsPage({super.key});

  @override
  State<AdminMaterialsPage> createState() => _AdminMaterialsPageState();
}

class _AdminMaterialsPageState extends State<AdminMaterialsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterMaterials(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final q = _searchQuery.toLowerCase();
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      return name.contains(q);
    }).toList();
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
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'البحث في المواد...',
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Future<void> _showAddMaterialDialog({DocumentSnapshot? doc}) async {
    final nameController =
        TextEditingController(text: doc != null ? doc['name'] : '');
    String? unit = doc != null ? doc['unit'] : null;
    String? imageUrl = doc != null ? doc['imageUrl'] : null;
    XFile? pickedImage;
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Future<void> pickImage() async {
            if (kIsWeb) {
              final result = await FilePicker.platform.pickFiles(type: FileType.image);
              if (result != null && result.files.isNotEmpty) {
                pickedImage = XFile(result.files.first.path!,
                    name: result.files.first.name);
                setStateDialog(() {});
              }
            } else {
              final picker = ImagePicker();
              final xFile = await picker.pickImage(source: ImageSource.gallery);
              if (xFile != null) {
                pickedImage = xFile;
                setStateDialog(() {});
              }
            }
          }

          Future<String?> uploadImage(XFile image) async {
            try {
              var request =
                  http.MultipartRequest('POST', Uri.parse(AppConstants.uploadUrl));
              if (kIsWeb) {
                final bytes = await image.readAsBytes();
                request.files.add(http.MultipartFile.fromBytes('image', bytes,
                    filename: image.name,
                    contentType: MediaType.parse(image.mimeType ?? 'image/jpeg')));
              } else {
                request.files.add(await http.MultipartFile.fromPath('image', image.path,
                    contentType: MediaType.parse(image.mimeType ?? 'image/jpeg')));
              }
              var streamed = await request.send();
              var resp = await http.Response.fromStream(streamed);
              if (resp.statusCode == 200) {
                final data = json.decode(resp.body);
                if (data['status'] == 'success' && data['url'] != null) {
                  return data['url'];
                }
              }
            } catch (_) {}
            return null;
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              title: Text(doc == null ? 'إضافة مادة' : 'تعديل مادة'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المادة',
                          prefixIcon: Icon(Icons.label_outline,
                              color: AppConstants.primaryColor),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'الحقل مطلوب' : null,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(
                          labelText: 'وحدة القياس',
                          prefixIcon: Icon(Icons.straighten,
                              color: AppConstants.primaryColor),
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.measurementUnits
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setStateDialog(() => unit = v),
                        validator: (v) => v == null ? 'اختر الوحدة' : null,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (imageUrl != null && pickedImage == null)
                        Column(
                          children: [
                            Image.network(imageUrl!, height: 80, fit: BoxFit.cover),
                            TextButton(
                              onPressed: () => setStateDialog(() => imageUrl = null),
                              child: const Text('إزالة الصورة'),
                            ),
                          ],
                        ),
                      if (pickedImage != null)
                        kIsWeb
                            ? Image.network(pickedImage!.path, height: 80, fit: BoxFit.cover)
                            : Image.file(File(pickedImage!.path), height: 80, fit: BoxFit.cover),
                      TextButton.icon(
                        onPressed: pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            color: AppConstants.primaryColor),
                        label: Text(
                            pickedImage == null && imageUrl == null
                                ? 'اختيار صورة'
                                : 'تغيير الصورة',
                            style: const TextStyle(color: AppConstants.primaryColor)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() => isLoading = true);
                          String? finalUrl = imageUrl;
                          if (pickedImage != null) {
                            final uploaded = await uploadImage(pickedImage!);
                            if (uploaded != null) {
                              finalUrl = uploaded;
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('فشل رفع الصورة'),
                                      backgroundColor: AppConstants.errorColor),
                                );
                              }
                            }
                          }
                          try {
                            if (doc == null) {
                              await FirebaseFirestore.instance.collection('materials').add({
                                'name': nameController.text.trim(),
                                'unit': unit,
                                'imageUrl': finalUrl,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('materials')
                                  .doc(doc.id)
                                  .update({
                                'name': nameController.text.trim(),
                                'unit': unit,
                                'imageUrl': finalUrl,
                              });
                            }
                            if (mounted) Navigator.pop(dialogContext);
                          } finally {
                            if (mounted) setStateDialog(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('حفظ'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _deleteMaterial(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('حذف المادة ${doc['name']}؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.deleteColor,
                  foregroundColor: Colors.white),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('materials').doc(doc.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المواد', style: TextStyle(color: Colors.white)),
          backgroundColor: AppConstants.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppConstants.primaryColor,
          onPressed: () => _showAddMaterialDialog(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('materials')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('فشل تحميل المواد'));
            }
            final docs = snapshot.data?.docs ?? [];
            final filtered = _filterMaterials(docs);
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.inventory_2_outlined,
                        size: 100, color: AppConstants.textSecondary),
                    SizedBox(height: AppConstants.itemSpacing),
                    Text('لا توجد مواد',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              children: [
                _buildSearchBar(),
                ...filtered.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                    child: ListTile(
                      leading: data['imageUrl'] != null
                          ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.photo_outlined),
                      title: Text(data['name'] ?? ''),
                      subtitle: Text('الوحدة: ${data['unit'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppConstants.infoColor),
                            onPressed: () => _showAddMaterialDialog(doc: doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppConstants.deleteColor),
                            onPressed: () => _deleteMaterial(doc),
                          ),
                        ],
                      ),
                    ),
                  );
                })
              ],
            );
          },
        ),
      ),
    );
  }
}
