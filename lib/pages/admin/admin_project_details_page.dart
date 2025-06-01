// lib/pages/admin/admin_project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // لا يزال يستخدم في _showAddNoteOrImageDialog الخاصة بالمسؤول
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // لا يزال يستخدم في _showAddNoteOrImageDialog الخاصة بالمسؤول
import 'dart:io'; // لا يزال يستخدم في _showAddNoteOrImageDialog الخاصة بالمسؤول
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;

import 'edit_assigned_engineers_page.dart';

// ... (AppConstants class remains the same) ...
class AppConstants {
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color cardColor = Colors.white;
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color deleteColor = errorColor;
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


class AdminProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const AdminProjectDetailsPage({super.key, required this.projectId});

  @override
  State<AdminProjectDetailsPage> createState() =>
      _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> with TickerProviderStateMixin {
  Key _projectFutureBuilderKey = UniqueKey();
  String? _currentUserRole;
  bool _isPageLoading = true;
  DocumentSnapshot? _projectDataSnapshot;

  late TabController _tabController;
  List<QueryDocumentSnapshot> _allAvailableEngineers = [];

  String? _clientTypeKeyFromFirestore;
  String? _clientTypeDisplayString;

  // ... (predefinedPhasesStructure and finalCommissioningTests remain the same) ...
  static const List<Map<String, dynamic>> predefinedPhasesStructure = [
    // ... (هيكل المراحل كما هو)
    {
      'id': 'phase_01', // معرّف فريد لكل مرحلة
      'name': 'تأسيس الميدة',
      'subPhases': [
        {'id': 'sub_01_01', 'name': 'أعمال السباكة: تركيب سليفات لأنظمة الصرف الصحي'},
        {'id': 'sub_01_02', 'name': 'أعمال السباكة: تثبيت وتوازن أنابيب الصرف والتهوية الرأسية'},
        {'id': 'sub_01_03', 'name': 'أعمال السباكة: تمديد مواسير تغذية المياه'},
        {'id': 'sub_01_04', 'name': 'أعمال السباكة: تأمين وتسكير الفتحات باستخدام الشريط الأسود'},
        {'id': 'sub_01_05', 'name': 'أعمال الكهرباء: تأسيس مواسير لمسارات الكوابل (كيبل واحد لكل ماسورة)'},
        {'id': 'sub_01_06', 'name': 'أعمال الكهرباء: تمديد مواسير التيار الخفيف وتحديد مكان لوحة المفاتيح'},
        {'id': 'sub_01_07', 'name': 'أعمال الكهرباء: تأسيس سليف للطاقة الشمسية'},
        {'id': 'sub_01_08', 'name': 'أعمال الكهرباء: تأمين وتسكير المواسير والسليفات بالشريط الأسود'},
        {'id': 'sub_01_09', 'name': 'أعمال الكهرباء: تأريض الأعمدة'},
      ]
    },
    {
      'id': 'phase_02',
      'name': 'أعمال الصرف الصحي ٦ إنش',
      'subPhases': [
        {'id': 'sub_02_01', 'name': 'تحديد مواقع كراسي الحمامات وأنواعها'},
        {'id': 'sub_02_02', 'name': 'التأكد من ميول المواسير'},
        {'id': 'sub_02_03', 'name': 'فحص مواقع الصفايات'},
        {'id': 'sub_02_04', 'name': 'تأكيد مواقع الكلين آوت وأبعادها'},
        {'id': 'sub_02_05', 'name': 'إغلاق الفتحات بالكاب أو الشريط الأسود'},
        {'id': 'sub_02_06', 'name': 'تثبيت المواسير أرضياً'},
        {'id': 'sub_02_07', 'name': 'استخدام المنظف قبل الغراء'},
        {'id': 'sub_02_08', 'name': 'ضمان تطبيق الغراء بشكل صحيح'},
        {'id': 'sub_02_09', 'name': 'تركيب رداد عند نهاية الماسورة المرتبطة بشركة المياه'},
        {'id': 'sub_02_10', 'name': 'إجراء اختبار التسرب بالماء'},
      ]
    },
    {
      'id': 'phase_03',
      'name': 'تمديد مواسير السباكة في الحوائط',
      'subPhases': [
        {'id': 'sub_03_01', 'name': 'التأكد من التثبيت الجيد وتوازن المواسير'},
        {'id': 'sub_03_02', 'name': 'فحص الطول المناسب لكل خط'},
        {'id': 'sub_03_03', 'name': 'تأمين وتسكير الفتحات بالشريط الأسود أو القطن'},
      ]
    },
    {
      'id': 'phase_04',
      'name': 'كهرباء الدرج والعتبات',
      'subPhases': [
        {'id': 'sub_04_01', 'name': 'تحديد مواقع الإنارة حسب المخططات'},
        {'id': 'sub_04_02', 'name': 'تثبيت وتربيط المواسير بإحكام'},
        {'id': 'sub_04_03', 'name': 'إنارة أسفل الدرج'},
        {'id': 'sub_04_04', 'name': 'تمديد ماسورة لمفتاح مزدوج الاتجاه'},
      ]
    },
    {
      'id': 'phase_05',
      'name': 'أعمدة سور الفيلا الخارجي',
      'subPhases': [
        {'id': 'sub_05_01', 'name': 'تحديد موقع الإنتركم وإنارات السور'},
        {'id': 'sub_05_02', 'name': 'تثبيت المواسير جيداً'},
        {'id': 'sub_05_03', 'name': 'تركيب علب الكهرباء وتحديد المنسوب وتثبيتها'},
      ]
    },
    {
      'id': 'phase_06',
      'name': 'أعمال الأسقف',
      'subPhases': [
        {'id': 'sub_06_01', 'name': 'أعمال الكهرباء: تمديد المواسير وتثبيت العلب بشكل جيد'},
        {'id': 'sub_06_02', 'name': 'أعمال الكهرباء: تعليق المواسير في الجسور والحديد'},
        {'id': 'sub_06_03', 'name': 'أعمال الكهرباء: تنظيم المسافات بين المواسير'},
        {'id': 'sub_06_04', 'name': 'أعمال الكهرباء: حماية العلب بالشريط اللاصق وتثبيتها جيداً'},
        {'id': 'sub_06_05', 'name': 'أعمال الكهرباء: تسكير الفتحات المعتمدة بالفوم والتأكد من الإحكام'},
        {'id': 'sub_06_06', 'name': 'أعمال الكهرباء: تمديد شبكة التيار الخفيف'},
        {'id': 'sub_06_07', 'name': 'أعمال الكهرباء: تمديد سليفات بين الجسور للكهرباء المعلقة'},
        {'id': 'sub_06_08', 'name': 'أعمال السباكة: فحص مواقع سليفات الجسور للسباكة المعلقة'},
        {'id': 'sub_06_09', 'name': 'أعمال السباكة: فحص مواقع سليفات الصرف الصحي ومياه الأمطار'},
        {'id': 'sub_06_10', 'name': 'أعمال السباكة: تركيب سليفات مراوح الشفط بدون تعارض مع الديكور'},
        {'id': 'sub_06_11', 'name': 'أعمال السباكة: تركيب وتوازن مواسير وسليفات تغذية الحمامات والمطابخ'},
        {'id': 'sub_06_12', 'name': 'أعمال السباكة: تركيب صحيح لقطع T للصرف والتهوية وحمايتها بالشريط الأسود'},
        {'id': 'sub_06_13', 'name': 'أعمال السباكة: تأمين وتسكير فتحات المواسير كاملة بالشريط الأسود'},
        {'id': 'sub_06_14', 'name': 'أعمال السباكة: تأسيس منفذ هواء لمجفف الغسيل حسب رغبة العميل'},
        {'id': 'sub_06_15', 'name': 'أعمال السباكة: مناسيب الكراسي والصفايات موضحة حسب المواصفات'},
      ]
    },
    {
      'id': 'phase_07',
      'name': 'تمديد الإنارة في الجدران',
      'subPhases': [
        {'id': 'sub_07_01', 'name': 'أعمال الكهرباء: تمديد المواسير حسب توزيع الإنارة في المخطط'},
        {'id': 'sub_07_02', 'name': 'أعمال الكهرباء: الحد الأدنى ٢ متر لكل نقطة إنارة'},
      ]
    },
    {
      'id': 'phase_08',
      'name': 'مرحلة التمديدات',
      'subPhases': [
        {'id': 'sub_08_01', 'name': 'أعمال الكهرباء: تحديد نقاط مخارج الكهرباء حسب المخطط أو العميل'},
        {'id': 'sub_08_02', 'name': 'أعمال الكهرباء: تحديد المناسيب بالليزر'},
        {'id': 'sub_08_03', 'name': 'أعمال الكهرباء: القص بالصاروخ'},
        {'id': 'sub_08_04', 'name': 'أعمال الكهرباء: تنظيف الربش والكسارات يومياً'},
        {'id': 'sub_08_05', 'name': 'أعمال الكهرباء: تثبيت العلب من الخلف والجوانب، ومراعاة البروز'},
        {'id': 'sub_08_06', 'name': 'أعمال الكهرباء: ستاندر المطابخ: مخرج كهرباء لكل ١ متر'},
        {'id': 'sub_08_07', 'name': 'أعمال الكهرباء: تركيب علب ٠.٣٠×٠.٣٠ سم للأفران والشوايات'},
        {'id': 'sub_08_08', 'name': 'أعمال الكهرباء: تركيب الطبلونات حسب المواقع'},
        {'id': 'sub_08_09', 'name': 'أعمال الكهرباء: تحديد ألوان الأسلاك وسحبها حسب الاستاندر'},
        {'id': 'sub_08_10', 'name': 'أعمال الكهرباء: خط رئيسي للإنارة، ومخارج الكهرباء، والتكييف'},
        {'id': 'sub_08_11', 'name': 'أعمال الكهرباء: ربط الخزانات الأرضية والعلوية للعوامة'},
        {'id': 'sub_08_12', 'name': 'أعمال الكهرباء: تأريض لجميع العلب'},
        {'id': 'sub_08_13', 'name': 'أعمال الكهرباء: تأريض علب المطابخ والغسيل'},
        {'id': 'sub_08_14', 'name': 'أعمال الكهرباء: تمديد مواسير مرنة مخصصة للإنارة المعلقة داخل الأسقف الجبسية'},
        {'id': 'sub_08_15', 'name': 'أعمال الكهرباء: تثبيت علب الإنارة خلف فتحات السبوت لايت حسب التصميم'},
        {'id': 'sub_08_16', 'name': 'أعمال الكهرباء: توصيل جميع نقاط الإنارة المعلقة بخط مستقل من الطبلون'},
        {'id': 'sub_08_17', 'name': 'أعمال الكهرباء: استخدام كيابل مقاومة للحرارة حسب المواصفات الفنية'},
        {'id': 'sub_08_18', 'name': 'أعمال الكهرباء: تحديد مواقع الإنارة المعلقة بدقة وتجنب التعارض مع فتحات التكييف أو الستائر'},
        {'id': 'sub_08_19', 'name': 'أعمال الكهرباء: عدم تمرير كيابل الكهرباء بجانب كيابل الصوت أو البيانات لتفادي التداخل'},
        {'id': 'sub_08_20', 'name': 'أعمال الكهرباء: استخدام أربطة تثبيت وعدم الاعتماد على الشريط اللاصق فقط'},
        {'id': 'sub_08_21', 'name': 'أعمال الكهرباء: تمرير السليفات بين الجسور لتسهيل تمديد الأسلاك بشكل خفي'},
        {'id': 'sub_08_22', 'name': 'أعمال الكهرباء: تسمية كل نقطة لسهولة الصيانة لاحقاً'},
        {'id': 'sub_08_23', 'name': 'أعمال الكهرباء: الابتعاد عن الشبابيك والأبواب ٠.٢٥ سم على الأقل'},
        {'id': 'sub_08_24', 'name': 'أعمال الكهرباء: تحديد منطقة كنترول للتيار الخفيف'},
        {'id': 'sub_08_25', 'name': 'أعمال الكهرباء: فصل شبكة التيار الخفيف عن الكهرباء'},
        {'id': 'sub_08_26', 'name': 'أعمال الكهرباء: تمديد شبكات التلفزيون، الإنترنت، الصوتيات، والواي فاي'},
        {'id': 'sub_08_27', 'name': 'أعمال الكهرباء: لكل نقطة تلفزيون: ٣ مخارج كهرباء + نقطة إنترنت'},
        {'id': 'sub_08_28', 'name': 'أعمال الكهرباء: تمديد الكابلات الرئيسية لكل لوحة مفاتيح'},
        {'id': 'sub_08_29', 'name': 'أعمال الكهرباء: تركيب باس بار رئيسي داخل سور المبنى'},
        {'id': 'sub_08_30', 'name': 'أعمال الكهرباء: قاطع خاص للمصعد'},
        {'id': 'sub_08_31', 'name': 'أعمال الكهرباء: لوحة مفاتيح مستقلة لكل دور وللحوش'},
        {'id': 'sub_08_32', 'name': 'أعمال الكهرباء: لوحات وقواطع خاصة بالتكييف حسب الطلب'},
        {'id': 'sub_08_33', 'name': 'أعمال السباكة: تمديد مواسير التغذية بين الخزانات'},
        {'id': 'sub_08_34', 'name': 'أعمال السباكة: تمديد ماسورة الماء الحلو من الشارع إلى الخزان ثم الفيلا'},
        {'id': 'sub_08_35', 'name': 'أعمال السباكة: تمديد ٢ إنش للوايت و١ إنش لعداد المياه'},
        {'id': 'sub_08_36', 'name': 'أعمال السباكة: خط تغذية بارد ٢ إنش وحار ١ إنش لكل دور'},
        {'id': 'sub_08_37', 'name': 'أعمال السباكة: تمديد خط راجع ٣/٤ للماء الحار حسب الاتفاق'},
        {'id': 'sub_08_38', 'name': 'أعمال السباكة: تباعد التعليقات حسب الاستاندر باستخدام الشنل والرود'},
        {'id': 'sub_08_39', 'name': 'أعمال السباكة: استخدام أكواع حرارية بزاوية ٤٥ درجة وتجنب استخدام كوع ٩٠'},
        {'id': 'sub_08_40', 'name': 'أعمال السباكة: توزيع الحمامات والمطابخ حسب المخطط أو اتفاق العميل'},
        {'id': 'sub_08_41', 'name': 'أعمال السباكة: تركيب فاصل بين الحار والبارد داخل الجدار'},
        {'id': 'sub_08_42', 'name': 'أعمال السباكة: تركيب خلاطات مدفونة حسب الاتفاق'},
        {'id': 'sub_08_43', 'name': 'أعمال السباكة: الدش المطري بارتفاع ٢.٢٠ م'},
        {'id': 'sub_08_44', 'name': 'أعمال السباكة: سيفون مخفي للمرحاض العربي'},
        {'id': 'sub_08_45', 'name': 'أعمال السباكة: تأكيد تمديد ماسورة ماء حلو ٣/٤ للمطبخ'},
        {'id': 'sub_08_46', 'name': 'أعمال السباكة: تثبيت مواسير تصريف ٢ إنش تحت المغاسل'},
        {'id': 'sub_08_47', 'name': 'أعمال السباكة: تركيب بكس ٠.٤٠×٠.٤٠ سم لغرف الغسيل'},
        {'id': 'sub_08_48', 'name': 'أعمال السباكة: اختبار الضغط وتثبيت ساعة الضغط لكل دور'},
        {'id': 'sub_08_49', 'name': 'أعمال السباكة: تثبيت نقاط إسمنتية بعد الاختبارات'},
      ]
    },
    {
      'id': 'phase_09',
      'name': 'الصرف الصحي وتصريف الأمطار الداخلي',
      'subPhases': [
        {'id': 'sub_09_01', 'name': 'تعليق وتثبيت المواسير والقطع الصغيرة حسب الاستاندر'},
        {'id': 'sub_09_02', 'name': 'فحص الميول بشكل دقيق'},
        {'id': 'sub_09_03', 'name': 'تسكير الفتحات بإحكام'},
        {'id': 'sub_09_04', 'name': 'تركيب رداد للمرحاض العربي حسب الرغبة'},
        {'id': 'sub_09_05', 'name': 'اختبار شبكة الصرف بالماء'},
        {'id': 'sub_09_06', 'name': 'تركيب المرحاض العربي: قاعدة رملية'},
        {'id': 'sub_09_07', 'name': 'تركيب المرحاض العربي: إسمنت جانبي'},
        {'id': 'sub_09_08', 'name': 'تركيب المرحاض العربي: توصيل المرحاض بماسورة السيفون'},
        {'id': 'sub_09_09', 'name': 'تركيب المرحاض العربي: تركيب رداد ٤ إنش'},
      ]
    },
    {
      'id': 'phase_10',
      'name': 'أعمال الحوش',
      'subPhases': [
        {'id': 'sub_10_01', 'name': 'أعمال الكهرباء: توصيل تأريض الأعمدة'},
        {'id': 'sub_10_02', 'name': 'أعمال الكهرباء: تركيب بوكس التأريض وربط النحاس بالحوش'},
        {'id': 'sub_10_03', 'name': 'أعمال الكهرباء: توصيل الباس بار للتأريض'},
        {'id': 'sub_10_04', 'name': 'أعمال الكهرباء: إكمال إنارة الحوش والحديقة'},
        {'id': 'sub_10_05', 'name': 'أعمال الكهرباء: تمديد نقاط الكهرباء للكراج'},
        {'id': 'sub_10_06', 'name': 'أعمال الكهرباء: تركيب شاحن سيارة'},
        {'id': 'sub_10_07', 'name': 'أعمال الكهرباء: تثبيت طبلون الحوش'},
        {'id': 'sub_10_08', 'name': 'أعمال السباكة: تمديد نقاط الغسيل بالحوش بعد الصب'},
      ]
    },
    {
      'id': 'phase_11',
      'name': 'الأعمال بعد اللياسة',
      'subPhases': [
        {'id': 'sub_11_01', 'name': 'أعمال السباكة: تركيب سيفون الكرسي المعلق بمنسوب ٠.٣٣ سم'},
        {'id': 'sub_11_02', 'name': 'أعمال السباكة: شبكه بنقطة الصرف والتغذية'},
        {'id': 'sub_11_03', 'name': 'أعمال السباكة: تثبيت الشطاف المدفون'},
      ]
    },
    {
      'id': 'phase_12',
      'name': 'أعمال السطح بعد العزل',
      'subPhases': [
        {'id': 'sub_12_01', 'name': 'ربط تغذية الخزان العلوي من الأرضي فوق العزل'},
        {'id': 'sub_12_02', 'name': 'نقاط غسيل السطح'},
        {'id': 'sub_12_03', 'name': 'تصريف التكييف والغليونات: تمديد ماسورة تصريف ١ إنش لكل مكيف'},
        {'id': 'sub_12_04', 'name': 'تصريف التكييف والغليونات: استخدام كوع ٤٥ بارتفاع ٥ سم عن الأرض'},
        {'id': 'sub_12_05', 'name': 'تصريف التكييف والغليونات: فحص الميول'},
        {'id': 'sub_12_06', 'name': 'تصريف التكييف والغليونات: تمديد ٢ إنش من المغاسل إلى الغليون'},
        {'id': 'sub_12_07', 'name': 'تصريف التكييف والغليونات: توصيل الصفايات الفرعية بالغليون'},
        {'id': 'sub_12_08', 'name': 'تصريف التكييف والغليونات: تثبيت الاتصالات في الغليون جيداً'},
        {'id': 'sub_12_09', 'name': 'أعمال الكهرباء: استلام نقاط الإنارة من فني الجبسوم'},
        {'id': 'sub_12_10', 'name': 'أعمال الكهرباء: توزيع الأسلاك فوق الجبس'},
      ]
    },
    {
      'id': 'phase_13',
      'name': 'التفنيش والتشغيل',
      'subPhases': [
        {'id': 'sub_13_01', 'name': 'أعمال الكهرباء: تنظيف العلب جيداً'},
        {'id': 'sub_13_02', 'name': 'أعمال الكهرباء: تركيب كونكترات للأسلاك'},
        {'id': 'sub_13_03', 'name': 'أعمال الكهرباء: توصيل التأريض لكل علبة'},
        {'id': 'sub_13_04', 'name': 'أعمال الكهرباء: ربط الأسلاك بإحكام'},
        {'id': 'sub_13_05', 'name': 'أعمال الكهرباء: تشغيل تجريبي بعد كل منطقة'},
        {'id': 'sub_13_06', 'name': 'أعمال الكهرباء: تأمين الإنارة الخارجية بالسيليكون'},
        {'id': 'sub_13_07', 'name': 'أعمال الكهرباء: عزل مواسير الحديقة جيداً'},
        {'id': 'sub_13_08', 'name': 'أعمال الكهرباء: تركيب محول ٢٤ فولت للحديقة'},
        {'id': 'sub_13_09', 'name': 'أعمال الكهرباء: التشغيل الفعلي للمبنى'},
        {'id': 'sub_13_10', 'name': 'أعمال الكهرباء: اختبار الأحمال وتوزيعها'},
        {'id': 'sub_13_11', 'name': 'أعمال الكهرباء: طباعة تعريف الخطوط بالطبلون'},
        {'id': 'sub_13_12', 'name': 'أعمال السباكة: تركيب الكراسي والمغاسل مع اختبار التثبيت'},
        {'id': 'sub_13_13', 'name': 'أعمال السباكة: استخدام السيليكون للعزل'},
        {'id': 'sub_13_14', 'name': 'أعمال السباكة: تركيب مضخة أو غطاس بالخزان الأرضي'},
        {'id': 'sub_13_15', 'name': 'أعمال السباكة: تركيب مضخة ضغط للخزان العلوي'},
        {'id': 'sub_13_16', 'name': 'أعمال السباكة: تركيب السخانات واختبار التشغيل'},
        {'id': 'sub_13_17', 'name': 'أعمال السباكة: تشغيل شبكة المياه وربط الخزانات'},
        {'id': 'sub_13_18', 'name': 'أعمال السباكة: تشغيل الشطافات والمغاسل مع الفحص'},
      ]
    },
  ];
  static const List<Map<String, dynamic>> finalCommissioningTests = [
    // ... (قائمة الاختبارات النهائية كما هي)
    {
      'section_id': 'tests_electricity',
      'section_name': 'أولاً: اختبارات الكهرباء (وفق كود IEC / NFPA / NEC)',
      'tests': [
        {'id': 'test_elec_01', 'name': 'اختبار مقاومة العزل: باستخدام جهاز الميجر بجهد 500/1000 فولت، والقيمة المقبولة ≥ 1 ميجا أوم.'},
        {'id': 'test_elec_02', 'name': 'اختبار الاستمرارية: فحص التوصيلات المغلقة والتأكد من سلامة الأسلاك.'},
        {'id': 'test_elec_03', 'name': 'اختبار مقاومة التأريض: باستخدام جهاز Earth Tester، والمقاومة المقبولة أقل من 5 أوم (يفضل < 1 أوم).'},
        {'id': 'test_elec_04', 'name': 'اختبار فرق الجهد: قياس الجهد بين المصدر والحمل والتأكد من ثباته.'},
        {'id': 'test_elec_05', 'name': 'اختبار قواطع الحماية (MCB/RCD): الضغط على زر الاختبار والتأكد من قطع التيار خلال المدة المسموحة.'},
        {'id': 'test_elec_06', 'name': 'اختبار تحميل الأحمال: تشغيل جميع الأحمال والتحقق من عدم وجود سخونة أو هبوط في الجهد.'},
        {'id': 'test_elec_07', 'name': 'اختبار الجهد والتيار: بقياس الفولت والأمبير عند نقاط متعددة.'},
        {'id': 'test_elec_08', 'name': 'اختبار أنظمة التيار الخفيف: فحص شبكات الإنترنت والتلفزيون والإنتركم.'},
        {'id': 'test_elec_09', 'name': 'فحص لوحات الكهرباء: التأكد من إحكام التوصيلات وتسميات الخطوط.'},
        {'id': 'test_elec_10', 'name': 'توثيق النتائج: تسجيل القراءات وتعريف الخطوط بلوحات الطبلون.'},
      ]
    },
    {
      'section_id': 'tests_water',
      'section_name': 'ثانياً: اختبارات تغذية المياه (وفق كود UPC / IPC)',
      'tests': [
        {'id': 'test_water_01', 'name': 'اختبار الضغط: باستخدام ساعة ضغط، ويُثبت الضغط لمدة 24 ساعة دون تسريب.'},
        {'id': 'test_water_02', 'name': 'اختبار التوصيلات: فحص التوصيلات النهائية للمغاسل والخلاطات والسخانات.'},
        {'id': 'test_water_03', 'name': 'اختبار عمل السخانات: التأكد من توفر ماء ساخن في جميع النقاط.'},
        {'id': 'test_water_04', 'name': 'اختبار تشغيل المضخة: للتحقق من توازن توزيع الماء.'},
        {'id': 'test_water_05', 'name': 'فحص سريان الماء: عند كافة المخارج النهائية (مغاسل، مطابخ، حمامات).'},
        {'id': 'test_water_06', 'name': 'اختبار الربط بين الخزانات: وتشغيل عوامة الخزان للتأكد من وظيفتها.'},
        {'id': 'test_water_07', 'name': 'توثيق النتائج: تسجيل بيانات الضغط والزمن لكل اختبار.'},
      ]
    },
  ];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInitialData();
  }

