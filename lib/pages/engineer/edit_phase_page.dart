import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../theme/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/pdf_report_generator.dart';

class EditPhasePage extends StatefulWidget {
  final String projectId;
  final String phaseId;
  final Map<String, dynamic> phaseData;

  const EditPhasePage({
    super.key,
    required this.projectId,
    required this.phaseId,
    required this.phaseData,
  });

  @override
  State<EditPhasePage> createState() => _EditPhasePageState();
}

class _EditPhasePageState extends State<EditPhasePage> {
  final _noteController = TextEditingController();
  File? _image360File;
  final _image360LinkController = TextEditingController();
  File? _imageFile;
  bool _locationAllowed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.phaseData['note'] ?? '';
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationAllowed = true;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _savePhase() async {
    if (!_locationAllowed) return;

    setState(() {
      _isLoading = true;
    });

    String? imageUrl;
    String? image360Url;

    // إذا المستخدم رفع صورة 360 من الجهاز

    if (_image360File != null) {
      try {
        final bytes = await _image360File!.readAsBytes();
        final compressed = await PdfReportGenerator.resizeImageForTest(bytes);
        var request = http.MultipartRequest('POST', Uri.parse(AppConstants.uploadUrl));
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          compressed,
          filename: "${widget.phaseId}_360.jpg",
          contentType: MediaType('image', 'jpeg'),
        ));
        var streamed = await request.send();
        var response = await http.Response.fromStream(streamed);
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          if (data['status'] == 'success' && data['url'] != null) {
            image360Url = data['url'];
          } else {
            throw Exception(data['message'] ?? 'فشل رفع الصورة من السيرفر.');
          }
        } else {
          throw Exception('خطأ في الاتصال بالسيرفر: ${response.statusCode}');
        }
      } catch (e) {
        // ignore and continue
      }
    } else if (_image360LinkController.text.trim().isNotEmpty) {
      image360Url = _image360LinkController.text.trim();
    }

    if (_imageFile != null) {
      try {
        final bytes = await _imageFile!.readAsBytes();
        final compressed = await PdfReportGenerator.resizeImageForTest(bytes);
        var request = http.MultipartRequest('POST', Uri.parse(AppConstants.uploadUrl));
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          compressed,
          filename: "${widget.phaseId}.jpg",
          contentType: MediaType('image', 'jpeg'),
        ));
        var streamed = await request.send();
        var response = await http.Response.fromStream(streamed);
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          if (data['status'] == 'success' && data['url'] != null) {
            imageUrl = data['url'];
          } else {
            throw Exception(data['message'] ?? 'فشل رفع الصورة من السيرفر.');
          }
        } else {
          throw Exception('خطأ في الاتصال بالسيرفر: ${response.statusCode}');
        }
      } catch (e) {
        // ignore and continue
      }
    }
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('phases')
        .doc(widget.phaseId)
        .update({
      'note': _noteController.text,
      'imageUrl': imageUrl ?? widget.phaseData['imageUrl'],
      'image360Url': image360Url ?? widget.phaseData['image360Url'],
      'completed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تحديث المرحلة ${widget.phaseData['number']}')),
      body: _locationAllowed
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
            const SizedBox(height: 16),
            _imageFile != null
                ? Image.file(_imageFile!, height: 150)
                : ElevatedButton(
              onPressed: _pickImage,
              child: const Text('التقاط صورة'),
            ),
            const SizedBox(height: 16),
            Text('صورة 360°'),
            ElevatedButton(
              onPressed: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() {
                    _image360File = File(picked.path);
                  });
                }
              },
              child: const Text('اختيار صورة 360° من الجهاز'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _image360LinkController,
              decoration: const InputDecoration(
                labelText: 'أو أدخل رابط صورة 360°',
              ),
            ),

            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
              onPressed: _savePhase,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
          ],
        ),
      )
          : const Center(
        child: Text('يرجى تفعيل الموقع أولاً لتعديل المرحلة'),
      ),
    );
  }
}
