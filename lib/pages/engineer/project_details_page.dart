// lib/pages/engineer/project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http; // If still using PHP script for upload
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui; // For TextDirection
// Import PDF generation and printing packages when you're ready to implement that part
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:path_provider/path_provider.dart';

// --- AppConstants (نسخ أو استيراد) ---
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
  static const String UPLOAD_URL = 'https://creditphoneqatar.com/eng-app/upload_image.php'; // إذا كنت لا تزال تستخدمه
}
// --- نهاية AppConstants ---


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

  // --- قوائم المراحل والاختبارات (نفس التي قدمتها) ---
  static const List<Map<String, dynamic>> predefinedPhasesStructure = [
    // ... (انسخ نفس القائمة التي قدمتها سابقاً هنا) ...
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
    // ... (انسخ نفس القائمة التي قدمتها سابقاً هنا) ...
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
  // --- نهاية قوائم المراحل والاختبارات ---


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
    await _fetchCurrentEngineerData(); // جلب بيانات المهندس أولاً
    await _fetchProjectData();        // ثم بيانات المشروع
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
        Navigator.pop(context); // العودة إذا لم يتم العثور على المشروع
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

  // --- AppBar ---
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

  // --- Summary Card ---
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
            // Text(projectName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
            // const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
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


  // --- Building Tabs ---
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
              if (phaseStatusSnapshot.hasData && phaseStatusSnapshot.data!.exists) {
                final statusData = phaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                isMainPhaseCompletedByAnyEngineer = statusData['completed'] ?? false;
              }

              bool canEngineerEditThisPhase = !isMainPhaseCompletedByAnyEngineer;

              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                child: ExpansionTile(
                  // key: PageStorageKey<String>(phaseId),
                  leading: CircleAvatar(
                    backgroundColor: isMainPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.primaryColor,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phaseName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Text(isMainPhaseCompletedByAnyEngineer ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: isMainPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
                  trailing: canEngineerEditThisPhase
                      ? IconButton(
                    icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                    tooltip: 'إضافة ملاحظة/صورة للمرحلة الرئيسية',
                    onPressed: () => _showAddNoteOrImageDialog(phaseId, phaseName),
                  )
                      : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                    tooltip: 'إنشاء تقرير PDF',
                    onPressed: () {
                      _generateAndSharePdf(phaseId, phaseName, isTestSection: false);
                    },
                  ),
                  children: [
                    _buildEntriesList(phaseId, isMainPhaseCompletedByAnyEngineer, phaseName), // لعرض الملاحظات والصور للمرحلة الرئيسية
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
                                  if (subPhaseStatusSnapshot.hasData && subPhaseStatusSnapshot.data!.exists) {
                                    isSubPhaseCompletedByAnyEngineer = (subPhaseStatusSnapshot.data!.data() as Map<String,dynamic>)['completed'] ?? false;
                                  }
                                  bool canEngineerEditThisSubPhase = canEngineerEditThisPhase && !isSubPhaseCompletedByAnyEngineer;

                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isSubPhaseCompletedByAnyEngineer ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: isSubPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.textSecondary,
                                    ),
                                    title: Text(subPhaseName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isSubPhaseCompletedByAnyEngineer ? TextDecoration.lineThrough : null)),
                                    trailing: canEngineerEditThisSubPhase
                                        ? Checkbox(
                                      value: isSubPhaseCompletedByAnyEngineer,
                                      activeColor: AppConstants.successColor,
                                      onChanged: (value) {
                                        _updateSubPhaseCompletionStatus(phaseId, subPhaseId, subPhaseName, value ?? false);
                                      },
                                    )
                                        : null,
                                    onTap: () {
                                      if (canEngineerEditThisSubPhase) {
                                        _showAddNoteOrImageDialog(phaseId, subPhaseName, subPhaseId: subPhaseId);
                                      }
                                    },
                                    subtitle: _buildEntriesList(phaseId, isSubPhaseCompletedByAnyEngineer, subPhaseName, subPhaseId: subPhaseId, isSubEntry: true), // لعرض ملاحظات وصور المرحلة الفرعية
                                  );
                                }
                            );
                          }).toList(),
                        ),
                      ),
                    if (canEngineerEditThisPhase && !isMainPhaseCompletedByAnyEngineer) // زر إكمال المرحلة الرئيسية
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
            // key: PageStorageKey<String>(sectionId),
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
                    String? engineerNameOnTest; // اسم المهندس الذي أجرى الاختبار

                    if (testStatusSnapshot.hasData && testStatusSnapshot.data!.exists) {
                      final statusData = testStatusSnapshot.data!.data() as Map<String, dynamic>;
                      isTestCompleted = statusData['completed'] ?? false;
                      testNote = statusData['note'] ?? '';
                      testImageUrl = statusData['imageUrl'] as String?;
                      engineerNameOnTest = statusData['engineerName'] as String?;
                    }
                    bool canEngineerEditThisTest = !isTestCompleted;


                    return ListTile(
                      title: Text(testName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: isTestCompleted ? TextDecoration.lineThrough : null)),
                      leading: Icon(
                        isTestCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isTestCompleted ? AppConstants.successColor : AppConstants.textSecondary,
                        size: 20,
                      ),
                      trailing: canEngineerEditThisTest
                          ? Checkbox(
                        value: isTestCompleted,
                        activeColor: AppConstants.successColor,
                        onChanged: (value) {
                          _showUpdateTestStatusDialog(testId, testName, value ?? false, currentNote: testNote, currentImageUrl: testImageUrl);
                        },
                      )
                          : (isTestCompleted ? IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                        tooltip: 'إنشاء تقرير PDF للاختبار',
                        onPressed: () {
                          _generateAndSharePdf(testId, testName, isTestSection: true, sectionName: sectionName, testNote: testNote, testImageUrl: testImageUrl, engineerNameOnTest: engineerNameOnTest);
                        },
                      ) : null ),
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
                                onTap: () => _viewImageDialog(testImageUrl!),
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

  // ... (دوال _updatePhaseCompletionStatus, _updateSubPhaseCompletionStatus, _showAddNoteOrImageDialog, _viewImageDialog) ...
  // ... (دالة _updateTestStatusDialog, _generateAndSharePdf) ...
  // سنقوم بتعريف هذه الدوال في الرسائل القادمة.

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading || _currentEngineerUid == null) {
      return Scaffold(appBar: AppBar(title: const Text('تحميل تفاصيل المشروع...')), body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)));
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: _buildAppBar(), // AppBar سيحتوي على TabBar
        body: Column( // استخدام Column لعرض ملخص المشروع فوق TabBarView
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


// --- الدوال المساعدة (سيتم تفصيلها لاحقًا) ---
  Future<void> _updatePhaseCompletionStatus(String phaseId, String phaseName, bool newStatus) async {
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
        'lastUpdatedByUid': _currentEngineerUid,
        'lastUpdatedByName': _currentEngineerName ?? 'مهندس',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        // إذا كانت مكتملة، يمكنك إضافة engineerSignature, completionTimestamp
      }, SetOptions(merge: true));

      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة "$phaseName".', isError: false);
      // TODO: إرسال إشعارات للمسؤول والعميل والمهندسين الآخرين إذا اكتملت
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      if (projectDoc.exists) {
        final projectData = projectDoc.data() as Map<String, dynamic>;
        final projectNameVal = projectData['name'] ?? 'المشروع';
        final clientUid = projectData['clientId'] as String?;
        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
        final List<String> allAssignedEngineerUids = assignedEngineersRaw.map((e) => e['uid'].toString()).toList();
        final List<String> otherEngineersUids = allAssignedEngineerUids.where((uid) => uid != _currentEngineerUid).toList();


        if (newStatus) { // Send notifications only on completion
          // Notify Admins
          // (Assuming you have a way to get admin UIDs or a topic for admins)
          // _sendNotificationToAdmins(projectId: widget.projectId, projectName: projectNameVal, phaseName: phaseName, completedBy: _currentEngineerName ?? "مهندس");

          // Notify Client
          if (clientUid != null) {
            // _sendNotificationToClient(clientId: clientUid, projectId: widget.projectId, projectName: projectNameVal, phaseName: phaseName);
          }
          // Notify other engineers on the project
          if (otherEngineersUids.isNotEmpty) {
            // _sendNotificationToOtherEngineers(engineerUids: otherEngineersUids, projectId: widget.projectId, projectName: projectNameVal, phaseName: phaseName, completedBy: _currentEngineerName ?? "مهندس");
          }
        }
      }

    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة: $e', isError: true);
    }
  }

  Future<void> _updateSubPhaseCompletionStatus(String mainPhaseId, String subPhaseId, String subPhaseName, bool newStatus) async {
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
        'lastUpdatedByUid': _currentEngineerUid,
        'lastUpdatedByName': _currentEngineerName ?? 'مهندس',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة الفرعية "$subPhaseName".', isError: false);
      // TODO: إرسال إشعارات مشابهة عند إكمال مرحلة فرعية
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة الفرعية: $e', isError: true);
    }
  }

  Future<void> _showUpdateTestStatusDialog(String testId, String testName, bool initialStatus, {String? currentNote, String? currentImageUrl}) async {
    bool newStatus = initialStatus; // حالة الإكمال الحالية أو الجديدة
    final noteController = TextEditingController(text: currentNote ?? "");
    String? tempImageUrl = currentImageUrl;
    File? pickedImageFile;
    bool isDialogLoading = false; // حالة تحميل خاصة بالنافذة

    final currentUser = FirebaseAuth.instance.currentUser;
    String engineerNameForTest = _currentEngineerName ?? "مهندس"; // استخدام اسم المهندس الحالي

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
                    if (tempImageUrl != null && pickedImageFile == null) // عرض الصورة الحالية فقط إذا لم يتم اختيار واحدة جديدة
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
                            // tempImageUrl = null; // إذا اختار صورة جديدة، قد نرغب في تجاهل القديمة تلقائياً
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
                    String? finalImageUrl = tempImageUrl; // ابدأ بالصورة الحالية (قد تكون null)

                    if (pickedImageFile != null) { // إذا تم اختيار صورة جديدة، ارفعها
                      try {
                        final refPath = 'project_tests/${widget.projectId}/$testId/${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final ref = FirebaseStorage.instance.ref().child(refPath);
                        await ref.putFile(pickedImageFile!);
                        finalImageUrl = await ref.getDownloadURL();
                      } catch (e) {
                        _showFeedbackSnackBar(stfContext, 'فشل رفع صورة الاختبار: $e', isError: true);
                        setDialogState(() => isDialogLoading = false);
                        return; // لا تكمل إذا فشل الرفع
                      }
                    }
                    // إذا لم يتم اختيار صورة جديدة ولم تكن هناك صورة حالية، finalImageUrl سيبقى null

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
                        'imageUrl': finalImageUrl, // قد يكون null
                        'lastUpdatedByUid': _currentEngineerUid,
                        'lastUpdatedByName': engineerNameForTest,
                        'lastUpdatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      Navigator.pop(dialogContext, true); // أغلق النافذة وأرجع true
                      _showFeedbackSnackBar(context, 'تم تحديث حالة الاختبار "$testName".', isError: false); // SnackBar على الصفحة الرئيسية
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

  Future<void> _showAddNoteOrImageDialog(String phaseId, String phaseOrSubPhaseName, {String? subPhaseId}) async {
    if (!mounted || _currentEngineerUid == null) return;
    final noteController = TextEditingController();
    File? pickedImageFile;
    bool isDialogLoading = false; // حالة تحميل خاصة بالنافذة المنبثقة
    final formKeyDialog = GlobalKey<FormState>(); // مفتاح نموذج للنافذة المنبثقة

    String dialogTitle = subPhaseId == null
        ? 'إضافة إدخال للمرحلة: $phaseOrSubPhaseName'
        : 'إضافة إدخال للمرحلة الفرعية: $phaseOrSubPhaseName';

    String entriesCollectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';


    await showDialog(
      context: context,
      barrierDismissible: !isDialogLoading,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setDialogState) { // استخدام stfContext هنا
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
                          final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (picked != null) {
                            setDialogState(() { // استخدام setDialogState الخاص بالـ StatefulBuilder
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
                  onPressed: isDialogLoading ? null : () async {
                    if (!formKeyDialog.currentState!.validate()) return;

                    setDialogState(() => isDialogLoading = true);
                    String? imageUrl;

                    if (pickedImageFile != null) {
                      try {
                        // استخدام مسار فريد أكثر للصورة
                        final timestampForPath = DateTime.now().millisecondsSinceEpoch;
                        final imageName = '${_currentEngineerUid}_${timestampForPath}.jpg';
                        final refPath = subPhaseId == null
                            ? 'project_entries/${widget.projectId}/$phaseId/$imageName'
                            : 'project_entries/${widget.projectId}/$subPhaseId/$imageName'; // استخدام subPhaseId كجزء من المسار

                        final ref = FirebaseStorage.instance.ref().child(refPath);
                        await ref.putFile(pickedImageFile!);
                        imageUrl = await ref.getDownloadURL();
                      } catch (e) {
                        if (mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع الصورة: $e', isError: true,);
                        setDialogState(() => isDialogLoading = false);
                        return;
                      }
                    }

                    try {
                      await FirebaseFirestore.instance.collection(entriesCollectionPath).add({
                        'type': imageUrl != null ? 'image_with_note' : 'note',
                        'note': noteController.text.trim(),
                        'imageUrl': imageUrl,
                        'engineerUid': _currentEngineerUid,
                        'engineerName': _currentEngineerName ?? 'مهندس',
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(dialogContext);
                      _showFeedbackSnackBar(context, 'تمت إضافة الإدخال بنجاح.', isError: false);
                    } catch (e) {
                      if (mounted) _showFeedbackSnackBar(stfContext, 'فشل إضافة الإدخال: $e', isError: true,);
                    } finally {
                      setDialogState(() => isDialogLoading = false);
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
    // إذا كان الأصل (مرحلة رئيسية أو فرعية) مكتملًا، لا تعرض زر إضافة
    bool canAddEntry = !parentCompleted;

    String entriesCollectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseOrMainPhaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries'; // استخدام subPhaseId للمسار إذا كانت مرحلة فرعية

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
                final String? imageUrl = entryData['imageUrl'] as String?;
                final String engineerName = entryData['engineerName'] ?? 'مهندس';
                final Timestamp? timestamp = entryData['timestamp'] as Timestamp?;
                final String entryType = entryData['type'] ?? 'note';

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), // تقليل الهامش الأفقي
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null)
                          InkWell(
                            onTap: () => _viewImageDialog(imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2.5),
                              child: Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover,
                                  errorBuilder: (c,e,s) => Container(height: 100, color: AppConstants.backgroundColor, child: Center(child: Icon(Icons.broken_image, color: AppConstants.textSecondary.withOpacity(0.5), size: 40)))),
                            ),
                          ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: imageUrl != null ? AppConstants.paddingSmall : 0),
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
        if (canAddEntry) // عرض زر الإضافة فقط إذا لم يكن الأصل مكتملاً
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
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.all(10), // لتقليل الحواف حول الصورة
        content: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain, // استخدام contain لعرض الصورة كاملة
            loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
            errorBuilder: (ctx, err, st) => const Center(child: Icon(Icons.error_outline, color: AppConstants.errorColor, size: 50)),
          ),
        ),
        actions: [ // إضافة زر إغلاق واضح
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


  Future<void> _generateAndSharePdf(String phaseOrTestId, String name, {required bool isTestSection, String? sectionName, String? testNote, String? testImageUrl, String? engineerNameOnTest}) async {
    _showFeedbackSnackBar(context, "ميزة إنشاء PDF قيد التطوير حالياً.", isError: false);

    // TODO: منطق إنشاء PDF الفعلي (سيكون معقدًا ويتطلب مكتبات مثل pdf و printing)
    // 1. جمع البيانات:
    //    - اسم المشروع، اسم المهندس الحالي
    //    - للمراحل: اسم المرحلة، ملاحظاتها وصورها (من entries)، حالة المراحل الفرعية وملاحظاتها وصورها.
    //    - للاختبارات: اسم قسم الاختبار، اسم الاختبار، حالته، ملاحظته، صورته.
    // 2. استخدام مكتبة pdf لإنشاء المستند:
    //    - pw.Document doc = pw.Document();
    //    - إضافة خط عربي للـ pdf.
    //    - بناء صفحات الـ pdf باستخدام pw.Page، pw.Column، pw.Text، pw.Image (لصور الشبكة pw.NetworkImage).
    //    - تذكر التعامل مع اتجاه النص RTL.
    //    - إضافة الملاحظة المطلوبة في الأسفل باللون الأحمر العريض.
    // 3. حفظ الـ PDF:
    //    - final output = await getTemporaryDirectory(); // أو getApplicationDocumentsDirectory
    //    - final file = File("${output.path}/report_${phaseOrTestId}.pdf");
    //    - await file.writeAsBytes(await doc.save());
    // 4. مشاركة الـ PDF:
    //    - Share.shareFiles([file.path], text: 'تقرير $name لمشروع X');
    //    - أو استخدام url_launcher لفتح واتساب/البريد مع الملف.

    // مثال على نص التقرير الذي سيتم تضمينه في الـ PDF (مبسط):
    String reportContent = "تقرير ${isTestSection ? 'اختبار' : 'مرحلة'}: $name\n";
    if (isTestSection && sectionName != null) {
      reportContent += "القسم: $sectionName\n";
    }
    reportContent += "بواسطة: ${_currentEngineerName ?? 'مهندس'}\n";
    reportContent += "تاريخ الإنشاء: ${DateFormat('yyyy/MM/dd HH:mm', 'ar').format(DateTime.now())}\n\n";

    if (isTestSection) {
      if (testNote != null && testNote.isNotEmpty) reportContent += "الملاحظات: $testNote\n";
      if (testImageUrl != null) reportContent += "رابط الصورة: $testImageUrl\n";
    } else {
      // TODO: جلب الملاحظات والصور للمرحلة الرئيسية والفرعية من Firestore
      // ...
      reportContent += "تفاصيل المرحلة والمراحل الفرعية هنا...\n";
    }

    reportContent += "\n\n";
    reportContent += "ملاحظة هامة: هذا التقرير ساري المفعول لأي مشاكل يتم الإبلاغ عنها خلال 24 ساعة من استلامه.\n";

    // يمكنك استخدام Share.share(reportContent) كمؤقت حتى يتم تنفيذ PDF
    Share.share(reportContent, subject: "تقرير: $name");


  }


} // نهاية _ProjectDetailsPageState

// --- ExpandableText Widget (تبقى كما هي) ---
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
          textAlign: TextAlign.start,
          textDirection: ui.TextDirection.rtl,
          text: textSpan,
        );
      },
    );
    return result;
  }
}