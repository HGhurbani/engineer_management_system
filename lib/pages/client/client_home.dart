import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Constants for consistent styling and text (يمكنك وضعها في ملف منفصل)
class AppConstants {
  static const Color primaryColor = Color(0xFF0056D8); // أزرق داكن احترافي
  static const Color accentColor = Color(0xFF42A5F5); // أزرق فاتح مميز
  static const Color cardColor = Colors.white; // لون البطاقات
  static const Color backgroundColor = Color(0xFFF0F2F5); // لون خلفية فاتح جداً
  static const Color textColor = Color(0xFF333333); // لون النص الأساسي
  static const Color secondaryTextColor = Color(0xFF666666); // لون نص ثانوي
  static const Color errorColor = Color(0xFFE53935); // أحمر للأخطاء
  static const Color successColor = Colors.green; // لون للنجاح
  static const Color warningColor = Color(0xFFFFA000); // لون للتحذير (برتقالي أغمق)
  static const Color infoColor = Color(0xFF00BCD4); // لون للمعلومات (أزرق فاتح)

  static const double padding = 20.0;
  static const double borderRadius = 12.0;
  static const double itemSpacing = 16.0;
}

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  final String? _currentClientUid = FirebaseAuth.instance.currentUser?.uid;
  String? _clientName; // لتخزين اسم العميل الحالي

  @override
  void initState() {
    super.initState();
    // إذا لم يكن هناك مستخدم مسجل دخول، قم بإعادة التوجيه
    if (_currentClientUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logout(); // أو يمكنك التوجيه مباشرة إلى صفحة تسجيل الدخول
      });
    } else {
      _fetchClientData(); // جلب بيانات العميل
    }
  }

  // دالة لجلب اسم العميل الحالي
  Future<void> _fetchClientData() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentClientUid).get();
      if (userDoc.exists) {
        if (mounted) { // التحقق من mounted قبل setState
          setState(() {
            _clientName = userDoc.data()?['name'] as String?;
          });
        }
      }
    } catch (e) {
      print('Error fetching client name: $e');
    }
  }

  // دالة لتسجيل الخروج
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) { // التحقق من mounted قبل استخدام context
        Navigator.of(context).pushReplacementNamed('/login');
        _showSuccessSnackBar(context, 'تم تسجيل الخروج بنجاح.');
      }
    } catch (e) {
      if (mounted) { // التحقق من mounted قبل استخدام context
        _showErrorSnackBar(context, 'فشل تسجيل الخروج: $e');
      }
    }
  }

  // دالة مساعدة لعرض SnackBar للأخطاء
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return; // تحقق إضافي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  // دالة مساعدة لعرض SnackBar للنجاح
  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return; // تحقق إضافي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
      ),
    );
  }

  // مكون مساعد لعرض معلومات المشروع الرئيسية
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              textDirection: TextDirection.rtl, // لضمان محاذاة النص داخل RichText
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                  ),
                  TextSpan(
                    text: ' $value',
                    style: TextStyle(
                      fontSize: 16,
                      color: valueColor ?? AppConstants.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // مكون مساعد لعرض قسم الصور
  // تم تحسينه للتعامل مع عدم وجود الصورة (placeholder)
  Widget _buildImageSection(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink(); // لا تعرض القسم إذا لم تكن هناك صورة
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textColor),
        ),
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200, // حافظ على نفس الارتفاع حتى لو فشلت الصورة
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      const Text('فشل تحميل الصورة', style: TextStyle(color: AppConstants.secondaryTextColor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.itemSpacing),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحقق من وجود UID للعميل. إذا لم يكن موجودًا، أظهر رسالة خطأ.
    if (_currentClientUid == null) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text('خطأ', style: TextStyle(color: Colors.white)),
          backgroundColor: AppConstants.primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: AppConstants.errorColor),
              const SizedBox(height: AppConstants.itemSpacing),
              Text(
                'فشل تحميل معلومات المستخدم. الرجاء تسجيل الدخول مرة أخرى.',
                style: TextStyle(fontSize: 18, color: AppConstants.textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.itemSpacing),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl, // جعل الواجهة من اليمين لليسار
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: Text(
            _clientName != null ? 'مرحباً، $_clientName!' : 'لوحة تحكم العميل',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: AppConstants.primaryColor,
          elevation: 4,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
            ),
          ],
        ),
        body: FutureBuilder<QuerySnapshot>(
          // استخدام FutureBuilder لجلب المشروع الخاص بالعميل
          future: FirebaseFirestore.instance
              .collection('projects')
              .where('clientId', isEqualTo: _currentClientUid)
              .limit(1) // نفترض أن العميل الواحد له مشروع واحد فقط
              .get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (projectSnapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ في تحميل بيانات المشروع: ${projectSnapshot.error}',
                  style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!projectSnapshot.hasData || projectSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_off, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Text(
                      'لم يتم ربط حسابك بأي مشروع حتى الآن.',
                      style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    Text(
                      'الرجاء التواصل مع إدارة المشروع لمزيد من المعلومات.',
                      style: TextStyle(fontSize: 14, color: AppConstants.secondaryTextColor.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final projectDoc = projectSnapshot.data!.docs.first;
            final projectId = projectDoc.id;
            final projectData = projectDoc.data() as Map<String, dynamic>;
            final projectName = projectData['name'] as String? ?? 'مشروع غير مسمى';
            final currentStageNumber = projectData['currentStage'] as int? ?? 1;
            final currentPhaseName = projectData['currentPhaseName'] as String? ?? 'غير محددة'; // Fetch current phase name
            final engineerName = projectData['engineerName'] as String? ?? 'غير معروف'; // جلب اسم المهندس مباشرة من المشروع
            final projectStatus = projectData['status'] as String? ?? 'غير محدد';
            final generalNotes = projectData['generalNotes'] as String? ?? ''; // ملاحظات عامة للمشروع

            return SingleChildScrollView( // لضمان إمكانية التمرير للمحتوى الكبير
              padding: const EdgeInsets.all(AppConstants.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // قسم معلومات المشروع الرئيسية
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    color: AppConstants.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            projectName,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(height: AppConstants.itemSpacing / 2),
                          // Display current phase number and name
                          _buildInfoRow(Icons.calendar_today, 'المرحلة الحالية:', '$currentStageNumber - $currentPhaseName'),
                          _buildInfoRow(Icons.engineering, 'المهندس المسؤول:', engineerName),
                          _buildInfoRow(Icons.info_outline, 'حالة المشروع:', projectStatus,
                              valueColor: (projectStatus == 'نشط')
                                  ? AppConstants.successColor
                                  : (projectStatus == 'مكتمل')
                                  ? Colors.blue
                                  : AppConstants.warningColor),
                          if (generalNotes.isNotEmpty) ...[
                            const Divider(height: AppConstants.itemSpacing * 2, thickness: 1),
                            Text(
                              'ملاحظات عامة من المهندس:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textColor,
                              ),
                            ),
                            const SizedBox(height: AppConstants.itemSpacing / 2),
                            Text(
                              generalNotes,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppConstants.secondaryTextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.itemSpacing * 1.5),

                  // عنوان قسم المراحل المكتملة
                  Text(
                    'المراحل المكتملة:',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),

                  // قائمة المراحل المكتملة
                  StreamBuilder<QuerySnapshot>(
                    // استخدام StreamBuilder لمراقبة المراحل المكتملة في الوقت الفعلي
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(projectId)
                        .collection('phases')
                        .where('completed', isEqualTo: true)
                        .orderBy('number')
                        .snapshots(),
                    builder: (context, phaseSnapshot) {
                      if (phaseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
                      }
                      if (phaseSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'حدث خطأ في تحميل المراحل: ${phaseSnapshot.error}',
                            style: TextStyle(color: AppConstants.errorColor, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!phaseSnapshot.hasData || phaseSnapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.checklist_rtl, size: 80, color: AppConstants.secondaryTextColor.withOpacity(0.5)),
                              const SizedBox(height: AppConstants.itemSpacing),
                              Text(
                                'لا توجد مراحل مكتملة لهذا المشروع حتى الآن.',
                                style: TextStyle(fontSize: 18, color: AppConstants.secondaryTextColor),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final completedPhases = phaseSnapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true, // مهم داخل SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // لتمكين SingleChildScrollView من التمرير
                        itemCount: completedPhases.length,
                        itemBuilder: (context, index) {
                          final phase = completedPhases[index];
                          final data = phase.data() as Map<String, dynamic>;
                          final number = data['number'] as int? ?? (index + 1);
                          final name = data['name'] as String? ?? 'مرحلة غير مسمى'; // Get phase name
                          final note = data['note'] as String? ?? '';
                          final imageUrl = data['imageUrl'] as String?;
                          final image360Url = data['image360Url'] as String?;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                            ),
                            child: ExpansionTile(
                              collapsedBackgroundColor: AppConstants.successColor.withOpacity(0.1),
                              backgroundColor: AppConstants.successColor.withOpacity(0.05),
                              leading: CircleAvatar(
                                backgroundColor: AppConstants.successColor,
                                child: Text(
                                  number.toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                'المرحلة $number: $name', // Display phase number and name
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textColor,
                                ),
                              ),
                              subtitle: Text(
                                'مكتملة ✅',
                                style: TextStyle(
                                  color: AppConstants.successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppConstants.padding, vertical: AppConstants.itemSpacing / 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (note.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'الملاحظات:',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppConstants.textColor),
                                            ),
                                            Text(
                                              note,
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  color: AppConstants.secondaryTextColor),
                                            ),
                                            const SizedBox(height: AppConstants.itemSpacing),
                                          ],
                                        ),
                                      // استخدام الدالة المساعدة لعرض الصور
                                      _buildImageSection('صورة عادية:', imageUrl),
                                      _buildImageSection('صورة 360°:', image360Url),
                                      if (note.isEmpty &&
                                          (imageUrl == null || imageUrl.isEmpty) &&
                                          (image360Url == null || image360Url.isEmpty))
                                        Text(
                                          'لا توجد تفاصيل إضافية لهذه المرحلة.',
                                          style: TextStyle(
                                              fontSize: 15,
                                              color: AppConstants.secondaryTextColor.withOpacity(0.7)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}