  String _getClientTypeDisplayValue(String? clientTypeKey) {
    final Map<String, String> clientTypeDisplayMap = {
      'individual': 'فردي',
      'company': 'شركة',
    };
    return clientTypeDisplayMap[clientTypeKey] ?? "غير محدد";
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isPageLoading = true;
      _clientTypeKeyFromFirestore = null;
      _clientTypeDisplayString = null;
    });
    await _fetchCurrentUserRole();
    await _loadAllAvailableEngineers();
    await _fetchProjectAndPhasesData(); // This will also fetch client type
    if (mounted) {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _currentUserRole = userDoc.data()?['role'] as String?;
        });
      }
    }
  }

  Future<void> _loadAllAvailableEngineers() async {
    try {
      final engSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'engineer')
          .orderBy('name')
          .get();
      if (mounted) {
        _allAvailableEngineers = engSnap.docs;
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل قائمة المهندسين: $e', isError: true);
      }
    }
  }

  Future<void> _fetchProjectAndPhasesData() async {
    if (mounted) {
      setState(() {
        _clientTypeDisplayString = null;
        _clientTypeKeyFromFirestore = null;
      });
    }
    try {
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      if (mounted && projectDoc.exists) {
        final projectData = projectDoc.data() as Map<String, dynamic>?;
        setState(() {
          _projectDataSnapshot = projectDoc;
        });

        final String? clientId = projectData?['clientId'] as String?;
        if (clientId != null && clientId.isNotEmpty) {
          try {
            final clientDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
            if (clientDoc.exists && mounted) {
              final clientDataMap = clientDoc.data() as Map<String, dynamic>?;
              final String? fetchedClientTypeKey = clientDataMap?['clientType'] as String?;
              setState(() {
                _clientTypeKeyFromFirestore = fetchedClientTypeKey;
                _clientTypeDisplayString = _getClientTypeDisplayValue(fetchedClientTypeKey);
              });
            } else {
              if (mounted) setState(() => _clientTypeDisplayString = "نوع العميل غير متوفر");
            }
          } catch (e) {
            if (mounted) setState(() => _clientTypeDisplayString = "خطأ في تحميل نوع العميل");
          }
        } else {
          if (mounted) setState(() => _clientTypeDisplayString = "لا يوجد عميل مرتبط");
        }
      } else if (mounted) {
        _showFeedbackSnackBar(context, 'المشروع غير موجود.', isError: true);
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحميل بيانات المشروع: $e', isError: true);
      }
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
  Future<void> _showEditAssignedEngineersDialog(Map<String, dynamic> projectDataMap) async {
    // ... (same as provided)
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      _showFeedbackSnackBar(context, "بيانات المشروع غير متوفرة حالياً.", isError: true);
      return;
    }
    if (_allAvailableEngineers.isEmpty && mounted) {
      _showFeedbackSnackBar(context, "جاري تحميل قائمة المهندسين، يرجى المحاولة مرة أخرى بعد قليل.", isError: false);
      await _loadAllAvailableEngineers();
      if (_allAvailableEngineers.isEmpty && mounted) {
        _showFeedbackSnackBar(context, "لا يوجد مهندسون متاحون في النظام.", isError: true);
        return;
      }
    }

    final currentEngRaw = projectDataMap['assignedEngineers'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> currentEngTyped = currentEngRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditAssignedEngineersPage(
          projectId: widget.projectId,
          projectName: projectDataMap['name'] ?? 'مشروع غير مسمى',
          currentlyAssignedEngineers: currentEngTyped,
          allAvailableEngineers: _allAvailableEngineers,
        ),
      ),
    );

    if (result == true && mounted) {
      _fetchProjectAndPhasesData(); // Re-fetch to update the UI
    }
  }

  Future<void> _sendNotificationToMultipleEngineers({
    required String projectId,
    required String projectName,
    required String title,
    required String body,
    required List<String> recipientUids,
    String phaseDocId = '',
    required String notificationType,
  }) async {
    // ... (same as provided)
    final notificationCollection = FirebaseFirestore.instance.collection('notifications');
    final currentUser = FirebaseAuth.instance.currentUser;
    String senderName = "النظام"; // Default sender name

    // Try to get the sender's name from Firestore
    if (currentUser != null) {
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      senderName = senderDoc.data()?['name'] ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مهندس');
    }


    for (String userId in recipientUids) {
      try {
        await notificationCollection.add({
          'userId': userId, // The UID of the recipient
          'projectId': projectId,
          'phaseDocId': phaseDocId, // Optional: specific phase/subphase doc ID
          'title': title,
          'body': body,
          'type': notificationType, // e.g., 'phase_completed', 'new_assignment'
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'senderName': senderName, // Who triggered the notification (e.g., "المسؤول" or engineer's name)
        });
        print('Notification sent to $userId for project $projectName');
      } catch(e) {
        print('Failed to send notification to $userId: $e');
        if (mounted) _showFeedbackSnackBar(context, 'فشل إرسال إشعار للمهندس $userId: $e', isError: true);
      }
    }
  }


  PreferredSizeWidget _buildAppBar() {
    // ... (same as provided)
    return AppBar(
      title: const Text('تفاصيل المشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22)),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      elevation: 4,
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'مراحل المشروع', icon: Icon(Icons.list_alt_rounded)),
          Tab(text: 'اختبارات التشغيل', icon: Icon(Icons.checklist_rtl_rounded)),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard(Map<String, dynamic> projectDataMap) {
    // ... (same as provided, but ensure _clientTypeDisplayString is used correctly)
    final projectName = projectDataMap['name'] ?? 'مشروع غير مسمى';
    final clientName = projectDataMap['clientName'] ?? 'غير محدد';
    final projectStatus = projectDataMap['status'] ?? 'غير محدد';
    final List<dynamic> assignedEngineersRaw = projectDataMap['assignedEngineers'] as List<dynamic>? ?? [];
    String engineersDisplay = "لم يتم تعيين مهندسين";
    if (assignedEngineersRaw.isNotEmpty) {
      engineersDisplay = assignedEngineersRaw.map((eng) => eng['name'] ?? 'غير معروف').join('، ');
      if (engineersDisplay.length > 70) { // Adjusted length for better display
        engineersDisplay = '${engineersDisplay.substring(0, 70)}...';
      }
    }

    IconData statusIcon;
    Color statusColor;
    switch (projectStatus) {
      case 'نشط': statusIcon = Icons.construction_rounded; statusColor = AppConstants.infoColor; break;
      case 'مكتمل': statusIcon = Icons.check_circle_outline_rounded; statusColor = AppConstants.successColor; break;
      case 'معلق': statusIcon = Icons.pause_circle_outline_rounded; statusColor = AppConstants.warningColor; break;
      default: statusIcon = Icons.help_outline_rounded; statusColor = AppConstants.textSecondary;
    }

    IconData clientTypeIcon = Icons.person_pin_rounded; // Default icon
    if (_clientTypeKeyFromFirestore == 'company') {
      clientTypeIcon = Icons.business_center_rounded;
    }
    // If _clientTypeDisplayString is still loading or failed, it might be null or an error message.
    // We handle this by conditionally showing the row.

    return Card(
      elevation: AppConstants.cardShadow[0].blurRadius,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingLarge, left: AppConstants.paddingSmall, right: AppConstants.paddingSmall, top: AppConstants.paddingSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(projectName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
            const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
            _buildDetailRow(Icons.engineering_rounded, 'المهندسون:', engineersDisplay),
            _buildDetailRow(Icons.person_rounded, 'العميل:', clientName),
            // Conditionally display client type
            if (_clientTypeDisplayString != null &&
                _clientTypeDisplayString != "لا يوجد عميل مرتبط" &&
                _clientTypeDisplayString != "خطأ في تحميل نوع العميل" &&
                _clientTypeDisplayString != "نوع العميل غير متوفر" && // Check against the "not available" message
                _clientTypeDisplayString != "غير محدد" // Check against default from _getClientTypeDisplayValue
            )
              _buildDetailRow(
                  clientTypeIcon,
                  'نوع العميل:',
                  _clientTypeDisplayString!
              ),
            _buildDetailRow(statusIcon, 'حالة المشروع:', projectStatus, valueColor: statusColor),
            const SizedBox(height: AppConstants.itemSpacing),
            if (_currentUserRole == 'admin')
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.group_add_rounded, color: Colors.white, size: 18),
                  label: const Text('تعديل المهندسين', style: TextStyle(color: Colors.white)),
                  onPressed: () => _showEditAssignedEngineersDialog(projectDataMap),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: AppConstants.paddingSmall),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    // ... (same as provided)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Text('$label ', style: const TextStyle(fontSize: 15, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesTab() {
    // ... (remains structurally similar, calls the updated _buildEntriesList) ...
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للمراحل."));
    }
    return ListView.builder(
      key: const PageStorageKey<String>('adminProjectDetails_phasesTabListView'), // For scroll position restoration
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: predefinedPhasesStructure.length,
      itemBuilder: (context, index) {
        final phaseStructure = predefinedPhasesStructure[index];
        final phaseId = phaseStructure['id'] as String;
        final phaseName = phaseStructure['name'] as String;
        final subPhasesStructure = phaseStructure['subPhases'] as List<Map<String, dynamic>>;

        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('phases_status')
                .doc(phaseId)
                .snapshots(),
            builder: (context, phaseStatusSnapshot) {
              bool isCompleted = false;
              String phaseActualName = phaseName; // Default to predefined name

              if (phaseStatusSnapshot.hasData && phaseStatusSnapshot.data!.exists) {
                final statusData = phaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                isCompleted = statusData['completed'] ?? false;
                phaseActualName = statusData['name'] ?? phaseName; // Use stored name if available
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                child: ExpansionTile(
                  key: PageStorageKey<String>(phaseId), // For scroll position restoration of individual tiles
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? AppConstants.successColor : AppConstants.primaryColor,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phaseActualName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Text(isCompleted ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: isCompleted ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
                  trailing: Row( // Combine icons in a Row
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Admin can always add notes/images, Engineers only if not completed
                      if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isCompleted))
                        IconButton(
                          icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                          tooltip: 'إضافة ملاحظة/صورة للمرحلة الرئيسية',
                          onPressed: () => _showAddNoteOrImageDialog(phaseId, phaseActualName),
                        ),
                      // Admin can always toggle, Engineers only if not completed
                      if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isCompleted))
                        Checkbox(
                          value: isCompleted,
                          activeColor: AppConstants.successColor,
                          onChanged: (value) {
                            _updatePhaseCompletionStatus(phaseId, phaseActualName, value ?? false);
                          },
                        ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingSmall).copyWith(right: AppConstants.paddingMedium + 8, left: AppConstants.paddingSmall),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("إدخالات المرحلة الرئيسية:", style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.textPrimary, fontSize: 14)),
                          _buildEntriesList(phaseId, isCompleted, phaseActualName), // This will show entries
                          const SizedBox(height: AppConstants.paddingSmall),
                        ],
                      ),
                    ),
                    if (subPhasesStructure.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppConstants.paddingSmall,
                            right: AppConstants.paddingMedium,
                            left: AppConstants.paddingSmall,
                            bottom: AppConstants.paddingSmall
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppConstants.paddingSmall / 2, right: 8.0),
                              child: Text("المراحل الفرعية:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                            ),
                            ...subPhasesStructure.map((subPhaseMap) {
                              final subPhaseId = subPhaseMap['id'] as String;
                              final subPhaseName = subPhaseMap['name'] as String;
                              return StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('projects')
                                      .doc(widget.projectId)
                                      .collection('subphases_status')
                                      .doc(subPhaseId)
                                      .snapshots(),
                                  builder: (context, subPhaseStatusSnapshot) {
                                    bool isSubCompleted = false;
                                    String subPhaseActualName = subPhaseName;

                                    if (subPhaseStatusSnapshot.hasData && subPhaseStatusSnapshot.data!.exists) {
                                      final subStatusData = subPhaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                                      isSubCompleted = subStatusData['completed'] ?? false;
                                      subPhaseActualName = subStatusData['name'] ?? subPhaseName;
                                    }
                                    return Card(
                                      elevation: 0.5,
                                      color: AppConstants.backgroundColor, // Slightly different background for sub-phase cards
                                      margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2, horizontal: AppConstants.paddingSmall /2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                                      child: ExpansionTile( // Sub-phases are also ExpansionTiles
                                        key: PageStorageKey<String>('sub_$subPhaseId'), // Key for sub-phase tile
                                        leading: Icon(
                                          isSubCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                          color: isSubCompleted ? AppConstants.successColor : AppConstants.textSecondary, size: 20,
                                        ),
                                        title: Text(subPhaseActualName, style: TextStyle(fontSize: 13.5, color: AppConstants.textSecondary, decoration: isSubCompleted ? TextDecoration.lineThrough : null)),
                                        trailing: (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isSubCompleted))
                                            ? Checkbox( // Admin or Engineer (if not completed) can mark sub-phase
                                          value: isSubCompleted,
                                          activeColor: AppConstants.successColor,
                                          visualDensity: VisualDensity.compact,
                                          onChanged: (value) {
                                            _updateSubPhaseCompletionStatus(phaseId, subPhaseId, subPhaseActualName, value ?? false);
                                          },
                                        )
                                            : null, // No action if completed by someone else and current user is engineer
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(left: AppConstants.paddingSmall, right: AppConstants.paddingMedium + 8, bottom: AppConstants.paddingSmall, top: 0),
                                            child: _buildEntriesList(phaseId, isSubCompleted, subPhaseActualName, subPhaseId: subPhaseId, isSubEntry: true), // Show entries for sub-phase
                                          )
                                        ],
                                      ),
                                    );
                                  });
                            }).toList(),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            });
      },
    );
  }

  Widget _buildTestsTab() {
    // ... (remains structurally similar, calls the updated _buildEntriesList if tests were to have multi-image entries)
    // For now, tests in the provided code seem to have a single imageUrl. If that changes, this needs review.
    // The current request is focused on phases/sub-phases entries.
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للاختبارات."));
    }
    return ListView.builder(
      key: const PageStorageKey<String>('adminProjectDetails_testsTabListView'), // For scroll position restoration
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: finalCommissioningTests.length,
      itemBuilder: (context, sectionIndex) {
        final section = finalCommissioningTests[sectionIndex];
        final sectionId = section['section_id'] as String;
        final sectionName = section['section_name'] as String;
        final tests = section['tests'] as List<Map<String, dynamic>>;

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          child: ExpansionTile(
            key: PageStorageKey<String>(sectionId), // For scroll position restoration
            title: Text(sectionName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
            childrenPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: AppConstants.paddingSmall / 2),
            children: tests.map((test) {
              final testId = test['id'] as String;
              final testName = test['name'] as String;
              return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.projectId)
                      .collection('tests_status')
                      .doc(testId)
                      .snapshots(),
                  builder: (context, testStatusSnapshot) {
                    bool isTestCompleted = false;
                    String testNote = "";
                    String? testImageUrl; // Tests currently use single imageUrl
                    String? engineerName;

                    if (testStatusSnapshot.hasData && testStatusSnapshot.data!.exists) {
                      final statusData = testStatusSnapshot.data!.data() as Map<String, dynamic>;
                      isTestCompleted = statusData['completed'] ?? false;
                      testNote = statusData['note'] ?? '';
                      testImageUrl = statusData['imageUrl'] as String?; // Assuming tests still use single imageUrl
                      engineerName = statusData['engineerName'] as String?;
                    }

                    return ListTile(
                      title: Text(testName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isTestCompleted ? TextDecoration.lineThrough : null)),
                      leading: Icon(
                        isTestCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isTestCompleted ? AppConstants.successColor : AppConstants.textSecondary,
                        size: 20,
                      ),
                      trailing: (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isTestCompleted))
                          ? Checkbox(
                        value: isTestCompleted,
                        activeColor: AppConstants.successColor,
                        onChanged: (value) {
                          _updateTestStatus(testId, testName, value ?? false, currentNote: testNote, currentImageUrl: testImageUrl);
                        },
                      )
                          : null,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (engineerName != null && engineerName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("بواسطة: $engineerName", style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic)),
                            ),
                          if (testNote.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("ملاحظة: $testNote", style: const TextStyle(fontSize: 12, color: AppConstants.infoColor)),
                            ),
                          if (testImageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: InkWell(
                                onTap: () => _viewImageDialog(testImageUrl!), // viewImageDialog can handle single URL
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image_outlined, size: 16, color: AppConstants.primaryLight),
                                    SizedBox(width: 4),
                                    Text("عرض الصورة", style: TextStyle(fontSize: 12, color: AppConstants.primaryLight, decoration: TextDecoration.underline)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        // Allow admin to edit, or engineer if not completed
                        if (_currentUserRole == 'admin' || (_currentUserRole == 'engineer' && !isTestCompleted)) {
                          _updateTestStatus(testId, testName, !isTestCompleted, currentNote: testNote, currentImageUrl: testImageUrl);
                        }
                      },
                    );
                  });
            }).toList(),
          ),
        );
      },
    );
  }

  // --- MODIFIED _buildEntriesList ---
  Widget _buildEntriesList(String phaseOrMainPhaseId, bool parentCompleted, String parentName, {String? subPhaseId, bool isSubEntry = false}) {
    String entriesCollectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseOrMainPhaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

    final String listKeySuffix = subPhaseId ?? phaseOrMainPhaseId;
    final PageStorageKey entriesListKey = PageStorageKey<String>('entriesList_$listKeySuffix');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection(entriesCollectionPath).orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(isSubEntry ? 'لا توجد إدخالات لهذه المرحلة الفرعية بعد.' : 'لا توجد إدخالات لهذه المرحلة بعد.', style: const TextStyle(color: AppConstants.textSecondary, fontStyle: FontStyle.italic, fontSize: 13)),
              );
            }
            final entries = snapshot.data!.docs;
            return ListView.builder(
              key: entriesListKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entryData = entries[index].data() as Map<String, dynamic>;
                final String note = entryData['note'] ?? '';
                final String engineerName = entryData['engineerName'] ?? 'غير معروف';
                final Timestamp? timestamp = entryData['timestamp'] as Timestamp?;

                // --- Logic to handle both imageUrl (single) and imageUrls (list) ---
                final List<String> imageUrlsToDisplay = [];
                final dynamic imagesField = entryData['imageUrls']; // Prefer new field 'imageUrls' (list)
                final dynamic singleImageField = entryData['imageUrl']; // Fallback to old field 'imageUrl' (string)

                if (imagesField is List) {
                  imageUrlsToDisplay.addAll(imagesField.map((e) => e.toString()).toList());
                } else if (singleImageField is String && singleImageField.isNotEmpty) {
                  imageUrlsToDisplay.add(singleImageField);
                }
                // --- End of image handling logic ---

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrlsToDisplay.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: note.isNotEmpty ? AppConstants.paddingSmall : 0),
                            child: Wrap(
                              spacing: AppConstants.paddingSmall / 1.5,
                              runSpacing: AppConstants.paddingSmall / 1.5,
                              children: imageUrlsToDisplay.map((url) {
                                return InkWell(
                                  onTap: () => _viewImageDialog(url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2.5),
                                    child: Image.network(
                                      url,
                                      height: 100, // Consistent small preview size
                                      width: 100,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (ctx, child, progress) =>
                                      progress == null ? child : Container(height:100, width: 100, alignment: Alignment.center, child: const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryLight))),
                                      errorBuilder: (c, e, s) => Container(height: 100, width: 100, color: AppConstants.backgroundColor.withOpacity(0.5), child: Center(child: Icon(Icons.broken_image_outlined, color: AppConstants.textSecondary.withOpacity(0.7), size: 30))),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: imageUrlsToDisplay.isNotEmpty ? AppConstants.paddingSmall : 0),
                            child: ExpandableText(note, valueColor: AppConstants.textPrimary),
                          ),
                        const SizedBox(height: AppConstants.paddingSmall / 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'بواسطة: $engineerName - ${timestamp != null ? DateFormat('dd/MM/yy hh:mm a', 'ar').format(timestamp.toDate()) : 'غير معروف'}',
                              style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        // The "Add Entry" button for admin is part of the ExpansionTile's trailing in _buildPhasesTab
        // So no separate button needed here in _buildEntriesList for admin viewing.
      ],
    );
  }
  // --- END OF MODIFIED _buildEntriesList ---


  Future<void> _viewImageDialog(String imageUrl) async {
    // ... (same as provided)
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.transparent, // Make background transparent
        contentPadding: EdgeInsets.zero, // Remove default padding
        insetPadding: const EdgeInsets.all(10), // Padding around the dialog
        content: InteractiveViewer(
          panEnabled: true, // Enable panning
          boundaryMargin: const EdgeInsets.all(20), // Margin around the content
          minScale: 0.5, // Minimum scale factor
          maxScale: 4,   // Maximum scale factor
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain, // Ensure the whole image is visible
            loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => const Center(child: Icon(Icons.error_outline, color: AppConstants.errorColor, size: 50)),
          ),
        ),
        actions: [ // Add a clear close button
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.5)),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("إغلاق", style: TextStyle(color: Colors.white)),
          )
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  Future<void> _showAddNoteOrImageDialog(String phaseId, String phaseOrSubPhaseName, {String? subPhaseId}) async {
    // ... (This dialog in admin page currently uses Firebase Storage and single image)
    // ... (It should ideally be updated to match engineer's multi-image PHP upload for consistency)
    // ... (For now, it remains as is, but _buildEntriesList will handle viewing its output)
    if (!mounted) return;

    final noteController = TextEditingController();
    File? pickedImageFile; // Admin's dialog still uses single File
    bool isUploadingDialog = false;
    final formKeyDialog = GlobalKey<FormState>();

    String dialogTitle = subPhaseId == null
        ? 'إضافة إدخال للمرحلة: $phaseOrSubPhaseName'
        : 'إضافة إدخال للمرحلة الفرعية: $phaseOrSubPhaseName';

    // Path for entries collection
    String collectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

    await showDialog(
      context: context,
      barrierDismissible: !isUploadingDialog, // Prevent dismissal during upload
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: Text(dialogTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKeyDialog,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(
                            labelText: 'الملاحظة',
                            hintText: 'أدخل ملاحظتك هنا (اختياري إذا أضفت صورة)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes_rounded)
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if ((value == null || value.isEmpty) && pickedImageFile == null) {
                            return 'الرجاء إدخال ملاحظة أو إضافة صورة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (pickedImageFile != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Image.file(pickedImageFile!, height: 120, fit: BoxFit.contain),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, color: AppConstants.primaryColor),
                        label: Text(pickedImageFile == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة', style: const TextStyle(color: AppConstants.primaryColor)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70); // Can be gallery too
                          if (picked != null) {
                            setDialogState(() { // Use the dialog's state setter
                              pickedImageFile = File(picked.path);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isUploadingDialog ? null : () async {
                    if (!formKeyDialog.currentState!.validate()) return;

                    setDialogState(() => isUploadingDialog = true);
                    String? imageUrl; // For single image from admin
                    final currentUser = FirebaseAuth.instance.currentUser;
                    String actorName = "غير معروف"; // Default

                    if (currentUser != null) {
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                      if (userDoc.exists) {
                        actorName = userDoc.data()?['name'] ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مهندس');
                      } else {
                        // Fallback if user doc not found but role is known
                        actorName = _currentUserRole == 'admin' ? 'المسؤول' : 'مهندس';
                      }
                    }

                    if (pickedImageFile != null) {
                      try {
                        // Admin uploads to Firebase Storage (current logic)
                        final timestampForPath = DateTime.now().millisecondsSinceEpoch;
                        final imageName = '${currentUser?.uid ?? 'unknown_user'}_${timestampForPath}.jpg';
                        final refPath = subPhaseId == null
                            ? 'project_entries/${widget.projectId}/$phaseId/$imageName' // Path for main phase entry image
                            : 'project_entries/${widget.projectId}/$subPhaseId/$imageName'; // Path for sub-phase entry image

                        final ref = FirebaseStorage.instance.ref().child(refPath);
                        await ref.putFile(pickedImageFile!);
                        imageUrl = await ref.getDownloadURL();
                      } catch (e) {
                        if (mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع الصورة: $e', isError: true,);
                        setDialogState(() => isUploadingDialog = false);
                        return;
                      }
                    }

                    try {
                      await FirebaseFirestore.instance.collection(collectionPath).add({
                        // Admin adds 'imageUrl', engineers add 'imageUrls'
                        'type': imageUrl != null ? (noteController.text.trim().isEmpty ? 'image_only' : 'image_with_note') : 'note_only',
                        'note': noteController.text.trim(),
                        'imageUrl': imageUrl, // Admin saves single imageUrl
                        // 'imageUrls': null, // Explicitly null for admin entries if using this dialog
                        'engineerUid': currentUser?.uid, // Could be admin's UID
                        'engineerName': actorName, // Could be "المسؤول"
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تمت إضافة الإدخال بنجاح.', isError: false);
                    } catch (e) {
                      if (mounted) _showFeedbackSnackBar(stfContext, 'فشل إضافة الإدخال: $e', isError: true,);
                    } finally {
                      if(mounted) setDialogState(() => isUploadingDialog = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                  child: isUploadingDialog ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),)) : const Text('حفظ الإدخال'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _updatePhaseCompletionStatus(String phaseId, String phaseName, bool newStatus) async {
    // ... (same as provided)
    if (!mounted) return;
    try {
      final phaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases_status')
          .doc(phaseId);

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = "غير معروف";
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          actorName = userDoc.data()?['name'] ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مهندس');
        } else {
          actorName = _currentUserRole == 'admin' ? 'المسؤول' : 'مهندس';
        }
      }

      await phaseDocRef.set({
        'completed': newStatus,
        'name': phaseName, // Ensure the name is also set/updated
        'lastUpdatedByUid': currentUser?.uid,
        'lastUpdatedByName': actorName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Use merge to avoid overwriting other fields if any

      // --- Notification Logic ---
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final projectData = projectDoc.data();
      final projectNameVal = projectData?['name'] ?? 'المشروع';
      final clientUid = projectData?['clientId'] as String?;
      final List<dynamic> assignedEngineersRaw = projectData?['assignedEngineers'] as List<dynamic>? ?? [];
      final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => e['uid'].toString()).toList();

      if (newStatus) { // Send notifications only on completion
        // Notify Client
        if (clientUid != null) {
          _sendNotificationToMultipleEngineers(
              projectId: widget.projectId,
              projectName: projectNameVal,
              title: 'تحديث مشروع: مرحلة مكتملة',
              body: 'المرحلة "$phaseName" في مشروع "$projectNameVal" أصبحت مكتملة. يمكنك الآن مراجعتها.',
              recipientUids: [clientUid],
              notificationType: 'phase_completed_client',
              phaseDocId: phaseId
          );
        }
        // Notify other engineers if an engineer completed it, or all engineers if admin completed it
        if (_currentUserRole == 'engineer') {
          final otherEngineers = assignedEngineerUids.where((uid) => uid != currentUser?.uid).toList();
          if (otherEngineers.isNotEmpty) {
            _sendNotificationToMultipleEngineers(
                projectId: widget.projectId,
                projectName: projectNameVal,
                title: 'تحديث مشروع: مرحلة مكتملة',
                body: 'المرحلة "$phaseName" في مشروع "$projectNameVal" أصبحت مكتملة بواسطة المهندس $actorName.',
                recipientUids: otherEngineers,
                notificationType: 'phase_completed_other_engineers',
                phaseDocId: phaseId
            );
          }
        } else if (_currentUserRole == 'admin' && assignedEngineerUids.isNotEmpty) {
          _sendNotificationToMultipleEngineers(
              projectId: widget.projectId,
              projectName: projectNameVal,
              title: 'تحديث مشروع: مرحلة مكتملة',
              body: 'المرحلة "$phaseName" في مشروع "$projectNameVal" أصبحت مكتملة بواسطة المسؤول.',
              recipientUids: assignedEngineerUids, // Notify all assigned engineers
              notificationType: 'phase_completed_admin_to_engineers',
              phaseDocId: phaseId
          );
        }
      }
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة "$phaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة: $e', isError: true);
    }
  }

  Future<void> _updateSubPhaseCompletionStatus(String mainPhaseId, String subPhaseId, String subPhaseName, bool newStatus) async {
    // ... (same as provided)
    if (!mounted) return;
    try {
      final subPhaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('subphases_status')
          .doc(subPhaseId);

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = "غير معروف";
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          actorName = userDoc.data()?['name'] ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مهندس');
        } else {
          actorName = _currentUserRole == 'admin' ? 'المسؤول' : 'مهندس';
        }
      }

      await subPhaseDocRef.set({
        'completed': newStatus,
        'mainPhaseId': mainPhaseId, // Good to keep track of parent
        'name': subPhaseName, // Ensure the name is also set/updated
        'lastUpdatedByUid': currentUser?.uid,
        'lastUpdatedByName': actorName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // --- Notification Logic for Sub-Phases ---
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final projectData = projectDoc.data();
      final projectNameVal = projectData?['name'] ?? 'المشروع';
      final clientUid = projectData?['clientId'] as String?;
      final List<dynamic> assignedEngineersRaw = projectData?['assignedEngineers'] as List<dynamic>? ?? [];
      final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => e['uid'].toString()).toList();

      if (newStatus) { // Send notifications only on completion
        if (clientUid != null) {
          _sendNotificationToMultipleEngineers(
              projectId: widget.projectId,
              projectName: projectNameVal,
              title: 'تحديث مشروع: مرحلة فرعية مكتملة',
              body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectNameVal" أصبحت مكتملة.',
              recipientUids: [clientUid],
              notificationType: 'subphase_completed_client',
              phaseDocId: mainPhaseId // Can refer to the main phase
          );
        }
        if (_currentUserRole == 'engineer') {
          final otherEngineers = assignedEngineerUids.where((uid) => uid != currentUser?.uid).toList();
          if (otherEngineers.isNotEmpty) {
            _sendNotificationToMultipleEngineers(
                projectId: widget.projectId,
                projectName: projectNameVal,
                title: 'تحديث مشروع: مرحلة فرعية مكتملة',
                body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectNameVal" أصبحت مكتملة بواسطة المهندس $actorName.',
                recipientUids: otherEngineers,
                notificationType: 'subphase_completed_other_engineers',
                phaseDocId: mainPhaseId
            );
          }
        } else if (_currentUserRole == 'admin' && assignedEngineerUids.isNotEmpty) {
          _sendNotificationToMultipleEngineers(
              projectId: widget.projectId,
              projectName: projectNameVal,
              title: 'تحديث مشروع: مرحلة فرعية مكتملة',
              body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectNameVal" أصبحت مكتملة بواسطة المسؤول.',
              recipientUids: assignedEngineerUids,
              notificationType: 'subphase_completed_admin_to_engineers',
              phaseDocId: mainPhaseId
          );
        }
      }
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة الفرعية "$subPhaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة الفرعية: $e', isError: true);
    }
  }

  Future<void> _updateTestStatus(String testId, String testName, bool newStatus, {String? currentNote, String? currentImageUrl}) async {
    // ... (same as provided - this dialog uses single image and Firebase Storage)
    if (!mounted) return;

    final noteController = TextEditingController(text: currentNote ?? "");
    String? tempImageUrl = currentImageUrl;
    File? pickedImageFile; // For single image in test status
    bool isUploadingDialog = false;

    final currentUser = FirebaseAuth.instance.currentUser;
    String actorName = "غير معروف";
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        actorName = userDoc.data()?['name'] ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مهندس');
      } else {
        actorName = _currentUserRole == 'admin' ? 'المسؤول' : 'مهندس';
      }
    }

    // Show confirmation dialog with editing options
    bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: !isUploadingDialog,
        builder: (dialogContext) {
          // Use a local state for newStatus inside the dialog to allow changes before saving
          bool dialogNewStatus = newStatus;
          return StatefulBuilder(builder: (stfContext, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: Text('تحديث حالة الاختبار: $testName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        title: const Text('الاختبار مكتمل وناجح'),
                        value: dialogNewStatus, // Use local dialog state
                        onChanged: (val) => setDialogState(() => dialogNewStatus = val ?? false),
                        activeColor: AppConstants.successColor,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      // Image handling logic (single image for tests)
                      if (tempImageUrl != null && pickedImageFile == null)
                        Column(
                          children: [
                            const Text("الصورة الحالية:", style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                            Image.network(tempImageUrl!, height: 80, fit: BoxFit.cover),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor, size: 18),
                              label: const Text("إزالة الصورة الحالية", style: TextStyle(color: AppConstants.errorColor, fontSize: 12)),
                              onPressed: () => setDialogState(() => tempImageUrl = null),
                            )
                          ],
                        ),
                      if (pickedImageFile != null)
                        Image.file(pickedImageFile!, height: 80, fit: BoxFit.cover),
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, color: AppConstants.primaryColor),
                        label: Text(pickedImageFile == null && tempImageUrl == null ? 'إضافة صورة (اختياري)' : (pickedImageFile == null ? 'تغيير الصورة الحالية' : 'تغيير الصورة المختارة'), style: const TextStyle(color: AppConstants.primaryColor)),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
                          if (picked != null) {
                            setDialogState(() {
                              pickedImageFile = File(picked.path);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                  ElevatedButton(
                    onPressed: isUploadingDialog ? null : () async {
                      setDialogState(() => isUploadingDialog = true);
                      String? finalImageUrl = tempImageUrl;
                      if (pickedImageFile != null) {
                        try {
                          // Tests use Firebase Storage (as per existing admin code)
                          final refPath = 'project_tests/${widget.projectId}/$testId/${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final ref = FirebaseStorage.instance.ref().child(refPath);
                          await ref.putFile(pickedImageFile!);
                          finalImageUrl = await ref.getDownloadURL();
                        } catch (e) {
                          if(mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع صورة الاختبار: $e', isError: true);
                          setDialogState(() => isUploadingDialog = false);
                          return; // Stop if image upload fails
                        }
                      }
                      // Update Firestore
                      try {
                        final testDocRef = FirebaseFirestore.instance
                            .collection('projects')
                            .doc(widget.projectId)
                            .collection('tests_status')
                            .doc(testId);

                        await testDocRef.set({
                          'completed': dialogNewStatus, // Use status from dialog
                          'name': testName,
                          'note': noteController.text.trim(),
                          'imageUrl': finalImageUrl, // Single image URL for tests
                          'lastUpdatedByUid': currentUser?.uid,
                          'lastUpdatedByName': actorName,
                          'lastUpdatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        if(mounted) Navigator.pop(dialogContext, true); // Close dialog and indicate success
                        if(mounted) _showFeedbackSnackBar(context, 'تم تحديث حالة الاختبار "$testName".', isError: false);

                      } catch (e) {
                        if(mounted) _showFeedbackSnackBar(stfContext, 'فشل تحديث حالة الاختبار: $e', isError: true);
                      } finally {
                        if(mounted) setDialogState(() => isUploadingDialog = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                    child: isUploadingDialog ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),)) : const Text('حفظ الحالة'),
                  ),
                ],
              ),
            );
          });
        }
    );
    // 'confirmed' will be true if saved, false if cancelled. Can be used if needed.
  }


  @override
  Widget build(BuildContext context) {
    if (_isPageLoading || _currentUserRole == null || _projectDataSnapshot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المشروع', style: TextStyle(color: Colors.white)), backgroundColor: AppConstants.primaryColor),
        body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }

    final projectDataMap = _projectDataSnapshot!.data() as Map<String, dynamic>;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        key: _projectFutureBuilderKey, // Use the key here
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildProjectSummaryCard(projectDataMap),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPhasesTab(),
                  _buildTestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ... (ExpandableText Widget remains the same) ...
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
        // Text object defining text
        final text = TextSpan(
            text: widget.text,
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5)
        );
        // Create a TextPainter to measure the text
        TextPainter textPainter = TextPainter(
          text: link,
          textAlign: TextAlign.start, // Useful for LTR or RTL
          textDirection: ui.TextDirection.rtl, // Set text direction
          maxLines: widget.trimLines,
          ellipsis: '...',
        );
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final linkSize = textPainter.size;
        // Layout and measure link
        textPainter.text = text;
        textPainter.layout(minWidth: constraints.minWidth, maxWidth: maxWidth);
        final textSize = textPainter.size;
        // Get the endIndex of data
        int endIndex;

        // Check if text has overflown
        if (!textPainter.didExceedMaxLines) {
          return RichText(
              softWrap: true,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.start, // Useful for LTR or RTL
              textDirection: ui.TextDirection.rtl, // Set text direction
              text: text);
        }
        // چلے
        var pos = textPainter.getPositionForOffset(Offset(
          textSize.width - linkSize.width,
          textSize.height,
        ));
        endIndex = textPainter.getOffsetBefore(pos.offset) ?? 0;

        var textSpan;
        if (_readMore) {
          textSpan = TextSpan(
            text: widget.text.substring(0, endIndex),
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5),
            children: <TextSpan>[const TextSpan(text: "... "),link],
          );
        } else {
          textSpan = TextSpan(
            text: widget.text,
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5),
            children: <TextSpan>[const TextSpan(text: " "), link],
          );
        }
        return RichText(
          softWrap: true,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.start, // Useful for LTR or RTL
          textDirection: ui.TextDirection.rtl, // Set text direction
          text: textSpan,
        );
      },
    );
    return result;
  }
}