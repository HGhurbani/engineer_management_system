import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:async';
import 'package:intl/intl.dart';
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
import 'package:engineer_management_system/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;
import 'dart:convert';
import 'dart:io';

import 'engineer_home.dart';

class MeetingLogsPage extends StatefulWidget {
  final String engineerId;
  const MeetingLogsPage({Key? key, required this.engineerId}) : super(key: key);

  @override
  State<MeetingLogsPage> createState() => _MeetingLogsPageState();
}

class _MeetingLogsPageState extends State<MeetingLogsPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  String _filterType = 'all';
  bool _isLoading = false;
  pw.Font? _arabicFont;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        // appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // _buildSearchAndFilter(),
              Expanded(child: _buildMeetingsList()),
            ],
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }



  // Widget _buildSearchAndFilter() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.grey.withOpacity(0.1),
  //           spreadRadius: 1,
  //           blurRadius: 3,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       children: [
  //         // Search Bar
  //         Container(
  //           decoration: BoxDecoration(
  //             color: Colors.grey[100],
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(color: Colors.grey[300]!),
  //           ),
  //           child: TextField(
  //             onChanged: (value) => setState(() => _searchQuery = value),
  //             decoration: InputDecoration(
  //               hintText: 'البحث في المحاضر...',
  //               prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
  //               border: InputBorder.none,
  //               contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         // Filter Chips
  //         Row(
  //           children: [
  //             Text(
  //               'فلترة حسب النوع:',
  //               style: TextStyle(
  //                 fontWeight: FontWeight.w600,
  //                 color: Colors.grey[700],
  //               ),
  //             ),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: SingleChildScrollView(
  //                 scrollDirection: Axis.horizontal,
  //                 child: Row(
  //                   children: [
  //                     _buildFilterChip('all', 'الكل'),
  //                     const SizedBox(width: 8),
  //                     _buildFilterChip('client', 'العملاء'),
  //                     const SizedBox(width: 8),
  //                     _buildFilterChip('employee', 'الموظفين'),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppConstants.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filterType = value),
      backgroundColor: Colors.white,
      selectedColor: AppConstants.primaryColor,
      checkmarkColor: Colors.white,
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppConstants.primaryColor),
      ),
    );
  }

  Widget _buildMeetingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meeting_logs')
          .where('engineerId', isEqualTo: widget.engineerId)
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

        final docs = snapshot.data!.docs;
        final filteredDocs = _filterDocs(docs);

        if (filteredDocs.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            return _buildMeetingCard(filteredDocs[index], index);
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final type = data['type'] ?? '';

      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          description.contains(_searchQuery.toLowerCase());

      final matchesFilter = _filterType == 'all' || type == _filterType;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildMeetingCard(QueryDocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '';
    final description = data['description'] ?? '';
    final type = data['type'] ?? '';
    final date = (data['date'] as Timestamp?)?.toDate();

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showMeetingDetails(data),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: type == 'client'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == 'client' ? Icons.person : Icons.group,
                            size: 16,
                            color: type == 'client' ? Colors.blue : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            type == 'client' ? 'عميل' : 'موظفين',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: type == 'client' ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (date != null)
                      Text(
                        DateFormat('dd/MM/yyyy', 'ar').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date != null
                          ? DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date)
                          : 'غير محدد',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppConstants.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل المحاضر...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
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
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'فشل في تحميل المحاضر',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تحقق من اتصال الإنترنت وحاول مرة أخرى',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد محاضر بعد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة أول محضر اجتماع',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddLogDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة محضر جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تغيير كلمات البحث أو الفلترة',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddLogDialog,
      backgroundColor: AppConstants.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add),
      label: const Text(
        'محضر جديد',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showMeetingDetails(Map<String, dynamic> data) {
    final title = data['title'] ?? '';
    final description = data['description'] ?? '';
    final type = data['type'] ?? '';
    final date = (data['date'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.assignment,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تفاصيل المحضر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('العنوان', title, Icons.title),
                if (description.isNotEmpty)
                  _buildDetailRow('التفاصيل', description, Icons.description),
                _buildDetailRow(
                  'النوع',
                  type == 'client' ? 'مع العميل' : 'مع الموظفين',
                  type == 'client' ? Icons.person : Icons.group,
                ),
                if (date != null)
                  _buildDetailRow(
                    'التاريخ',
                    DateFormat('EEEE، dd MMMM yyyy', 'ar').format(date),
                    Icons.calendar_today,
                  ),
                const SizedBox(height: 12),
                if (data['imageUrls'] != null || data['imageUrl'] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...((data['imageUrls'] as List<dynamic>? ?? [])
                              .map((e) => e.toString()))
                          .map(
                            (url) => InkWell(
                              onTap: () => _viewImageDialog(url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) =>
                                      progress == null
                                          ? child
                                          : const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                  errorBuilder: (c, e, s) => Container(
                                      height: 100,
                                      width: 100,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image_outlined)),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      if (data['imageUrl'] != null &&
                          (data['imageUrl'] as String).isNotEmpty)
                        InkWell(
                          onTap: () => _viewImageDialog(data['imageUrl']),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['imageUrl'],
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) =>
                                  progress == null
                                      ? child
                                      : const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                              CircularProgressIndicator(strokeWidth: 2),
                                        ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLogDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    String? type;
    final _formKey = GlobalKey<FormState>();
    List<XFile>? selectedImages;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      child: Icon(
                        Icons.add,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'إضافة محضر جديد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: Form(
                  key: _formKey,
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال عنوان المحضر';
                          }
                          return null;
                        },
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
                          DropdownMenuItem(
                            value: 'client',
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 20),
                                SizedBox(width: 8),
                                Text('مع العميل'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'employee',
                            child: Row(
                              children: [
                                Icon(Icons.group, size: 20),
                                SizedBox(width: 8),
                                Text('مع الموظفين'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) => setDialogState(() => type = val),
                        validator: (value) {
                          if (value == null) {
                            return 'يرجى اختيار نوع الاجتماع';
                          }
                          return null;
                        },
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
                                        ? Image.network(xFile.path,
                                            height: 80,
                                            width: 80,
                                            fit: BoxFit.cover)
                                        : Image.file(File(xFile.path),
                                            height: 80,
                                            width: 80,
                                            fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: IconButton(
                                      icon: const CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        radius: 12,
                                        child:
                                            Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
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
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            color: AppConstants.primaryColor),
                        label: Text(
                            selectedImages == null || selectedImages!.isEmpty
                                ? 'إضافة صور (اختياري)'
                                : 'تغيير/إضافة المزيد من الصور',
                            style:
                                const TextStyle(color: AppConstants.primaryColor)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final images = await picker.pickMultiImage(imageQuality: 70);
                          if (images.isNotEmpty) {
                            setDialogState(() {
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
                    onPressed: _isLoading ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        setDialogState(() => _isLoading = true);
                        try {
                          List<String> uploadedUrls = [];
                          if (selectedImages != null && selectedImages!.isNotEmpty) {
                            for (int i = 0; i < selectedImages!.length; i++) {
                              final img = selectedImages![i];
                              try {
                                var request = http.MultipartRequest(
                                    'POST', Uri.parse(AppConstants.uploadUrl));
                                if (kIsWeb) {
                                  final bytes = await img.readAsBytes();
                                  request.files.add(http.MultipartFile.fromBytes(
                                    'image',
                                    bytes,
                                    filename: img.name,
                                    contentType:
                                        MediaType.parse(img.mimeType ?? 'image/jpeg'),
                                  ));
                                } else {
                                  request.files.add(await http.MultipartFile.fromPath(
                                    'image',
                                    img.path,
                                    contentType:
                                        MediaType.parse(img.mimeType ?? 'image/jpeg'),
                                  ));
                                }
                                var streamedResponse = await request.send();
                                var response = await http.Response.fromStream(streamedResponse);
                                if (response.statusCode == 200) {
                                  var data = json.decode(response.body);
                                  if (data['status'] == 'success' && data['url'] != null) {
                                    uploadedUrls.add(data['url']);
                                  } else {
                                    throw Exception(data['message'] ??
                                        'فشل رفع الصورة (${i + 1}) من السيرفر.');
                                  }
                                } else {
                                  throw Exception(
                                      'خطأ في الاتصال بالسيرفر لرفع الصورة (${i + 1}): ${response.statusCode}');
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('فشل رفع الصورة (${i + 1}): $e'),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              }
                            }
                          }

                          await FirebaseFirestore.instance.collection('meeting_logs').add({
                            'engineerId': widget.engineerId,
                            'title': titleController.text.trim(),
                            'description': descController.text.trim(),
                            'type': type,
                            'date': Timestamp.now(),
                            if (uploadedUrls.isNotEmpty) 'imageUrls': uploadedUrls,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('تم إضافة المحضر بنجاح'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('فشل في إضافة المحضر'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        } finally {
                          setDialogState(() => _isLoading = false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
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
            loadingBuilder: (ctx, child, progress) => progress == null
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
            style:
                TextButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5)),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
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
      // ignore: avoid_print
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
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        final contentType = response.headers['content-type'] ?? '';
        if (response.statusCode == 200 && contentType.startsWith('image/')) {
          final decoded = img.decodeImage(response.bodyBytes);
          if (decoded != null) {
            final memImg = pw.MemoryImage(response.bodyBytes);
            fetched[url] = memImg;
            PdfImageCache.put(url, memImg);
          }
        }
      } on TimeoutException catch (_) {
        // ignore: avoid_print
        print('Timeout fetching image from URL $url');
      } catch (e) {
        // ignore: avoid_print
        print('Error fetching image from URL $url: $e');
      }
    }));
    return fetched;
  }

  Future<void> _saveOrSharePdf(
      Uint8List pdfBytes, String fileName, String subject, String text) async {
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

  void _openPdfPreview(Uint8List pdfBytes, String fileName, String text) {
    Navigator.of(context).pushNamed('/pdf_preview', arguments: {
      'bytes': pdfBytes,
      'fileName': fileName,
      'text': text,
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
      // ignore: avoid_print
      print('Error loading NotoColorEmoji font: $e');
    }
    final List<pw.Font> commonFontFallback = emojiFont != null ? [emojiFont] : [];

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

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme:
              pw.ThemeData.withFont(base: _arabicFont, fontFallback: commonFontFallback),
          margin: PdfStyles.pageMargins,
        ),
        header: (context) => PdfStyles.buildHeader(
          font: _arabicFont!,
          logo: appLogo,
          headerText: AppConstants.meetingReportHeader,
          now: meetingDate,
          projectName: data['title'] ?? 'اجتماع',
          clientName: data['type'] == 'client' ? 'عميل' : 'موظفين',
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
            generatedByText: 'المهندس: ${_authUser?.displayName ?? ''}'),
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      await uploadReportPdf(pdfBytes, fileName, token);

      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, 'تم إنشاء المحضر بنجاح.', isError: false);

      _openPdfPreview(
        pdfBytes,
        fileName,
        'يرجى الاطلاع على المحضر المرفق.',
      );
    } catch (e) {
      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, 'فشل إنشاء أو مشاركة المحضر: $e',
          isError: true);
      // ignore: avoid_print
      print('Error generating meeting PDF: $e');
    }
  }
}