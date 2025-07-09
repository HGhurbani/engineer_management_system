import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../utils/pdf_styles.dart';
import '../../utils/pdf_image_cache.dart';
import '../../utils/report_storage.dart';
import '../../utils/pdf_report_generator.dart';
import 'package:engineer_management_system/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

class AdminMeetingLogsPage extends StatefulWidget {
  const AdminMeetingLogsPage({Key? key}) : super(key: key);

  @override
  State<AdminMeetingLogsPage> createState() => _AdminMeetingLogsPageState();
}

class _AdminMeetingLogsPageState extends State<AdminMeetingLogsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  pw.Font? _arabicFont;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchAndFilter(),
            Expanded(child: _buildMeetingsList()),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'محاضر الاجتماعات',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: AppConstants.primaryDark,
      centerTitle: true,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppConstants.primaryColor, AppConstants.primaryDark],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
          onPressed: _showFilterDialog,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // شريط البحث
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                hintText: 'البحث في المحاضر...',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),
          // أزرار الفلترة
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', 'جميع المحاضر', Icons.list_alt),
          _buildFilterChip('client', 'اجتماعات العملاء', Icons.people),
          _buildFilterChip('employee', 'اجتماعات الموظفين', Icons.business),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppConstants.primaryDark,
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppConstants.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Colors.white,
        selectedColor: AppConstants.primaryDark,
        checkmarkColor: Colors.white,
        elevation: isSelected ? 4 : 1,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  Widget _buildMeetingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meeting_logs')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = _filterDocs(snapshot.data!.docs);

        if (docs.isEmpty) {
          return _buildNoResultsState();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      index * 0.1,
                      (index * 0.1) + 0.1,
                      curve: Curves.easeOut,
                    ),
                  )),
                  child: _buildMeetingCard(data, docs[index].id),
                );
              },
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = data['title']?.toString().toLowerCase() ?? '';
      final description = data['description']?.toString().toLowerCase() ?? '';
      final type = data['type'] ?? '';

      // فلترة حسب النوع
      if (_selectedFilter != 'all' && type != _selectedFilter) {
        return false;
      }

      // فلترة حسب البحث
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || description.contains(query);
      }

      return true;
    }).toList();
  }

  Widget _buildMeetingCard(Map<String, dynamic> data, String docId) {
    final title = data['title'] ?? 'بدون عنوان';
    final description = data['description'] ?? 'بدون وصف';
    final type = data['type'] ?? '';
    final date = (data['date'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showMeetingDetails(data),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMeetingIcon(type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTypeChip(type),
                    if (date != null) _buildDateChip(date),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingIcon(String type) {
    final isClient = type == 'client';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isClient
            ? const Color(0xFF10B981).withOpacity(0.1)
            : AppConstants.primaryDark.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isClient ? Icons.people : Icons.business,
        color: isClient ? const Color(0xFF10B981) : AppConstants.primaryDark,
        size: 20,
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final isClient = type == 'client';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClient
            ? const Color(0xFF10B981).withOpacity(0.1)
            : AppConstants.primaryDark.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClient ? const Color(0xFF10B981) : AppConstants.primaryDark,
          width: 1,
        ),
      ),
      child: Text(
        isClient ? 'عميل' : 'موظفين',
        style: TextStyle(
          color: isClient ? const Color(0xFF10B981) : AppConstants.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppConstants.primaryDark),
          SizedBox(height: 16),
          Text(
            'جاري تحميل المحاضر...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ في تحميل البيانات',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryDark,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد محاضر اجتماعات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة محضر اجتماع جديد',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد نتائج مطابقة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تغيير كلمات البحث أو الفلتر',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddMeetingDialog,
      backgroundColor: const Color(0xFF21206C),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'محضر جديد',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showAddMeetingDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? type;
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    List<XFile>? selectedImages;

    final currentAdmin = FirebaseAuth.instance.currentUser;
    String adminName = 'المسؤول';
    if (currentAdmin != null) {
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentAdmin.uid)
            .get();
        if (adminDoc.exists) {
          adminName = (adminDoc.data() as Map<String, dynamic>)['name'] ?? 'المسؤول';
        }
      } catch (_) {}
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, color: AppConstants.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'إضافة محضر جديد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'عنوان المحضر *',
                          hintText: 'أدخل عنوان المحضر',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال العنوان' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descController,
                        decoration: InputDecoration(
                          labelText: 'التفاصيل',
                          hintText: 'أدخل تفاصيل المحضر (اختياري)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: InputDecoration(
                          labelText: 'نوع الاجتماع *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'client', child: Text('مع العميل')),
                          DropdownMenuItem(value: 'employee', child: Text('مع الموظفين')),
                        ],
                        onChanged: (val) => setStateDialog(() => type = val),
                        validator: (val) => val == null ? 'اختر نوع الاجتماع' : null,
                      ),
                      const SizedBox(height: 16),
                      if (selectedImages != null && selectedImages!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selectedImages!.map((xFile) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? Image.network(xFile.path, height: 80, width: 80, fit: BoxFit.cover)
                                        : Image.file(File(xFile.path), height: 80, width: 80, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: IconButton(
                                      icon: const CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 12,
                                        child: Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                      onPressed: () {
                                        setStateDialog(() {
                                          selectedImages!.remove(xFile);
                                          if (selectedImages!.isEmpty) selectedImages = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppConstants.primaryColor),
                        label: Text(
                            selectedImages == null || selectedImages!.isEmpty
                                ? 'إضافة صور (اختياري)'
                                : 'تغيير/إضافة المزيد من الصور',
                            style: const TextStyle(color: AppConstants.primaryColor)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final images = await picker.pickMultiImage(imageQuality: 70);
                          if (images.isNotEmpty) {
                            setStateDialog(() {
                              selectedImages ??= [];
                              selectedImages!.addAll(images);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setStateDialog(() => isLoading = true);
                            List<String> uploadedUrls = [];
                            if (selectedImages != null && selectedImages!.isNotEmpty) {
                              for (int i = 0; i < selectedImages!.length; i++) {
                                final img = selectedImages![i];
                                try {
                                  var request = http.MultipartRequest('POST', Uri.parse(AppConstants.uploadUrl));
                                  if (kIsWeb) {
                                    final bytes = await img.readAsBytes();
                                    request.files.add(http.MultipartFile.fromBytes(
                                      'image',
                                      bytes,
                                      filename: img.name,
                                      contentType: MediaType.parse(img.mimeType ?? 'image/jpeg'),
                                    ));
                                  } else {
                                    request.files.add(await http.MultipartFile.fromPath(
                                      'image',
                                      img.path,
                                      contentType: MediaType.parse(img.mimeType ?? 'image/jpeg'),
                                    ));
                                  }

                                  var streamedResponse = await request.send();
                                  var response = await http.Response.fromStream(streamedResponse);

                                  if (response.statusCode == 200) {
                                    var data = json.decode(response.body);
                                    if (data['status'] == 'success' && data['url'] != null) {
                                      uploadedUrls.add(data['url']);
                                    } else {
                                      throw Exception(data['message'] ?? 'فشل رفع الصورة (${i + 1}) من السيرفر.');
                                    }
                                  } else {
                                    throw Exception('خطأ في الاتصال بالسيرفر لرفع الصورة (${i + 1}): ${response.statusCode}');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('فشل رفع الصورة (${i + 1}): $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            }

                            try {
                              await FirebaseFirestore.instance.collection('meeting_logs').add({
                                'adminId': currentAdmin?.uid,
                                'adminName': adminName,
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'type': type,
                                'date': Timestamp.now(),
                                if (uploadedUrls.isNotEmpty) 'imageUrls': uploadedUrls,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              Navigator.pop(context);
                            } finally {
                              setStateDialog(() => isLoading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'إضافة',
                            style: TextStyle(fontWeight: FontWeight.w600),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة المحاضر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('جميع المحاضر'),
              value: 'all',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('اجتماعات العملاء'),
              value: 'client',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('اجتماعات الموظفين'),
              value: 'employee',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMeetingDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تفاصيل المحضر',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _generateMeetingPdf(data),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('العنوان', data['title'] ?? 'بدون عنوان'),
                        _buildDetailRow('الوصف', data['description'] ?? 'بدون وصف'),
                        _buildDetailRow('النوع',
                            data['type'] == 'client' ? 'اجتماع عملاء' : 'اجتماع موظفين'),
                        if (data['adminName'] != null)
                          _buildDetailRow('أضيف بواسطة', data['adminName']),
                        if (data['date'] != null)
                          _buildDetailRow('التاريخ',
                              (data['date'] as Timestamp).toDate().toString().split(' ')[0]),
                        const SizedBox(height: 12),
                        if (data['imageUrls'] != null || data['imageUrl'] != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...((data['imageUrls'] as List<dynamic>? ?? [])
                                  .map((e) => e.toString()))
                                  .map((url) => InkWell(
                                        onTap: () => _viewImageDialog(url),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            url,
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (ctx, child, progress) => progress == null
                                                ? child
                                                : const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                            errorBuilder: (c, e, s) => Container(
                                                height: 100,
                                                width: 100,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.broken_image_outlined)),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              if (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty)
                                InkWell(
                                  onTap: () => _viewImageDialog(data['imageUrl']),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      data['imageUrl'],
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (ctx, child, progress) => progress == null
                                          ? child
                                          : const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2)),
                                      errorBuilder: (c, e, s) => Container(
                                          height: 100,
                                          width: 100,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image_outlined)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewImageDialog(String imageUrl) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.all(10),
        content: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) =>
                progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                            color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => const Center(
                child: Icon(Icons.error_outline,
                    color: AppConstants.errorColor, size: 50)),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5)),
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('إغلاق', style: TextStyle(color: Colors.white)),
          )
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  Future<void> _loadArabicFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      print('Error loading Arabic font: $e');
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppConstants.primaryColor),
              const SizedBox(width: 20),
              Text(message,
                  style: const TextStyle(fontFamily: 'NotoSansArabic')),
            ],
          ),
        );
      },
    );
  }

  void _hideLoadingDialog(BuildContext context) {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message,
      {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Future<Map<String, pw.MemoryImage>> _fetchImagesForUrls(
      List<String> urls) async {
    final Map<String, pw.MemoryImage> fetched = {};
    await Future.wait(urls.map((url) async {
      if (fetched.containsKey(url)) return;

      final cached = PdfImageCache.get(url);
      if (cached != null) {
        fetched[url] = cached;
        return;
      }

      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 60));
        final contentType = response.headers['content-type'] ?? '';
        if (response.statusCode == 200 && contentType.startsWith('image/')) {
          final resizedBytes =
              await PdfReportGenerator.resizeImageForTest(response.bodyBytes);
          final memImg = pw.MemoryImage(resizedBytes);
          fetched[url] = memImg;
          PdfImageCache.put(url, memImg);
        }
      } on TimeoutException catch (_) {
        print('Timeout fetching image from URL $url');
      } catch (e) {
        print('Error fetching image from URL $url: $e');
      }
    }));
    return fetched;
  }

  Future<void> _saveOrSharePdf(Uint8List pdfBytes, String fileName, String subject,
      String text) async {
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(path)], subject: subject, text: text);
    }
  }

  void _openPdfPreview(
      Uint8List pdfBytes, String fileName, String text, String? link) {
    Navigator.of(context).pushNamed('/pdf_preview', arguments: {
      'bytes': pdfBytes,
      'fileName': fileName,
      'text': text,
      'link': link,
    });
  }

  Future<void> _generateMeetingPdf(Map<String, dynamic> data) async {
    final DateTime meetingDate =
        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    if (_arabicFont == null) {
      await _loadArabicFont();
      if (_arabicFont == null) {
        _showFeedbackSnackBar(context, 'فشل تحميل الخط العربي. لا يمكن إنشاء PDF.',
            isError: true);
        return;
      }
    }

    _showLoadingDialog(context, 'جاري إنشاء المحضر...');

    pw.Font? emojiFont;
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmoji();
    } catch (e) {
      print('Error loading NotoColorEmoji font: $e');
    }
    final List<pw.Font> commonFontFallback =
        emojiFont != null ? [emojiFont] : [];

    final ByteData logoByteData =
        await rootBundle.load('assets/images/app_logo.png');
    final Uint8List logoBytes = logoByteData.buffer.asUint8List();
    final pw.MemoryImage appLogo = pw.MemoryImage(logoBytes);

    final imageUrls = <String>[...
        (data['imageUrls'] as List<dynamic>? ?? []).map((e) => e.toString())];
    if (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty) {
      imageUrls.add(data['imageUrl'] as String);
    }

    final fetchedImages = await _fetchImagesForUrls(imageUrls);

    final pdf = pw.Document();
    final fileName =
        'meeting_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final token = generateReportToken();
    final qrLink = buildReportDownloadUrl(fileName, token);
    final pw.TextStyle regularStyle = pw.TextStyle(
        font: _arabicFont, fontSize: 12, fontFallback: commonFontFallback);
    final pw.TextStyle headerStyle = pw.TextStyle(
        font: _arabicFont,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        fontFallback: commonFontFallback);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 1000000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: _arabicFont,
            bold: _arabicFont,
            italic: _arabicFont,
            boldItalic: _arabicFont,
            fontFallback: commonFontFallback,
          ),
          margin: PdfStyles.pageMargins,
        ),
        header: (context) => PdfStyles.buildHeader(
          font: _arabicFont!,
          logo: appLogo,
          headerText: AppConstants.meetingReportHeader,
          now: meetingDate,
          projectName: data['title'] ?? 'اجتماع',
          clientName:
              data['type'] == 'client' ? 'عميل' : 'موظفين',
        ),
        build: (context) {
          final widgets = <pw.Widget>[];
          final desc = data['description']?.toString() ?? '';
          if (desc.isNotEmpty) {
            widgets.add(pw.Text(desc, style: regularStyle));
            widgets.add(pw.SizedBox(height: 10));
          }
          for (final url in imageUrls) {
            final imgMem = fetchedImages[url];
            if (imgMem != null) {
              widgets.add(pw.Image(imgMem, width: 400, fit: pw.BoxFit.contain));
              widgets.add(pw.SizedBox(height: 10));
            }
          }
          return widgets;
        },
        footer: (context) => PdfStyles.buildFooter(
            context,
            font: _arabicFont!,
            fontFallback: commonFontFallback,
            qrData: qrLink,
            generatedByText: 'المهندس: ${FirebaseAuth.instance.currentUser?.displayName ?? ''}'),
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      final link = await uploadReportPdf(pdfBytes, fileName, token);

      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, 'تم إنشاء المحضر بنجاح.', isError: false);

      _openPdfPreview(
          pdfBytes,
          fileName,
          'يرجى الاطلاع على المحضر المرفق.',
          link);
    } catch (e) {
      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, 'فشل إنشاء أو مشاركة المحضر: $e',
          isError: true);
      print('Error generating meeting PDF: $e');
    }
  }}