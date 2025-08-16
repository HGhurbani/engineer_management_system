import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_constants.dart';
import '../../main.dart';

class AdminAddPhaseEntryPage extends StatefulWidget {
  final String projectId;
  final String phaseId;
  final String phaseOrSubPhaseName;
  final String? subPhaseId;

  const AdminAddPhaseEntryPage({
    Key? key,
    required this.projectId,
    required this.phaseId,
    required this.phaseOrSubPhaseName,
    this.subPhaseId,
  }) : super(key: key);

  @override
  State<AdminAddPhaseEntryPage> createState() => _AdminAddPhaseEntryPageState();
}

class _AdminAddPhaseEntryPageState extends State<AdminAddPhaseEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  List<XFile> _selectedBeforeImages = [];
  List<XFile> _selectedAfterImages = [];
  List<XFile> _selectedOtherImages = [];
  
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  // تحسين الأداء - استخدام PageView للصور
  final PageController _beforeImagesController = PageController();
  final PageController _afterImagesController = PageController();
  final PageController _otherImagesController = PageController();

  @override
  void dispose() {
    _noteController.dispose();
    _beforeImagesController.dispose();
    _afterImagesController.dispose();
    _otherImagesController.dispose();
    super.dispose();
  }

  Future<void> _pickImages(ImageSource source, String imageType) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80, // تقليل جودة الصور لتحسين الأداء
        maxWidth: 1920, // تحديد الحد الأقصى للعرض
        maxHeight: 1080, // تحديد الحد الأقصى للارتفاع
      );
      
      if (images.isNotEmpty) {
        setState(() {
          switch (imageType) {
            case 'before':
              _selectedBeforeImages.addAll(images);
              break;
            case 'after':
              _selectedAfterImages.addAll(images);
              break;
            case 'other':
              _selectedOtherImages.addAll(images);
              break;
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('فشل في اختيار الصور: $e');
    }
  }

  void _removeImage(String imageType, int index) {
    setState(() {
      switch (imageType) {
        case 'before':
          _selectedBeforeImages.removeAt(index);
          break;
        case 'after':
          _selectedAfterImages.removeAt(index);
          break;
        case 'other':
          _selectedOtherImages.removeAt(index);
          break;
      }
    });
  }

  Future<List<String>> _uploadImages(List<XFile> images, String folder) async {
    if (images.isEmpty) return [];
    
    List<String> uploadedUrls = [];
    int totalImages = images.length;
    int uploadedCount = 0;
    
    for (int i = 0; i < images.length; i++) {
      try {
        final file = File(images[i].path);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = FirebaseStorage.instance
            .ref()
            .child('projects/${widget.projectId}/$folder/$fileName');
        
        final uploadTask = ref.putFile(file);
        
        // مراقبة تقدم الرفع
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * (1 / totalImages);
          setState(() {
            _uploadProgress = (uploadedCount / totalImages) + progress;
          });
        });
        
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
        uploadedCount++;
        
        setState(() {
          _uploadProgress = uploadedCount / totalImages;
        });
        
      } catch (e) {
        print('Error uploading image $i: $e');
        // الاستمرار مع الصور الأخرى
      }
    }
    
    return uploadedUrls;
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedBeforeImages.isEmpty && 
        _selectedAfterImages.isEmpty && 
        _selectedOtherImages.isEmpty && 
        _noteController.text.trim().isEmpty) {
      _showErrorSnackBar('الرجاء إدخال ملاحظة أو إضافة صورة واحدة على الأقل');
      return;
    }
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    try {
      // رفع الصور
      final beforeUrls = await _uploadImages(_selectedBeforeImages, 'before_images');
      final afterUrls = await _uploadImages(_selectedAfterImages, 'after_images');
      final otherUrls = await _uploadImages(_selectedOtherImages, 'other_images');
      
      // حفظ البيانات في Firestore
      final entriesCollectionPath = widget.subPhaseId == null
          ? 'projects/${widget.projectId}/phases_status/${widget.phaseId}/entries'
          : 'projects/${widget.projectId}/subphases_status/${widget.subPhaseId}/entries';
      
      final entryData = {
        'note': _noteController.text.trim(),
        'beforeImages': beforeUrls,
        'afterImages': afterUrls,
        'otherImages': otherUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'adminId': FirebaseAuth.instance.currentUser?.uid,
        'adminName': await _getCurrentAdminName(),
      };
      
      await FirebaseFirestore.instance
          .collection(entriesCollectionPath)
          .add(entryData);
      
      // إرسال إشعار للعميل
      await _sendClientNotification(beforeUrls, afterUrls, otherUrls);
      
      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessSnackBar('تمت إضافة الإدخال بنجاح');
      }
      
    } catch (e) {
      _showErrorSnackBar('فشل في حفظ الإدخال: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<String> _getCurrentAdminName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      
      if (userDoc.exists) {
        return (userDoc.data() as Map<String, dynamic>)['name'] ?? 'المسؤول';
      }
    } catch (e) {
      print('Error getting admin name: $e');
    }
    return 'المسؤول';
  }

  Future<void> _sendClientNotification(List<String> beforeUrls, List<String> afterUrls, List<String> otherUrls) async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      
      if (projectDoc.exists) {
        final projectData = projectDoc.data() as Map<String, dynamic>;
        final clientUid = projectData['clientUid'] as String?;
        final projectName = projectData['name'] as String? ?? 'المشروع';
        
        if (clientUid != null && clientUid.isNotEmpty) {
          final hasImages = beforeUrls.isNotEmpty || afterUrls.isNotEmpty || otherUrls.isNotEmpty;
          
          await sendNotification(
            recipientUserId: clientUid,
            title: '✨ تحديث جديد لمشروعك: $projectName',
            body: 'المسؤول أضاف ${hasImages ? 'صور وملاحظات' : 'ملاحظات'} جديدة حول تقدم العمل في المرحلة "${widget.phaseOrSubPhaseName}".',
            type: 'project_entry_admin_to_client',
            projectId: widget.projectId,
            itemId: widget.subPhaseId ?? widget.phaseId,
            senderName: await _getCurrentAdminName(),
          );
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildImageSection(String title, List<XFile> images, PageController controller, String imageType) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: AppConstants.primaryColor),
                      onPressed: () => _pickImages(ImageSource.camera, imageType),
                      tooltip: 'التقاط صورة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library, color: AppConstants.primaryColor),
                      onPressed: () => _pickImages(ImageSource.gallery, imageType),
                      tooltip: 'اختيار من المعرض',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (images.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(images[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () => _removeImage(imageType, index),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${index + 1} / ${images.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == 0 ? AppConstants.primaryColor : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
            ] else ...[
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط لإضافة صور',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.subPhaseId == null
                ? 'إضافة إدخال للمرحلة: ${widget.phaseOrSubPhaseName}'
                : 'إضافة إدخال للمرحلة الفرعية: ${widget.phaseOrSubPhaseName}',
          ),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // الملاحظة
                            Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'الملاحظة',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _noteController,
                                      decoration: const InputDecoration(
                                        hintText: 'أدخل ملاحظتك هنا (اختياري إذا أضفت صورة)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.notes_rounded),
                                      ),
                                      maxLines: 3,
                                      validator: (value) {
                                        if ((value == null || value.isEmpty) &&
                                            _selectedBeforeImages.isEmpty &&
                                            _selectedAfterImages.isEmpty &&
                                            _selectedOtherImages.isEmpty) {
                                          return 'الرجاء إدخال ملاحظة أو إضافة صورة واحدة على الأقل';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // صور قبل العمل
                            _buildImageSection(
                              'صور قبل العمل',
                              _selectedBeforeImages,
                              _beforeImagesController,
                              'before',
                            ),
                            
                            // صور بعد العمل
                            _buildImageSection(
                              'صور بعد العمل',
                              _selectedAfterImages,
                              _afterImagesController,
                              'after',
                            ),
                            
                            // صور أخرى
                            _buildImageSection(
                              'صور أخرى',
                              _selectedOtherImages,
                              _otherImagesController,
                              'other',
                            ),
                            
                            const SizedBox(height: 100), // مساحة للزر
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploading) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'جاري رفع الصور... ${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: AppConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _saveEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'حفظ الإدخال',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
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
