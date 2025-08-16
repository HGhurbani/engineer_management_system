import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_constants.dart';
import '../../utils/part_request_pdf_generator.dart';

class MaterialRequestDetailsPage extends StatelessWidget {
  final DocumentSnapshot requestDoc;
  final String userRole;

  const MaterialRequestDetailsPage({
    Key? key,
    required this.requestDoc,
    required this.userRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = requestDoc.data() as Map<String, dynamic>?;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('لا يمكن تحميل تفاصيل الطلب')),
      );
    }

    final List<dynamic>? itemsData = data['items'];
    final String projectName = data['projectName'] ?? 'مشروع غير محدد';
    final String engineerName = data['engineerName'] ?? 'مهندس غير معروف';
    final String status = data['status'] ?? 'غير معروف';
    final Timestamp? requestedAt = data['requestedAt'] as Timestamp?;
    final String? projectId = data['projectId'] as String?;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل طلب المواد'),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات المشروع
              _buildInfoCard(
                'معلومات المشروع',
                [
                  _buildInfoRow('اسم المشروع', projectName),
                ],
                icon: Icons.construction,
                color: AppConstants.primaryColor,
              ),
              
              const SizedBox(height: 16),
              
              // معلومات الطلب
              _buildInfoCard(
                'معلومات الطلب',
                [
                  _buildInfoRow('مقدم الطلب', engineerName),
                  _buildInfoRow('الحالة', status, statusColor: _getStatusColor(status)),
                  if (requestedAt != null)
                    _buildInfoRow('تاريخ الطلب', DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(requestedAt.toDate())),
                ],
                icon: Icons.shopping_cart,
                color: AppConstants.infoColor,
              ),
              
              const SizedBox(height: 16),
              
              // المواد المطلوبة
              _buildMaterialsCard(itemsData),
              
              const SizedBox(height: 100), // مساحة للزر
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
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _generateAndDownloadReport(context, data),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  'إنشاء تقرير PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, {required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppConstants.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: statusColor ?? AppConstants.textPrimary,
                fontWeight: statusColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsCard(List<dynamic>? itemsData) {
    if (itemsData == null || itemsData.isEmpty) {
      return _buildInfoCard(
        'المواد المطلوبة',
        [
          _buildInfoRow('اسم المادة', 'لا توجد مواد محددة'),
          _buildInfoRow('الكمية', '0'),
        ],
        icon: Icons.inventory,
        color: AppConstants.warningColor,
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory, color: AppConstants.warningColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'المواد المطلوبة (${itemsData.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...itemsData.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value as Map<String, dynamic>;
              final name = item['name'] ?? 'مادة غير مسماة';
              final quantity = item['quantity']?.toString() ?? '0';
              final imageUrl = item['imageUrl'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // رقم المادة
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // صورة المادة (إن وجدت)
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_not_supported, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                    // تفاصيل المادة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الكمية: $quantity',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'معلق':
        return AppConstants.warningColor;
      case 'تمت الموافقة':
        return AppConstants.successColor;
      case 'مرفوض':
        return AppConstants.errorColor;
      case 'تم الطلب':
        return AppConstants.infoColor;
      case 'تم الاستلام':
        return AppConstants.primaryColor;
      default:
        return AppConstants.textSecondary;
    }
  }

  Future<void> _generateAndDownloadReport(BuildContext context, Map<String, dynamic> data) async {
    try {
      // إظهار مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppConstants.primaryColor,
          ),
        ),
      );

      // إنشاء التقرير
      final bytes = await PartRequestPdfGenerator.generate(
        data,
        generatedByRole: userRole == 'admin' ? 'المسؤول' : 'المهندس',
      );

      // إغلاق مؤشر التحميل
      if (context.mounted) {
        Navigator.pop(context);
      }

      // عرض التقرير
      if (context.mounted) {
        Navigator.pushNamed(context, '/pdf_preview', arguments: {
          'bytes': bytes,
          'fileName': 'material_request_${requestDoc.id}.pdf',
          'text': 'تقرير طلب المواد',
        });
      }
    } catch (e) {
      // إغلاق مؤشر التحميل
      if (context.mounted) {
        Navigator.pop(context);
      }

      // إظهار رسالة الخطأ
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إنشاء التقرير: $e'),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
