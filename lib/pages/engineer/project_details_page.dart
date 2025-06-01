// lib/pages/engineer/project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
// import 'package:url_launcher/url_launcher.dart'; // Not used directly for notifications
// import 'package:share_plus/share_plus.dart'; // Not used directly for notifications
import 'dart:ui' as ui; // For TextDirection
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

// --- MODIFICATION START: Import notification helper functions ---
// Make sure the path to your main.dart (or a dedicated notification service file) is correct.
import '../../main.dart'; // Assuming helper functions are in main.dart
// --- MODIFICATION END ---


// ... (AppConstants remains the same, ensure UPLOAD_URL is correct) ...
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
  // تأكد أن هذا الرابط صحيح
  static const String UPLOAD_URL = 'https://creditphoneqatar.com/eng-app/upload_image.php'; //
}

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> with TickerProviderStateMixin {
  String? _currentEngineerUid;
  String? _currentEngineerName;
  bool _isPageLoading = true;
  DocumentSnapshot? _projectDataSnapshot;

  late TabController _tabController;

  // --- قوائم المراحل والاختبارات (تبقى كما هي) ---
  static const List<Map<String, dynamic>> predefinedPhasesStructure = [ //
    // ... (قائمة المراحل كما هي في الكود الأصلي) ...
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
  static const List<Map<String, dynamic>> finalCommissioningTests = [ //
    // ... (قائمة الاختبارات كما هي في الكود الأصلي) ...
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
    _currentEngineerUid = FirebaseAuth.instance.currentUser?.uid;
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isPageLoading = true);
    await _fetchCurrentEngineerData();
    await _fetchProjectData();
    if (mounted) {
      setState(() => _isPageLoading = false);
    }
  }

  Future<void> _fetchCurrentEngineerData() async {
    if (_currentEngineerUid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentEngineerUid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _currentEngineerName = userDoc.data()?['name'] as String?;
        });
      }
    }
  }

  Future<void> _fetchProjectData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      if (mounted && doc.exists) {
        setState(() {
          _projectDataSnapshot = doc;
        });
      } else if (mounted) {
        _showFeedbackSnackBar(context, 'المشروع غير موجود.', isError: true);
        Navigator.pop(context);
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

  PreferredSizeWidget _buildAppBar() {
    String projectName = _projectDataSnapshot != null && _projectDataSnapshot!.exists
        ? (_projectDataSnapshot!.data() as Map<String, dynamic>)['name'] ?? 'تفاصيل المشروع'
        : 'تفاصيل المشروع';
    return AppBar(
      title: Text(projectName, style: const TextStyle(color: Colors.white, fontSize: 20)),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
      elevation: 3,
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
    final clientName = projectDataMap['clientName'] ?? 'غير محدد';
    final projectStatus = projectDataMap['status'] ?? 'غير محدد';
    final List<dynamic> assignedEngineersRaw = projectDataMap['assignedEngineers'] as List<dynamic>? ?? [];
    String engineersDisplay = "لم يتم تعيين مهندسين";
    if (assignedEngineersRaw.isNotEmpty) {
      engineersDisplay = assignedEngineersRaw.map((eng) => eng['name'] ?? 'م.غير معروف').join('، ');
      if (engineersDisplay.length > 60) engineersDisplay = '${engineersDisplay.substring(0,60)}...';
    }

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
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium, left:AppConstants.paddingSmall, right: AppConstants.paddingSmall, top:AppConstants.paddingSmall ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.engineering_rounded, 'المهندسون:', engineersDisplay),
            _buildDetailRow(Icons.person_rounded, 'العميل:', clientName),
            _buildDetailRow(statusIcon, 'حالة المشروع:', projectStatus, valueColor: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Text('$label ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesTab() {
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للمراحل."));
    }
    return ListView.builder(
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
              bool isMainPhaseCompletedByAnyEngineer = false;
              String? mainPhaseCompletedByUid;

              if (phaseStatusSnapshot.hasData && phaseStatusSnapshot.data!.exists) {
                final statusData = phaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                isMainPhaseCompletedByAnyEngineer = statusData['completed'] ?? false;
                mainPhaseCompletedByUid = statusData['lastUpdatedByUid'] as String?;
              }

              bool canEngineerEditThisPhase = !isMainPhaseCompletedByAnyEngineer;
              bool canGeneratePdfForMainPhase = isMainPhaseCompletedByAnyEngineer && mainPhaseCompletedByUid == _currentEngineerUid;

              Widget? trailingWidget;
              if (canEngineerEditThisPhase) {
                trailingWidget = IconButton(
                  icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                  tooltip: 'إضافة ملاحظة/صورة للمرحلة الرئيسية',
                  onPressed: () => _showAddNoteOrImageDialog(phaseId, phaseName),
                );
              } else if (canGeneratePdfForMainPhase) {
                trailingWidget = IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                  tooltip: 'إنشاء تقرير PDF (خاص بك)',
                  onPressed: () {
                    _generateAndSharePdf(phaseId, phaseName, isTestSection: false);
                  },
                );
              } else if (isMainPhaseCompletedByAnyEngineer) {
                trailingWidget = IconButton( // أيقونة معطلة إذا أكملها مهندس آخر
                  icon: Icon(Icons.picture_as_pdf_outlined, color: Colors.grey[400]),
                  tooltip: 'أكملها مهندس آخر',
                  onPressed: null,
                );
              }


              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: isMainPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.primaryColor,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phaseName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Text(isMainPhaseCompletedByAnyEngineer ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: isMainPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
                  trailing: trailingWidget,
                  children: [
                    _buildEntriesList(phaseId, isMainPhaseCompletedByAnyEngineer, phaseName),
                    if (subPhasesStructure.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppConstants.paddingSmall, right: AppConstants.paddingMedium, bottom: AppConstants.paddingSmall),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: subPhasesStructure.map((subPhaseMap) {
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
                                  bool isSubPhaseCompletedByAnyEngineer = false;
                                  String? subPhaseCompletedByUid;

                                  if (subPhaseStatusSnapshot.hasData && subPhaseStatusSnapshot.data!.exists) {
                                    final subStatusData = subPhaseStatusSnapshot.data!.data() as Map<String,dynamic>;
                                    isSubPhaseCompletedByAnyEngineer = subStatusData['completed'] ?? false;
                                    subPhaseCompletedByUid = subStatusData['lastUpdatedByUid'] as String?;
                                  }
                                  bool canEngineerEditThisSubPhase = canEngineerEditThisPhase && !isSubPhaseCompletedByAnyEngineer;
                                  bool canGeneratePdfForSubPhase = isSubPhaseCompletedByAnyEngineer && subPhaseCompletedByUid == _currentEngineerUid;

                                  Widget? subPhaseTrailingWidget;
                                  if (canEngineerEditThisSubPhase) {
                                    subPhaseTrailingWidget = Checkbox(
                                      value: isSubPhaseCompletedByAnyEngineer,
                                      activeColor: AppConstants.successColor,
                                      onChanged: (value) {
                                        _updateSubPhaseCompletionStatus(phaseId, subPhaseId, subPhaseName, value ?? false);
                                      },
                                    );
                                  } else if (canGeneratePdfForSubPhase) {
                                    subPhaseTrailingWidget = IconButton(
                                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal, size: 20),
                                      tooltip: 'تقرير PDF للمرحلة الفرعية (خاص بك)',
                                      onPressed: () {
                                        _generateAndSharePdf(subPhaseId, subPhaseName, isTestSection: false, isSubPhase: true);
                                      },
                                    );
                                  } else if (isSubPhaseCompletedByAnyEngineer) {
                                    subPhaseTrailingWidget = Icon(Icons.picture_as_pdf_outlined, color: Colors.grey[400], size: 20);
                                  }


                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isSubPhaseCompletedByAnyEngineer ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: isSubPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.textSecondary,
                                    ),
                                    title: Text(subPhaseName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isSubPhaseCompletedByAnyEngineer ? TextDecoration.lineThrough : null)),
                                    trailing: subPhaseTrailingWidget,
                                    onTap: () {
                                      if (canEngineerEditThisSubPhase) {
                                        _showAddNoteOrImageDialog(phaseId, subPhaseName, subPhaseId: subPhaseId);
                                      }
                                    },
                                    subtitle: _buildEntriesList(phaseId, isSubPhaseCompletedByAnyEngineer, subPhaseName, subPhaseId: subPhaseId, isSubEntry: true),
                                  );
                                }
                            );
                          }).toList(),
                        ),
                      ),
                    if (canEngineerEditThisPhase && !isMainPhaseCompletedByAnyEngineer)
                      Padding(
                        padding: const EdgeInsets.all(AppConstants.paddingSmall),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: const Text("إكمال المرحلة الرئيسية", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor),
                          onPressed: () => _updatePhaseCompletionStatus(phaseId, phaseName, true),
                        ),
                      ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildTestsTab() {
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للاختبارات."));
    }
    return ListView.builder(
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
                    String? testImageUrl;
                    String? engineerNameOnTest;
                    String? testCompletedByUid;

                    if (testStatusSnapshot.hasData && testStatusSnapshot.data!.exists) {
                      final statusData = testStatusSnapshot.data!.data() as Map<String, dynamic>;
                      isTestCompleted = statusData['completed'] ?? false;
                      testNote = statusData['note'] ?? '';
                      testImageUrl = statusData['imageUrl'] as String?;
                      engineerNameOnTest = statusData['engineerName'] as String?;
                      testCompletedByUid = statusData['lastUpdatedByUid'] as String?;
                    }
                    bool canEngineerEditThisTest = !isTestCompleted;
                    bool canGeneratePdfForTest = isTestCompleted && testCompletedByUid == _currentEngineerUid;

                    Widget? trailingWidget;
                    if (canEngineerEditThisTest) {
                      trailingWidget = Checkbox(
                        value: isTestCompleted,
                        activeColor: AppConstants.successColor,
                        onChanged: (value) {
                          _showUpdateTestStatusDialog(testId, testName, value ?? false, currentNote: testNote, currentImageUrl: testImageUrl);
                        },
                      );
                    } else if (canGeneratePdfForTest) {
                      trailingWidget = IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                        tooltip: 'إنشاء تقرير PDF للاختبار (خاص بك)',
                        onPressed: () {
                          _generateAndSharePdf(testId, testName, isTestSection: true, sectionName: sectionName, testNote: testNote, testImageUrl: testImageUrl, engineerNameOnTest: engineerNameOnTest);
                        },
                      );
                    } else if (isTestCompleted) {
                      trailingWidget = Icon(Icons.picture_as_pdf_outlined, color: Colors.grey[400]);
                    }

                    return ListTile(
                      title: Text(testName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isTestCompleted ? TextDecoration.lineThrough : null)),
                      leading: Icon(
                        isTestCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isTestCompleted ? AppConstants.successColor : AppConstants.textSecondary,
                        size: 20,
                      ),
                      trailing: trailingWidget,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (engineerNameOnTest != null && engineerNameOnTest.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("بواسطة: $engineerNameOnTest", style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic)),
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
                                onTap: () => _viewImageDialog(testImageUrl??''),
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
                        if (canEngineerEditThisTest) {
                          _showUpdateTestStatusDialog(testId, testName, !isTestCompleted, currentNote: testNote, currentImageUrl: testImageUrl);
                        }
                      },
                    );
                  }
              );
            }).toList(),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isPageLoading || _currentEngineerUid == null) {
      return Scaffold(appBar: AppBar(title: const Text('تحميل تفاصيل المشروع...')), body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)));
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_projectDataSnapshot != null && _projectDataSnapshot!.exists)
              _buildProjectSummaryCard(_projectDataSnapshot!.data() as Map<String, dynamic>),
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

  Future<void> _updatePhaseCompletionStatus(String phaseId, String phaseName, bool newStatus) async {
    // ... (نفس الكود السابق لهذه الدالة، التأكد من تخزين lastUpdatedByUid) ...
    if (!mounted || _currentEngineerUid == null) return;
    try {
      final phaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases_status')
          .doc(phaseId);

      await phaseDocRef.set({
        'completed': newStatus,
        'name': phaseName,
        'lastUpdatedByUid': _currentEngineerUid, // مهم جداً للتحكم في PDF
        'lastUpdatedByName': _currentEngineerName ?? 'مهندس',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة "$phaseName".', isError: false);
      // ... (باقي الكود للإشعارات)
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة: $e', isError: true);
    }
  }

  Future<void> _updateSubPhaseCompletionStatus(String mainPhaseId, String subPhaseId, String subPhaseName, bool newStatus) async {
    // ... (نفس الكود السابق لهذه الدالة، التأكد من تخزين lastUpdatedByUid) ...
    if (!mounted || _currentEngineerUid == null) return;
    try {
      final subPhaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('subphases_status')
          .doc(subPhaseId);

      await subPhaseDocRef.set({
        'completed': newStatus,
        'mainPhaseId': mainPhaseId,
        'name': subPhaseName,
        'lastUpdatedByUid': _currentEngineerUid, // مهم جداً للتحكم في PDF
        'lastUpdatedByName': _currentEngineerName ?? 'مهندس',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة الفرعية "$subPhaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة الفرعية: $e', isError: true);
    }
  }

  Future<void> _showUpdateTestStatusDialog(String testId, String testName, bool initialStatus, {String? currentNote, String? currentImageUrl}) async {
    bool newStatus = initialStatus;
    final noteController = TextEditingController(text: currentNote ?? "");
    String? tempImageUrl = currentImageUrl;
    XFile? pickedImageXFile; // استخدام XFile هنا أيضاً للتناسق إذا أردت
    bool isDialogLoading = false;

    String engineerNameForTest = _currentEngineerName ?? "مهندس";

    await showDialog<bool>(
      context: context,
      barrierDismissible: !isDialogLoading,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: Text('تحديث حالة اختبار: $testName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text('الاختبار مكتمل وناجح'),
                      value: newStatus,
                      onChanged: (val) => setDialogState(() => newStatus = val ?? false),
                      activeColor: AppConstants.successColor,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    if (tempImageUrl != null && pickedImageXFile == null)
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
                    if (pickedImageXFile != null)
                      kIsWeb
                          ? Image.network(pickedImageXFile!.path, height: 80, fit: BoxFit.cover)
                          : Image.file(File(pickedImageXFile!.path), height: 80, fit: BoxFit.cover),
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, color: AppConstants.primaryColor),
                      label: Text(pickedImageXFile == null && tempImageUrl == null ? 'إضافة صورة (اختياري)' : (pickedImageXFile == null ? 'تغيير الصورة الحالية' : 'تغيير الصورة المختارة'), style: const TextStyle(color: AppConstants.primaryColor)),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 60); // أو المعرض إذا أردت خيارين هنا أيضاً
                        if (picked != null) {
                          setDialogState(() {
                            pickedImageXFile = picked;
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
                  onPressed: isDialogLoading ? null : () async {
                    setDialogState(() => isDialogLoading = true);
                    String? finalImageUrl = tempImageUrl;

                    if (pickedImageXFile != null) {
                      try {
                        var request = http.MultipartRequest('POST', Uri.parse(AppConstants.UPLOAD_URL));
                        request.files.add(await http.MultipartFile.fromPath(
                          'image', // اسم الحقل الذي يتوقعه سكربت PHP
                          pickedImageXFile!.path,
                          contentType: MediaType.parse(pickedImageXFile!.mimeType ?? 'image/jpeg'),
                        ));

                        var streamedResponse = await request.send();
                        var response = await http.Response.fromStream(streamedResponse);

                        if (response.statusCode == 200) {
                          var responseData = json.decode(response.body);
                          if (responseData['status'] == 'success' && responseData['url'] != null) {
                            finalImageUrl = responseData['url'];
                          } else {
                            throw Exception(responseData['message'] ?? 'فشل رفع الصورة من السيرفر.');
                          }
                        } else {
                          throw Exception('خطأ في الاتصال بالسيرفر: ${response.statusCode}');
                        }
                      } catch (e) {
                        _showFeedbackSnackBar(stfContext, 'فشل رفع صورة الاختبار: $e', isError: true);
                        setDialogState(() => isDialogLoading = false);
                        return;
                      }
                    }

                    try {
                      final testDocRef = FirebaseFirestore.instance
                          .collection('projects')
                          .doc(widget.projectId)
                          .collection('tests_status')
                          .doc(testId);

                      await testDocRef.set({
                        'completed': newStatus,
                        'name': testName,
                        'note': noteController.text.trim(),
                        'imageUrl': finalImageUrl,
                        'lastUpdatedByUid': _currentEngineerUid, // مهم جداً للتحكم في PDF
                        'lastUpdatedByName': engineerNameForTest,
                        'lastUpdatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      Navigator.pop(dialogContext, true);
                      _showFeedbackSnackBar(context, 'تم تحديث حالة الاختبار "$testName".', isError: false);
                    } catch (e) {
                      _showFeedbackSnackBar(stfContext, 'فشل تحديث حالة الاختبار: $e', isError: true);
                    } finally {
                      setDialogState(() => isDialogLoading = false);
                    }
                  },
                  child: isDialogLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('حفظ الحالة'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                ),
              ],
            ),
          );
        });
      },
    );
  }


  void _showImageSourceActionSheet(BuildContext context, Function(List<XFile>?) onImagesSelected) {
    // ... (نفس الكود السابق لهذه الدالة) ...
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppConstants.primaryColor),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (image != null) {
                    onImagesSelected([image]);
                  } else {
                    onImagesSelected(null);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppConstants.primaryColor),
                title: const Text('اختيار صور من المعرض'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final ImagePicker picker = ImagePicker();
                  final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
                  if (images.isNotEmpty) {
                    onImagesSelected(images);
                  } else {
                    onImagesSelected(null);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddNoteOrImageDialog(String phaseId, String phaseOrSubPhaseName, {String? subPhaseId}) async {
    if (!mounted || _currentEngineerUid == null) return;
    final noteController = TextEditingController();
    bool isDialogLoading = false;
    final formKeyDialog = GlobalKey<FormState>();

    String dialogTitle = subPhaseId == null
        ? 'إضافة إدخال للمرحلة: $phaseOrSubPhaseName'
        : 'إضافة إدخال للمرحلة الفرعية: $phaseOrSubPhaseName';

    String entriesCollectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

    List<XFile>? _selectedImagesInDialogStateful;

    await showDialog(
      context: context,
      barrierDismissible: !isDialogLoading,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setDialogContentState) {
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
                            hintText: 'أدخل ملاحظتك هنا (اختياري إذا أضفت صور)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes_rounded)
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if ((value == null || value.isEmpty) && (_selectedImagesInDialogStateful == null || _selectedImagesInDialogStateful!.isEmpty)) {
                            return 'الرجاء إدخال ملاحظة أو إضافة صورة واحدة على الأقل.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (_selectedImagesInDialogStateful != null && _selectedImagesInDialogStateful!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _selectedImagesInDialogStateful!.map((xFile) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
                                    child: kIsWeb
                                        ? Image.network(xFile.path, height: 100, width: 100, fit: BoxFit.cover)
                                        : Image.file(File(xFile.path), height: 100, width: 100, fit: BoxFit.cover),
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
                                        setDialogContentState(() {
                                          _selectedImagesInDialogStateful!.remove(xFile);
                                          if (_selectedImagesInDialogStateful!.isEmpty) {
                                            _selectedImagesInDialogStateful = null;
                                          }
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
                            (_selectedImagesInDialogStateful == null || _selectedImagesInDialogStateful!.isEmpty)
                                ? 'إضافة صور (اختياري)'
                                : 'تغيير/إضافة المزيد من الصور',
                            style: const TextStyle(color: AppConstants.primaryColor)
                        ),
                        onPressed: () {
                          _showImageSourceActionSheet(context, (List<XFile>? images) {
                            if (images != null && images.isNotEmpty) {
                              setDialogContentState(() {
                                if (_selectedImagesInDialogStateful == null) {
                                  _selectedImagesInDialogStateful = [];
                                }
                                _selectedImagesInDialogStateful!.addAll(images);
                              });
                            }
                          });
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
                  onPressed: isDialogLoading ? null : () async {
                    if (!formKeyDialog.currentState!.validate()) return;

                    setDialogContentState(() => isDialogLoading = true);
                    List<String> uploadedImageUrls = [];

                    if (_selectedImagesInDialogStateful != null && _selectedImagesInDialogStateful!.isNotEmpty) {
                      for (int i = 0; i < _selectedImagesInDialogStateful!.length; i++) {
                        final XFile imageFile = _selectedImagesInDialogStateful![i];
                        try {
                          var request = http.MultipartRequest('POST', Uri.parse(AppConstants.UPLOAD_URL));
                          request.files.add(await http.MultipartFile.fromPath(
                            'image', // اسم الحقل الذي يتوقعه سكربت PHP
                            imageFile.path,
                            contentType: MediaType.parse(imageFile.mimeType ?? 'image/jpeg'), // استخدام mimeType من XFile
                          ));

                          var streamedResponse = await request.send();
                          var response = await http.Response.fromStream(streamedResponse);

                          if (response.statusCode == 200) {
                            var responseData = json.decode(response.body);
                            if (responseData['status'] == 'success' && responseData['url'] != null) {
                              uploadedImageUrls.add(responseData['url']);
                            } else {
                              throw Exception(responseData['message'] ?? 'فشل رفع الصورة (${i+1}) من السيرفر.');
                            }
                          } else {
                            throw Exception('خطأ في الاتصال بالسيرفر لرفع الصورة (${i+1}): ${response.statusCode}');
                          }
                        } catch (e) {
                          if (mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع الصورة (${i+1}): $e', isError: true,);
                          // يمكنك إيقاف العملية هنا إذا فشلت إحدى الصور
                          // setDialogContentState(() => isDialogLoading = false);
                          // return;
                        }
                      }
                    }

                    // التأكد من أن جميع الصور تم رفعها بنجاح قبل المتابعة (إذا أردت ذلك)
                    // if (_selectedImagesInDialogStateful != null && uploadedImageUrls.length != _selectedImagesInDialogStateful!.length) {
                    //   _showFeedbackSnackBar(stfContext, 'لم يتم رفع جميع الصور بنجاح. حاول مرة أخرى.', isError: true);
                    //   setDialogContentState(() => isDialogLoading = false);
                    //   return;
                    // }


                    try {
                      await FirebaseFirestore.instance.collection(entriesCollectionPath).add({
                        'type': uploadedImageUrls.isNotEmpty ? 'image_with_note' : 'note',
                        'note': noteController.text.trim(),
                        'imageUrls': uploadedImageUrls.isNotEmpty ? uploadedImageUrls : null,
                        'engineerUid': _currentEngineerUid,
                        'engineerName': _currentEngineerName ?? 'مهندس',
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تمت إضافة الإدخال بنجاح.', isError: false);
                    } catch (e) {
                      if (mounted) _showFeedbackSnackBar(stfContext, 'فشل إضافة الإدخال: $e', isError: true,);
                    } finally {
                      setDialogContentState(() => isDialogLoading = false);
                    }
                  },
                  child: isDialogLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,)) : const Text('حفظ الإدخال'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildEntriesList(String phaseOrMainPhaseId, bool parentCompleted, String parentName, {String? subPhaseId, bool isSubEntry = false}) {
    // ... (نفس الكود السابق لهذه الدالة، هي بالفعل تعرض imageUrls) ...
    bool canAddEntry = !parentCompleted;

    String entriesCollectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseOrMainPhaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

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
                child: Text(isSubEntry ? 'لا توجد إدخالات لهذه المرحلة الفرعية.' : 'لا توجد إدخالات لهذه المرحلة.', style: const TextStyle(color: AppConstants.textSecondary, fontStyle: FontStyle.italic, fontSize: 13)),
              );
            }
            final entries = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entryData = entries[index].data() as Map<String, dynamic>;
                final String note = entryData['note'] ?? '';
                final List<dynamic>? imageUrlsDynamic = entryData['imageUrls'] as List<dynamic>?;
                final List<String> imageUrls = imageUrlsDynamic?.map((e) => e.toString()).toList() ?? [];

                final String engineerName = entryData['engineerName'] ?? 'مهندس';
                final Timestamp? timestamp = entryData['timestamp'] as Timestamp?;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrls.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: note.isNotEmpty ? AppConstants.paddingSmall : 0),
                            child: Wrap(
                              spacing: AppConstants.paddingSmall / 2,
                              runSpacing: AppConstants.paddingSmall / 2,
                              children: imageUrls.map((url) {
                                return InkWell(
                                  onTap: () => _viewImageDialog(url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2.5),
                                    child: Image.network(url, height: 100, width: 100, fit: BoxFit.cover,
                                        errorBuilder: (c,e,s) => Container(height: 100, width:100, color: AppConstants.backgroundColor, child: Center(child: Icon(Icons.broken_image, color: AppConstants.textSecondary.withOpacity(0.5), size: 40)))),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: imageUrls.isNotEmpty ? AppConstants.paddingSmall : 0),
                            child: Text(note, style: const TextStyle(fontSize: 13.5)),
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
        if (canAddEntry)
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.paddingSmall),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(isSubEntry ? 'إضافة للمرحلة الفرعية' : 'إضافة للمرحلة الرئيسية', style: const TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: AppConstants.primaryColor),
                onPressed: () => _showAddNoteOrImageDialog(phaseOrMainPhaseId, parentName, subPhaseId: subPhaseId),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _viewImageDialog(String imageUrl) async {
    // ... (نفس الكود السابق لهذه الدالة) ...
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
            progress == null ? child : const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => const Center(child: Icon(Icons.error_outline, color: AppConstants.errorColor, size: 50)),
          ),
        ),
        actions: [
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

  Future<void> _generateAndSharePdf(String phaseOrTestId, String name, {required bool isTestSection, bool isSubPhase = false, String? sectionName, String? testNote, String? testImageUrl, String? engineerNameOnTest}) async {
    // TODO: عند تنفيذ PDF، تأكد من أن البيانات التي يتم جلبها (خاصة الإدخالات Notes/Images)
    // قد تحتاج إلى فلترتها بناءً على `_currentEngineerUid` إذا كان المقصود أن التقرير يعكس "عمله فقط" بشكل صارم.
    // حالياً، الشرط هو على *من يمكنه الضغط على زر إنشاء PDF*.
    _showFeedbackSnackBar(context, "ميزة إنشاء PDF قيد التطوير حالياً.", isError: false);

    String itemType = isTestSection ? 'اختبار' : (isSubPhase ? 'مرحلة فرعية' : 'مرحلة');
    String reportContent = "تقرير $itemType: $name\n";
    if (isTestSection && sectionName != null) {
      reportContent += "القسم: $sectionName\n";
    }
    reportContent += "بواسطة: ${_currentEngineerName ?? 'مهندس'}\n";
    reportContent += "تاريخ الإنشاء: ${DateFormat('yyyy/MM/dd HH:mm', 'ar').format(DateTime.now())}\n\n";

    if (isTestSection) {
      if (testNote != null && testNote.isNotEmpty) reportContent += "الملاحظات: $testNote\n";
      if (testImageUrl != null) reportContent += "رابط الصورة: $testImageUrl\n";
    } else {
      // لجلب الملاحظات والصور للمرحلة أو المرحلة الفرعية من Firestore بناءً على phaseOrTestId
      // إذا كان يجب أن يعرض التقرير فقط إدخالات المهندس الحالي، أضف .where('engineerUid', isEqualTo: _currentEngineerUid)
      reportContent += "تفاصيل $itemType (ملاحظات وصور) هنا...\n";
    }

    reportContent += "\n\n";
    reportContent += "ملاحظة هامة: هذا التقرير ساري المفعول لأي مشاكل يتم الإبلاغ عنها خلال 24 ساعة من استلامه.\n";
    Share.share(reportContent, subject: "تقرير: $name");
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

        if (!textPainter.didExceedMaxLines) {
          return RichText(
            softWrap: true,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.start,
            textDirection: ui.TextDirection.rtl,
            text: text,
          );
        }

        int endIndex = textPainter.getPositionForOffset(Offset(textSize.width - linkSize.width, textSize.height)).offset;
        endIndex = (endIndex < 0 || endIndex > widget.text.length) ? widget.text.length : endIndex;

        TextSpan textSpan;
        if (_readMore && widget.text.length > endIndex && endIndex > 0) { // Added checks for endIndex
          textSpan = TextSpan(
            text: widget.text.substring(0, endIndex) + "...",
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5),
            children: <TextSpan>[link],
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
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          text: textSpan,
        );
      },
    );
    return result;
  }
}