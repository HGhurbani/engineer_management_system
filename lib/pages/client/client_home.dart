// lib/pages/client/client_home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // For TextDirection

// Constants for consistent styling, aligned with the admin dashboard's style.
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const double paddingLarge = 24.0;
  static const double paddingMedium = 16.0;
  static const double paddingSmall = 8.0;
  static const double borderRadius = 16.0;
  static const double itemSpacing = 16.0;
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
        color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
}

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  final String? _currentClientUid = FirebaseAuth.instance.currentUser?.uid; //
  String? _clientName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_currentClientUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logout();
      });
    } else {
      _fetchClientData(); //
    }
  }

  Future<void> _fetchClientData() async { //
    setState(() => _isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentClientUid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _clientName = userDoc.data()?['name'] as String?;
        });
      }
    } catch (e) {
      print('Error fetching client name: $e');
      if (mounted) _showFeedbackSnackBar(context, 'فشل تحميل بياناتك.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async { //
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
        _showFeedbackSnackBar(context, 'تم تسجيل الخروج بنجاح.', isError: false);
      }
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل تسجيل الخروج: $e', isError: true);
    }
  }

  void _showFeedbackSnackBar(BuildContext context, String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
        margin: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isExpandable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Text('$label ', style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: isExpandable
                ? ExpandableText(value, valueColor: valueColor) // Assuming ExpandableText is defined
                : Text(
              value,
              style: TextStyle(fontSize: 15, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: isExpandable ? null : 3, // Allow more lines for notes
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String title, String? imageUrl) { //
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
        const SizedBox(height: AppConstants.paddingSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
          child: Image.network(
            imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 180, alignment: Alignment.center, child: const CircularProgressIndicator(color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => Container(height: 180, width: double.infinity, color: AppConstants.backgroundColor, child: const Icon(Icons.broken_image_outlined, color: AppConstants.textSecondary, size: 50)),
          ),
        ),
        const SizedBox(height: AppConstants.itemSpacing),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _clientName != null ? 'أهلاً بك، $_clientName' : 'لوحة تحكم العميل',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22),
      ),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      elevation: 3,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          tooltip: 'الإشعارات',
          onPressed: () => Navigator.pushNamed(context, '/notifications'), //
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          tooltip: 'تسجيل الخروج',
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildErrorState(String message, {bool showLogoutButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 70, color: AppConstants.errorColor),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.textPrimary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            if (showLogoutButton) ...[
              const SizedBox(height: AppConstants.paddingLarge),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {IconData icon = Icons.folder_off_outlined}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppConstants.textSecondary.withOpacity(0.4)),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.textSecondary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.paddingSmall),
            Text('الرجاء التواصل مع إدارة المشروع لمزيد من المعلومات.', style: TextStyle(fontSize: 14, color: AppConstants.textSecondary.withOpacity(0.7)), textAlign: TextAlign.center), //
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: _buildAppBar(), body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)));
    }
    if (_currentClientUid == null) {
      return Scaffold(
          backgroundColor: AppConstants.backgroundColor,
          appBar: AppBar(title: const Text('خطأ', style: TextStyle(color: Colors.white)), backgroundColor: AppConstants.primaryColor),
          body: _buildErrorState('فشل تحميل معلومات المستخدم. الرجاء تسجيل الدخول مرة أخرى.', showLogoutButton: true)
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: FutureBuilder<QuerySnapshot>( //
          future: FirebaseFirestore.instance.collection('projects').where('clientId', isEqualTo: _currentClientUid).limit(1).get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (projectSnapshot.hasError) {
              return _buildErrorState('حدث خطأ في تحميل بيانات المشروع: ${projectSnapshot.error}');
            }
            if (!projectSnapshot.hasData || projectSnapshot.data!.docs.isEmpty) {
              return _buildEmptyState('لم يتم ربط حسابك بأي مشروع حتى الآن.'); //
            }

            final projectDoc = projectSnapshot.data!.docs.first;
            final projectId = projectDoc.id;
            final projectData = projectDoc.data() as Map<String, dynamic>;

            return RefreshIndicator(
              onRefresh: () async {
                if(mounted) {
                  setState(() {
                    // This will trigger the FutureBuilder to re-fetch project data
                    // and subsequently the StreamBuilder for phases will also update.
                  });
                }
              },
              color: AppConstants.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProjectSummaryCard(projectData), // New helper for summary
                    const SizedBox(height: AppConstants.paddingLarge),
                    const Text('المراحل المكتملة:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                    const SizedBox(height: AppConstants.itemSpacing),
                    _buildCompletedPhasesList(projectId), // New helper for phases list
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProjectSummaryCard(Map<String, dynamic> projectData) {
    final projectName = projectData['name'] ?? 'مشروع غير مسمى';
    final engineerName = projectData['engineerName'] ?? 'غير محدد'; //
    final projectStatus = projectData['status'] ?? 'غير محدد';
    final generalNotes = projectData['generalNotes'] ?? ''; //
    final currentStageNumber = projectData['currentStage'] ?? 0; //
    final currentPhaseName = projectData['currentPhaseName'] ?? 'غير محددة'; //

    IconData statusIcon;
    Color statusColor;
    switch (projectStatus) {
      case 'نشط': statusIcon = Icons.construction_rounded; statusColor = AppConstants.infoColor; break;
      case 'مكتمل': statusIcon = Icons.check_circle_outline_rounded; statusColor = AppConstants.successColor; break;
      case 'معلق': statusIcon = Icons.pause_circle_outline_rounded; statusColor = AppConstants.warningColor; break;
      default: statusIcon = Icons.help_outline_rounded; statusColor = AppConstants.textSecondary;
    }

    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
            const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
            _buildDetailRow(Icons.engineering_rounded, 'المهندس المسؤول:', engineerName),
            _buildDetailRow(statusIcon, 'حالة المشروع:', projectStatus, valueColor: statusColor),
            _buildDetailRow(Icons.stairs_rounded, 'المرحلة الحالية:', '$currentStageNumber - $currentPhaseName'),
            if (generalNotes.isNotEmpty) ...[
              const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
              _buildDetailRow(Icons.speaker_notes_rounded, 'ملاحظات عامة من المهندس:', generalNotes, isExpandable: true), //
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedPhasesList(String projectId) {
    return StreamBuilder<QuerySnapshot>( //
      stream: FirebaseFirestore.instance.collection('projects').doc(projectId).collection('phases')
          .where('completed', isEqualTo: true).orderBy('number').snapshots(),
      builder: (context, phaseSnapshot) {
        if (phaseSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (phaseSnapshot.hasError) {
          return _buildErrorState('حدث خطأ في تحميل المراحل المكتملة.');
        }
        if (!phaseSnapshot.hasData || phaseSnapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد مراحل مكتملة لعرضها حالياً.', icon: Icons.checklist_rtl_rounded); //
        }

        final completedPhases = phaseSnapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: completedPhases.length,
          itemBuilder: (context, index) {
            final phase = completedPhases[index];
            final data = phase.data() as Map<String, dynamic>;
            final number = data['number'] ?? (index + 1);
            final name = data['name'] ?? 'مرحلة غير مسمى'; //
            final note = data['note'] ?? '';
            final imageUrl = data['imageUrl'] as String?;
            final image360Url = data['image360Url'] as String?;
            final hasSubPhases = data['hasSubPhases'] ?? false; //

            return Card(
              margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
              elevation: 1.5,
              shadowColor: AppConstants.primaryColor.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
              child: ExpansionTile(
                collapsedIconColor: AppConstants.primaryLight,
                iconColor: AppConstants.primaryColor,
                leading: CircleAvatar(
                  backgroundColor: AppConstants.successColor,
                  child: Text(number.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text('المرحلة $number: $name', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                subtitle: const Text('مكتملة ✅', style: TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.w500)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium).copyWith(top: AppConstants.paddingSmall),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.isNotEmpty) ...[
                          const Text('الملاحظات:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                          const SizedBox(height: AppConstants.paddingSmall / 2),
                          ExpandableText(note, valueColor: AppConstants.textSecondary),
                          const SizedBox(height: AppConstants.itemSpacing),
                        ],
                        _buildImageSection('صورة عادية:', imageUrl),
                        _buildImageSection('صورة 360°:', image360Url),
                        if (note.isEmpty && (imageUrl == null || imageUrl.isEmpty) && (image360Url == null || image360Url.isEmpty) && !hasSubPhases)
                          const Text('لا توجد تفاصيل إضافية لهذه المرحلة.', style: TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                        if (hasSubPhases) _buildCompletedSubPhasesList(projectId, phase.id), //
                      ],
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

  Widget _buildCompletedSubPhasesList(String projectId, String phaseId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppConstants.itemSpacing * 1.5, thickness: 0.5),
        const Text('المراحل الفرعية المكتملة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
        const SizedBox(height: AppConstants.paddingSmall),
        StreamBuilder<QuerySnapshot>( //
          stream: FirebaseFirestore.instance.collection('projects').doc(projectId).collection('phases').doc(phaseId)
              .collection('subPhases').where('completed', isEqualTo: true).orderBy('timestamp').snapshots(),
          builder: (context, subPhaseSnapshot) {
            if (subPhaseSnapshot.connectionState == ConnectionState.waiting) return const Center(child: SizedBox(height:25, width:25, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryColor)));
            if (subPhaseSnapshot.hasError) return Text('خطأ: ${subPhaseSnapshot.error}', style: const TextStyle(color: AppConstants.errorColor));
            if (!subPhaseSnapshot.hasData || subPhaseSnapshot.data!.docs.isEmpty) return const Text('لا توجد مراحل فرعية مكتملة.', style: TextStyle(color: AppConstants.textSecondary)); //

            final completedSubPhases = subPhaseSnapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedSubPhases.length,
              itemBuilder: (context, subIndex) {
                final subPhase = completedSubPhases[subIndex];
                final subData = subPhase.data() as Map<String, dynamic>;
                final String subName = subData['name'] ?? 'مرحلة فرعية غير مسمى';
                final String subNote = subData['note'] ?? '';
                final String? subImageUrl = subData['imageUrl'];
                final String? subImage360Url = subData['image360Url'];

                return Card( // Wrap sub-phase in a light card for better separation
                  elevation: 0.5,
                  color: AppConstants.successColor.withOpacity(0.03),
                  margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  child: ExpansionTile( // Allow expanding sub-phases too
                    leading: const Icon(Icons.check_circle_outline_rounded, color: AppConstants.successColor, size: 20),
                    title: Text(subName, style: const TextStyle(fontWeight: FontWeight.w500, color: AppConstants.textPrimary, fontSize: 14.5)),
                    subtitle: const Text('مكتملة', style: TextStyle(color: AppConstants.successColor, fontSize: 12)),
                    tilePadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: 0),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                    children: [
                      if (subNote.isNotEmpty) ...[
                        const Text('ملاحظات فرعية:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                        const SizedBox(height: AppConstants.paddingSmall / 2),
                        ExpandableText(subNote, valueColor: AppConstants.textSecondary, trimLines: 1),
                        const SizedBox(height: AppConstants.itemSpacing /2),
                      ],
                      _buildImageSection('صورة فرعية عادية:', subImageUrl), //
                      _buildImageSection('صورة فرعية 360°:', subImage360Url), //
                      if (subNote.isEmpty && (subImageUrl == null || subImageUrl.isEmpty) && (subImage360Url == null || subImage360Url.isEmpty))
                        const Text('لا توجد تفاصيل إضافية لهذه المرحلة الفرعية.', style: TextStyle(fontSize: 13, color: AppConstants.textSecondary)), //
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// Helper widget for expandable text (same as in other detail pages)
class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final Color? valueColor;

  const ExpandableText(this.text, {super.key, this.trimLines = 2, this.valueColor});

  @override
  ExpandableTextState createState() => ExpandableTextState();
}

class ExpandableTextState extends State<ExpandableText> {
  bool _readMore = true;
  void _onTapLink() {
    setState(() => _readMore = !_readMore);
  }

  @override
  Widget build(BuildContext context) {
    TextSpan link = TextSpan(
        text: _readMore ? " عرض المزيد" : " عرض أقل",
        style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w600, fontSize: 14),
        recognizer: TapGestureRecognizer()..onTap = _onTapLink
    );
    Widget result = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        assert(constraints.hasBoundedWidth);
        final double maxWidth = constraints.maxWidth;
        final text = TextSpan(text: widget.text, style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5));
        TextPainter textPainter = TextPainter(
          text: link,
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          maxLines: widget.trimLines,
          ellipsis: '...',
        );
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final linkSize = textPainter.size;
        textPainter.text = text;
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final textSize = textPainter.size;
        int endIndex = textPainter.getPositionForOffset(Offset(textSize.width - linkSize.width, textSize.height)).offset;
        TextSpan textSpan;
        if (textPainter.didExceedMaxLines) {
          textSpan = TextSpan(
            text: _readMore && widget.text.length > endIndex ? widget.text.substring(0, endIndex) + "..." : widget.text,
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5),
            children: <TextSpan>[link],
          );
        } else {
          textSpan = TextSpan(text: widget.text, style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5));
        }
        return RichText(
          softWrap: true,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          text: textSpan,
        );
      },
    );
    return result;
  }
}