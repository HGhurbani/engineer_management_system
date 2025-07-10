// lib/pages/engineer/project_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io'; // For File
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui' as ui; // For TextDirection
import 'dart:async';

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:engineer_management_system/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

// --- PDF and Path Provider Imports ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle; // For font loading
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import '../../utils/pdf_styles.dart';
import '../../utils/pdf_image_cache.dart';
import '../../utils/report_storage.dart';
import '../../utils/pdf_report_generator.dart';
import '../../utils/part_request_pdf_generator.dart';
import '../../utils/progress_dialog.dart';
// --- End PDF Imports ---

import '../../main.dart'; // Assuming helper functions are in main.dart
import '../auth/login_page.dart' show LoginConstants;
import '../../theme/app_constants.dart';



class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  final String? highlightItemId;
  final String? notificationType;
  const ProjectDetailsPage({
    super.key,
    required this.projectId,
    this.highlightItemId,
    this.notificationType,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}
class _ProjectDetailsPageState extends State<ProjectDetailsPage> with TickerProviderStateMixin {
  String? _currentEngineerUid;
  String? _currentEngineerName;
  bool _isPageLoading = true;
  DocumentSnapshot? _projectDataSnapshot;
  String? _clientPhone;

  String? _highlightPhaseId;
  String? _highlightSubPhaseId;
  String? _highlightTestId;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _phaseKeys = {};
  final Map<String, GlobalKey> _subPhaseKeys = {};
  final Map<String, GlobalKey> _testKeys = {};

  late TabController _tabController;

  // --- Font for PDF ---
  pw.Font? _arabicFont; // To store the loaded font for PDF

  static const List<Map<String, dynamic>> predefinedPhasesStructure = [
    // ... (Your existing predefinedPhasesStructure - no changes here) ...
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
    // ... (Your existing finalCommissioningTests - no changes here) ...
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
    _tabController = TabController(length: 7, vsync: this);
    _currentEngineerUid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.notificationType != null && widget.highlightItemId != null) {
      final type = widget.notificationType!;
      if (type.contains('subphase')) {
        _highlightSubPhaseId = widget.highlightItemId;
      } else if (type.contains('phase')) {
        _highlightPhaseId = widget.highlightItemId;
      } else if (type.contains('test')) {
        _highlightTestId = widget.highlightItemId;
      }
    }
    _loadArabicFont(); // Load the font
    _fetchInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
  }

  Widget _buildEmployeesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingSmall),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
              label: const Text('إضافة عامل', style: TextStyle(color: Colors.white)),
              onPressed: _showAddEmployeeDialog,
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('employeeAssignments')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
              }
              if (snapshot.hasError) {
                return const Center(child: Text('فشل تحميل الموظفين'));
              }
              final assignments = snapshot.data?.docs ?? [];
              if (assignments.isEmpty) {
                return const Center(child: Text('لا يوجد موظفون مضافون'));
              }
              return ListView.builder(
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final data = assignments[index].data() as Map<String, dynamic>;
                  final employeeId = data['employeeId'] as String? ?? '';
                  final employeeName = data['employeeName'] as String? ?? 'موظف';
                  final phaseName = data['phaseName'] as String? ?? '';
                  final subPhaseName = data['subPhaseName'] as String?;
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .where('userId', isEqualTo: employeeId)
                        .where('projectId', isEqualTo: widget.projectId)
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, attSnap) {
                      String attendanceInfo = 'لا يوجد سجل';
                      if (attSnap.hasData && attSnap.data!.docs.isNotEmpty) {
                        final attData = attSnap.data!.docs.first.data() as Map<String, dynamic>;
                        final Timestamp ts = attData['timestamp'] as Timestamp;
                        final type = attData['type'] == 'check_in' ? 'حضور' : 'انصراف';
                        attendanceInfo = '$type - ${DateFormat('dd/MM HH:mm').format(ts.toDate())}';
                      }
                      return ListTile(
                        title: Text(employeeName),
                        subtitle: Text(
                            'المرحلة: $phaseName${subPhaseName != null ? ' > $subPhaseName' : ''}\n$attendanceInfo'),
                        // trailing: PopupMenuButton<String>(
                        //   onSelected: (value) {
                        //     if (value == 'check_in') {
                        //       _recordEmployeeAttendance(employeeId, 'check_in');
                        //     } else if (value == 'check_out') {
                        //       _recordEmployeeAttendance(employeeId, 'check_out');
                        //     }
                        //   },
                        //   itemBuilder: (_) => const [
                        //     PopupMenuItem(value: 'check_in', child: Text('تسجيل حضور')),
                        //     PopupMenuItem(value: 'check_out', child: Text('تسجيل انصراف')),
                        //   ],
                        // ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _recordEmployeeAttendance(String employeeId, String type) async {
    if (!mounted) return;
    try {
      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': employeeId,
        'type': type,
        'timestamp': Timestamp.now(),
        'recordedBy': _currentEngineerUid,
        'projectId': widget.projectId,
      });
      _showFeedbackSnackBar(context, type == 'check_in' ? 'تم تسجيل الحضور' : 'تم تسجيل الانصراف', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'حدث خطأ أثناء التسجيل', isError: true);
    }
  }

  Future<void> _showAddEmployeeDialog() async {
    if (!mounted || _currentEngineerUid == null) return;
    final employeesSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();
    final employees = employeesSnap.docs;
    if (employees.isEmpty) {
      _showFeedbackSnackBar(context, 'لا يوجد موظفون لإضافتهم', isError: true);
      return;
    }
    String? selectedEmployeeId;
    String? selectedPhaseId;
    String? selectedSubPhaseId;
    List<Map<String, dynamic>> subPhases = [];
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إضافة عامل للمشروع'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'الموظف'),
                    items: employees.map((e) {
                      final data = e.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: e.id,
                        child: Text(data['name'] ?? 'موظف'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedEmployeeId = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'المرحلة'),
                    items: predefinedPhasesStructure.map((phase) {
                      return DropdownMenuItem(
                        value: phase['id'] as String,
                        child: Text(phase['name'] as String),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedPhaseId = val;
                        selectedSubPhaseId = null;
                        subPhases = predefinedPhasesStructure
                            .firstWhere((p) => p['id'] == val)['subPhases']
                            .cast<Map<String, dynamic>>();
                      });
                    },
                  ),
                  if (subPhases.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'المرحلة الفرعية'),
                      items: subPhases.map((sp) {
                        return DropdownMenuItem(
                          value: sp['id'] as String,
                          child: Text(sp['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedSubPhaseId = val),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selectedEmployeeId == null || selectedPhaseId == null
                      ? null
                      : () async {
                          final phaseMap = predefinedPhasesStructure.firstWhere((p) => p['id'] == selectedPhaseId);
                          Map<String, dynamic>? subPhaseMap;
                          if (selectedSubPhaseId != null) {
                            subPhaseMap = phaseMap['subPhases']
                                .firstWhere((sp) => sp['id'] == selectedSubPhaseId);
                          }
                          final employeeDoc = employees.firstWhere((e) => e.id == selectedEmployeeId);
                          final empData = employeeDoc.data() as Map<String, dynamic>;
                          await FirebaseFirestore.instance
                              .collection('projects')
                              .doc(widget.projectId)
                              .collection('employeeAssignments')
                              .add({
                            'employeeId': selectedEmployeeId,
                            'employeeName': empData['name'] ?? 'موظف',
                            'phaseId': selectedPhaseId,
                            'phaseName': phaseMap['name'],
                            if (selectedSubPhaseId != null) ...{
                              'subPhaseId': selectedSubPhaseId,
                              'subPhaseName': subPhaseMap?['name'] ?? '',
                            },
                            'assignedBy': _currentEngineerUid,
                            'assignedAt': Timestamp.now(),
                          });
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildAttachmentsTab() {
    return Column(
      children: [
        // Padding(
        //   padding: const EdgeInsets.all(AppConstants.paddingSmall),
        //   child: Align(
        //     alignment: AlignmentDirectional.centerStart,
        //     child: ElevatedButton.icon(
        //       icon: const Icon(Icons.attach_file, color: Colors.white, size: 18),
        //       label: const Text('إضافة مرفق', style: TextStyle(color: Colors.white)),
        //       onPressed: _showAddAttachmentDialog,
        //       style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
        //     ),
        //   ),
        // ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('attachments')
                .orderBy('uploadedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
              }
              if (snapshot.hasError) {
                return const Center(child: Text('فشل تحميل المرفقات'));
              }
              final files = snapshot.data?.docs ?? [];
              if (files.isEmpty) {
                return const Center(child: Text('لا توجد مرفقات حالياً'));
              }
              return ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final data = files[index].data() as Map<String, dynamic>;
                  final fileName = data['fileName'] ?? 'ملف';
                  final fileUrl = data['fileUrl'] as String?;
                  final uploader = data['uploaderName'] ?? '';
                  return ListTile(
                    leading: const Icon(Icons.attach_file_outlined),
                    title: Text(fileName),
                    subtitle: Text('بواسطة: $uploader'),
                    onTap: fileUrl != null ? () => _handleFileTap(fileUrl) : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImportantNotesTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('importantNotes')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
              }
              if (snapshot.hasError) {
                return const Center(child: Text('فشل تحميل الملاحظات'));
              }
              final notes = snapshot.data?.docs ?? [];
              if (notes.isEmpty) {
                return const Center(child: Text('لا توجد ملاحظات'));
              }
              return ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final data = notes[index].data() as Map<String, dynamic>;
                  final text = data['text'] ?? '';
                  final author = data['authorName'] ?? '';
                  final ts = data['createdAt'] as Timestamp?;
                  final date = ts != null ? DateFormat('yyyy/MM/dd').format(ts.toDate()) : '';
                  return ListTile(
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: Text(text),
                    subtitle: Text('$author - $date'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddAttachmentDialog() async {
    if (!mounted) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFiles =
        result.files.where((f) => f.path != null).toList(growable: false);
    if (pickedFiles.isEmpty) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoading = false;
          Future<void> upload() async {
            setState(() => isLoading = true);
            for (final picked in pickedFiles) {
              final file = File(picked.path!);
              final mimeType =
                  lookupMimeType(picked.path!) ?? 'application/octet-stream';
              try {
                var request = http.MultipartRequest(
                    'POST', Uri.parse(AppConstants.uploadUrl));
                if (kIsWeb) {
                  final bytes = await file.readAsBytes();
                  request.files.add(http.MultipartFile.fromBytes(
                    'image',
                    bytes,
                    filename: picked.name,
                    contentType: MediaType.parse(mimeType),
                  ));
                } else {
                  request.files.add(await http.MultipartFile.fromPath(
                    'image',
                    file.path,
                    contentType: MediaType.parse(mimeType),
                  ));
                }

                var streamedResponse = await request.send();
                var response = await http.Response.fromStream(streamedResponse);

                if (response.statusCode == 200) {
                  var responseData = json.decode(response.body);
                  if (responseData['status'] == 'success' &&
                      responseData['url'] != null) {
                    final url = responseData['url'];
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('attachments')
                        .add({
                      'fileName': picked.name,
                      'fileUrl': url,
                      'uploaderUid': _currentEngineerUid,
                      'uploaderName': _currentEngineerName ?? 'مهندس',
                      'uploadedAt': FieldValue.serverTimestamp(),
                    });
                  } else {
                    throw Exception(
                        responseData['message'] ?? 'فشل رفع المرفق من السيرفر.');
                  }
                } else {
                  throw Exception(
                      'خطأ في الاتصال بالسيرفر: ${response.statusCode}');
                }
              } catch (e) {
                if (mounted) {
                  _showFeedbackSnackBar(context, 'فشل رفع المرفق: $e',
                      isError: true);
                }
              }
            }
            if (mounted) Navigator.pop(dialogContext);
          }

          return AlertDialog(
            title: const Text('تأكيد رفع المرفقات'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    pickedFiles.map((f) => ListTile(title: Text(f.name))).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : upload,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor),
                child:
                    isLoading ? const CircularProgressIndicator() : const Text('رفع'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddImportantNoteDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة ملاحظة هامة'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'الملاحظة'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .collection('importantNotes')
                    .add({
                  'text': controller.text.trim(),
                  'authorUid': _currentEngineerUid,
                  'authorName': _currentEngineerName ?? 'مهندس',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDailyReportDialog() async {
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    DateTime end = start.add(const Duration(days: 1));
    int entriesCount = 0;
    int testsCount = 0;
    int requestsCount = 0;
    try {
      for (var phase in predefinedPhasesStructure) {
        final phaseId = phase['id'];
        final snap = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('phases_status')
            .doc(phaseId)
            .collection('entries')
            .where('timestamp', isGreaterThanOrEqualTo: start)
            .where('timestamp', isLessThan: end)
            .get();
        entriesCount += snap.docs.length;
        for (var sub in phase['subPhases']) {
          final subId = sub['id'];
          final subSnap = await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('subphases_status')
              .doc(subId)
              .collection('entries')
              .where('timestamp', isGreaterThanOrEqualTo: start)
              .where('timestamp', isLessThan: end)
              .get();
          entriesCount += subSnap.docs.length;
        }
      }
      final testsSnap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tests_status')
          .where('lastUpdatedAt', isGreaterThanOrEqualTo: start)
          .where('lastUpdatedAt', isLessThan: end)
          .get();
      testsCount = testsSnap.docs.length;
      final reqSnap = await FirebaseFirestore.instance
          .collection('partRequests')
          .where('projectId', isEqualTo: widget.projectId)
          .where('requestedAt', isGreaterThanOrEqualTo: start)
          .where('requestedAt', isLessThan: end)
          .get();
      requestsCount = reqSnap.docs.length;
    } catch (e) {
      // ignore errors
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تقرير اليوم'),
          content: Text('عدد الملاحظات المسجلة اليوم: $entriesCount\n'
              'عدد الاختبارات المحدثة اليوم: $testsCount\n'
              'عدد طلبات المواد اليوم: $requestsCount'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );
  }

  Future<void> _selectReportDate() async {
    final now = DateTime.now();
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: SimpleDialog(
          title: const Text('نوع التقرير'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                final start = DateTime(now.year, now.month, now.day);
                _generateDailyReportPdf(start: start, end: start.add(const Duration(days: 1)));
              },
              child: const Text('تقرير اليوم'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                _generateDailyReportPdf();
              },
              child: const Text('تقرير شامل'),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                final DateTimeRange? range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppConstants.primaryColor,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  final start = DateTime(range.start.year, range.start.month, range.start.day);
                  final end = DateTime(range.end.year, range.end.month, range.end.day);
                  _generateDailyReportPdf(start: start, end: end.add(const Duration(days: 1)));
                }
              },
              child: const Text('تقرير فترة محددة'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Function to load Arabic font ---
  Future<void> _loadArabicFont() async {
    try {
      // IMPORTANT: Replace 'NotoSansArabic-Regular.ttf' with the actual filename of your font asset
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      print("Error loading Arabic font: $e");
      // Handle error, maybe use a default font or show a warning
      // For PDF generation to work correctly with Arabic, this font is crucial.
      // If it fails, PDF might use a default font that doesn't support Arabic well.
    }
  }


  Future<void> _generateDailyReportPdf({DateTime? start, DateTime? end}) async {
    DateTime now = DateTime.now();
    final bool isFullReport = start == null && end == null;
    bool useRange = !isFullReport;
    if (useRange) {
      start ??= DateTime(now.year, now.month, now.day);
      end ??= start.add(const Duration(days: 1));
    }

    final bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String getLocalizedText(String ar, String en) => isArabic ? ar : en;

    final progress = ProgressDialog.show(
        context, getLocalizedText('جاري إنشاء التقرير...', 'Generating Report...'));

    final fileName = 'daily_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    try {
      PdfReportResult result;
      try {
        result = await PdfReportGenerator.generateWithIsolate(
          projectId: widget.projectId,
          projectData: _projectDataSnapshot?.data() as Map<String, dynamic>?,
          phases: predefinedPhasesStructure,
          testsStructure: finalCommissioningTests,
          generatedBy: _currentEngineerName,
          start: start,
          end: end,
          onProgress: (p) => progress.value = p,
        );
      } catch (e) {
        // Retry with low-memory settings if initial attempt fails.
        result = await PdfReportGenerator.generateWithIsolate(
          projectId: widget.projectId,
          projectData: _projectDataSnapshot?.data() as Map<String, dynamic>?,
          phases: predefinedPhasesStructure,
          testsStructure: finalCommissioningTests,
          generatedBy: _currentEngineerName,
          start: start,
          end: end,
          onProgress: (p) => progress.value = p,
          lowMemory: true,
        );
      }

      await ProgressDialog.hide(context);
      _showFeedbackSnackBar(context, getLocalizedText('تم إنشاء التقرير بنجاح.', 'Report generated successfully.'), isError: false);
      _openPdfPreview(
        result.bytes,
        fileName,
        getLocalizedText('يرجى الإطلاع على التقرير للمشروع.', 'Please review the project report.'),
        result.downloadUrl,
      );
    } catch (e) {
      try {
        progress.value = 0.0;
        final bytes = await PdfReportGenerator.generateSimpleTables(
          projectId: widget.projectId,
          phases: predefinedPhasesStructure,
          testsStructure: finalCommissioningTests,
          start: start,
          end: end,
          onProgress: (p) => progress.value = p,
          lowMemory: true,
        );
        await ProgressDialog.hide(context);
        _showFeedbackSnackBar(
          context,
          getLocalizedText('تم إنشاء تقرير مبسط بسبب نقص الذاكرة.', 'Generated simplified report due to low memory.'),
          isError: false,
        );
        _openPdfPreview(
          bytes,
          fileName,
          getLocalizedText('يرجى الإطلاع على التقرير للمشروع.', 'Please review the project report.'),
          null,
        );
      } catch (e2) {
        await ProgressDialog.hide(context);
        _showFeedbackSnackBar(context, getLocalizedText('فشل إنشاء أو مشاركة التقرير: $e2', 'Failed to generate or share report: $e2'), isError: true);
        print('Error generating daily report PDF: $e2');
      }
    }
  }

// --- Helper Widgets (modified to accept isArabic and getLocalizedText) ---

  pw.Widget _buildSummaryCard(int entriesCount, int testsCount, int requestsCount, pw.TextStyle headerStyle, pw.TextStyle regularStyle, PdfColor primaryColor, PdfColor lightGrey, {required bool isArabic, required String Function(String, String) getLocalizedText}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: primaryColor, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(getLocalizedText('ملخص التقرير', 'Report Summary'), style: headerStyle),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(getLocalizedText('الملاحظات', 'Notes'), entriesCount.toString(), regularStyle, primaryColor, isArabic: isArabic, getLocalizedText: getLocalizedText),
              _buildSummaryItem(getLocalizedText('الاختبارات', 'Tests'), testsCount.toString(), regularStyle, primaryColor, isArabic: isArabic, getLocalizedText: getLocalizedText),
              _buildSummaryItem(getLocalizedText('طلبات المواد', 'Material Requests'), requestsCount.toString(), regularStyle, primaryColor, isArabic: isArabic, getLocalizedText: getLocalizedText),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value, pw.TextStyle regularStyle, PdfColor primaryColor, {required bool isArabic, required String Function(String, String) getLocalizedText}) {
    return pw.Column(
      children: [
        pw.Container(
          width: 40,
          height: 40,
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Center(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: _arabicFont,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                fontFallback: regularStyle.fontFallback, // Use the same fallback as regularStyle
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(label, style: regularStyle),
      ],
    );
  }

  pw.Widget _buildSectionHeader(String title, pw.TextStyle headerStyle, PdfColor primaryColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: _arabicFont,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 16,
          fontFallback: headerStyle.fontFallback, // Ensure font fallback
        ),
      ),
    );
  }

  pw.Widget _buildEmptyState(String message, pw.TextStyle regularStyle, PdfColor lightGrey) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(message, style: regularStyle),
      ),
    );
  }

  pw.Widget _buildEntryCard(Map<String, dynamic> entry, Map<String, pw.MemoryImage> fetchedImages, int index, pw.TextStyle subHeaderStyle, pw.TextStyle regularStyle, pw.TextStyle labelStyle, pw.TextStyle metaStyle, PdfColor borderColor, PdfColor lightGrey, {required bool isArabic, required String Function(String, String) getLocalizedText}) {
    final note = entry['note'] ?? '';
    final engineer = entry['employeeName'] ?? entry['engineerName'] ?? getLocalizedText('مهندس', 'Engineer');
    final ts = (entry['timestamp'] as Timestamp?)?.toDate();
    final dateStr = ts != null ? DateFormat(getLocalizedText('dd/MM/yy HH:mm', 'MM/dd/yy HH:mm'), isArabic ? 'ar' : 'en').format(ts) : '';
    final phaseName = entry['phaseName'] ?? '';
    final subName = entry['subPhaseName'];
    final imageUrls = (entry['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(15),
                ),
                child: pw.Text('#$index', style: metaStyle),
              ),
              pw.Expanded(
                child: pw.Text(
                  subName != null
                      ? (isArabic ? '$phaseName > $subName' : '$phaseName > $subName') // Phase and sub-phase names might already be localized
                      : phaseName,
                  style: subHeaderStyle,
                  textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          // Using pw.Table for textual details
          pw.Table.fromTextArray(
            border: null, // No border for inner table
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            cellAlignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            headerDecoration: null,
            rowDecoration: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(), // Value column
              1: const pw.FixedColumnWidth(80), // Label column
            },
            headers: [], // No headers for this internal table
            data: <List<String>>[
              <String>[engineer, getLocalizedText('المهندس:', 'Engineer:')],
              <String>[dateStr, getLocalizedText('التاريخ:', 'Date:')],
              if (note.toString().isNotEmpty)
                <String>[note.toString(), getLocalizedText('الملاحظة:', 'Note:')],
            ],
            cellStyle: regularStyle,
            headerStyle: labelStyle, // Use labelStyle for cell labels (second column)
            defaultColumnWidth: const pw.IntrinsicColumnWidth(),
            tableWidth: pw.TableWidth.min, // Adjust table width based on content
          ),
          if (imageUrls.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(getLocalizedText('الصور المرفقة', 'Attached Images:'), style: labelStyle),
            pw.SizedBox(height: 5),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: imageUrls.where((url) => fetchedImages.containsKey(url)).map((url) =>
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.ClipRRect(
                      child: pw.Image(
                        fetchedImages[url]!,
                        width: 120,
                        height: 80,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildTestCard(Map<String, dynamic> test, Map<String, pw.MemoryImage> fetchedImages, int index, pw.TextStyle subHeaderStyle, pw.TextStyle regularStyle, pw.TextStyle labelStyle, pw.TextStyle metaStyle, PdfColor borderColor, PdfColor lightGrey, {required bool isArabic, required String Function(String, String) getLocalizedText}) {
    final note = test['note'] ?? '';
    final engineer = test['lastUpdatedByName'] ?? getLocalizedText('مهندس', 'Engineer');
    final ts = (test['lastUpdatedAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null ? DateFormat(getLocalizedText('dd/MM/yy HH:mm', 'MM/dd/yy HH:mm'), isArabic ? 'ar' : 'en').format(ts) : '';
    final section = test['sectionName'] ?? '';
    final name = test['testName'] ?? '';
    final imageUrl = test['imageUrl'];

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(15),
                ),
                child: pw.Text('#$index', style: metaStyle),
              ),
              pw.Expanded(
                child: pw.Text(
                  (isArabic ? '$section - $name' : '$section - $name'), // Section and test names might already be localized
                  style: subHeaderStyle,
                  textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          // Using pw.Table for textual details
          pw.Table.fromTextArray(
            border: null, // No border for inner table
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            cellAlignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            headerDecoration: null,
            rowDecoration: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(), // Value column
              1: const pw.FixedColumnWidth(80), // Label column
            },
            headers: [], // No headers for this internal table
            data: <List<String>>[
              <String>[engineer, getLocalizedText('المهندس:', 'Engineer:')],
              <String>[dateStr, getLocalizedText('التاريخ:', 'Date:')],
              if (note.toString().isNotEmpty)
                <String>[note.toString(), getLocalizedText('الملاحظات:', 'Notes:')],
            ],
            cellStyle: regularStyle,
            headerStyle: labelStyle, // Use labelStyle for cell labels (second column)
            defaultColumnWidth: const pw.IntrinsicColumnWidth(),
            tableWidth: pw.TableWidth.min, // Adjust table width based on content
          ),
          if (imageUrl != null && fetchedImages.containsKey(imageUrl)) ...[
            pw.SizedBox(height: 10),
            pw.Text(getLocalizedText('الصورة المرفقة:', 'Attached Image:'), style: labelStyle),
            pw.SizedBox(height: 5),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.ClipRRect(
                child: pw.Image(
                  fetchedImages[imageUrl]!,
                  width: 150,
                  height: 100,
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildRequestsTable(List<Map<String, dynamic>> requests, pw.TextStyle regularStyle, pw.TextStyle labelStyle, PdfColor borderColor, PdfColor lightGrey, {required bool isArabic, required String Function(String, String) getLocalizedText}) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: lightGrey),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(getLocalizedText('التاريخ', 'Date'), style: labelStyle, textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(getLocalizedText('المهندس', 'Engineer'), style: labelStyle, textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(getLocalizedText('الحالة', 'Status'), style: labelStyle, textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(getLocalizedText('الكمية', 'Quantity'), style: labelStyle, textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(getLocalizedText('اسم المادة', 'Item Name'), style: labelStyle, textAlign: pw.TextAlign.center),
            ),
          ],
        ),
        ...requests.map((pr) {
          final List<dynamic>? items = pr['items'];
          String name;
          String qty;
          if (items != null && items.isNotEmpty) {
            name = items.map((e) => '${e['name']} (${e['quantity']})').join(getLocalizedText('، ', ', '));
            qty = '-';
          } else {
            name = pr['partName'] ?? '';
            qty = pr['quantity']?.toString() ?? '1';
          }
          final status = pr['status'] ?? '';
          final eng = pr['engineerName'] ?? '';
          final ts = (pr['requestedAt'] as Timestamp?)?.toDate();
          final dateStr = ts != null ? DateFormat(getLocalizedText('dd/MM/yy', 'MM/dd/yy'), isArabic ? 'ar' : 'en').format(ts) : '';

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(dateStr, style: regularStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(eng, style: regularStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(status, style: regularStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(qty, style: regularStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(name, style: regularStyle, textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

// _buildPartSummaryTable is not called in the main _generateDailyReportPdf logic, so it's kept as is (no localization parameters added for it).
  pw.Widget _buildPartSummaryTable(List<Map<String, dynamic>> requests, pw.Font font) {
    final Map<String, int> qtyTotals = {};
    final Map<String, String> statusMap = {};
    for (var pr in requests) {
      final status = pr['status']?.toString() ?? '';
      final List<dynamic>? items = pr['items'] as List<dynamic>?;
      if (items != null && items.isNotEmpty) {
        for (var item in items) {
          final name = item['name']?.toString() ?? '';
          final qty = int.tryParse(item['quantity'].toString()) ?? 0;
          qtyTotals[name] = (qtyTotals[name] ?? 0) + qty;
          statusMap[name] = status;
        }
      } else {
        final name = pr['partName']?.toString() ?? '';
        final qty = int.tryParse(pr['quantity'].toString()) ?? 0;
        qtyTotals[name] = (qtyTotals[name] ?? 0) + qty;
        statusMap[name] = status;
      }
    }

    final data = qtyTotals.entries
        .map((e) => [e.key, e.value.toString(), statusMap[e.key] ?? ''])
        .toList();

    return PdfStyles.buildTable(
      font: font,
      headers: ['اسم القطعة', 'الكمية الإجمالية', 'الحالة'],
      data: data,
      isRtl: true,
    );
  }

  pw.Widget _buildImportantNotice(pw.TextStyle regularStyle, {required bool isArabic, required String Function(String, String) getLocalizedText}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF3E0'),
        border: pw.Border.all(color: PdfColor.fromHex('#FF9800'), width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              getLocalizedText('ملاحظة هامة: في حال مضى 24 ساعة يعتبر هذا التقرير مكتمل وغير قابل للتعديل.', 'Important Note: This report will be considered complete and uneditable after 24 hours.'),
              style: pw.TextStyle(
                font: _arabicFont,
                color: PdfColor.fromHex('#E65100'),
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                fontFallback: regularStyle.fontFallback, // Ensure font fallback
              ),
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Container(
            width: 30,
            height: 30,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FF9800'),
              borderRadius: pw.BorderRadius.circular(15),
            ),
            child: pw.Center(
              child: pw.Text(
                '!',
                style: pw.TextStyle(
                  font: _arabicFont, // Use Arabic font for '!' as it's a character often included in Arabic font sets, or a common fallback.
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  fontFallback: regularStyle.fontFallback, // Ensure font fallback
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _fetchInitialData() async {
    // ... (no changes in this function)
    if (!mounted) return;
    setState(() => _isPageLoading = true);
    await _fetchCurrentEngineerData();
    await _fetchProjectData();
    if (mounted) {
      setState(() => _isPageLoading = false);
    }
  }

  Future<void> _fetchCurrentEngineerData() async {
    // ... (no changes in this function)
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
    // ... (no changes in this function)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      if (mounted && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        String? phone;
        final clientId = data?['clientId'] as String?;
        if (clientId != null && clientId.isNotEmpty) {
          try {
            final clientDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(clientId)
                .get();
            phone = (clientDoc.data() as Map<String, dynamic>?)?['phone'] as String?;
          } catch (_) {}
        }
        setState(() {
          _projectDataSnapshot = doc;
          _clientPhone = phone;
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
    // ... (no changes in this function)
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

  bool _isCurrentEngineerResponsible() {
    if (_projectDataSnapshot == null || _currentEngineerUid == null) return false;
    final data = _projectDataSnapshot!.data() as Map<String, dynamic>?;
    if (data == null) return false;
    final List<dynamic> uidsDynamic = data['engineerUids'] as List<dynamic>? ?? [];
    final List<String> uids = uidsDynamic.map((e) => e.toString()).toList();
    return uids.contains(_currentEngineerUid);
  }

  // --- Helper for loading dialog ---
  void _showLoadingDialog(BuildContext context, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppConstants.primaryColor),
              const SizedBox(width: 20),
              Text(message, style: const TextStyle(fontFamily: 'NotoSansArabic')), // Example of using the font family name
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

  void _scrollToHighlighted() {
    GlobalKey? key;
    if (_highlightSubPhaseId != null) {
      key = _subPhaseKeys[_highlightSubPhaseId];
    } else if (_highlightPhaseId != null) {
      key = _phaseKeys[_highlightPhaseId];
    } else if (_highlightTestId != null) {
      key = _testKeys[_highlightTestId];
    }
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
      );
    }
  }


  PreferredSizeWidget _buildAppBar() {
    // ... (no changes in this function)
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
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          tooltip: 'تقرير اليوم',
          onPressed: _selectReportDate,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'تفاصيل', icon: Icon(Icons.info_outline_rounded)),
          Tab(text: 'مراحل المشروع', icon: Icon(Icons.list_alt_rounded)),
          Tab(text: 'اختبارات التشغيل', icon: Icon(Icons.checklist_rtl_rounded)),
          Tab(text: 'طلبات المواد', icon: Icon(Icons.build_circle_outlined)),
          Tab(text: 'عمال المشروع', icon: Icon(Icons.group)),
          Tab(text: 'مرفقات', icon: Icon(Icons.attach_file_outlined)),
          Tab(text: 'ملاحظات هامة', icon: Icon(Icons.notes)),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard(Map<String, dynamic> projectDataMap) {
    // ... (no changes in this function)
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
      // If the global shadow list is empty we default to no elevation to avoid
      // hitting a RangeError when accessing the first element.
      elevation: AppConstants.cardShadow.isNotEmpty
          ? AppConstants.cardShadow[0].blurRadius
          : 0,
      shadowColor: AppConstants.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium, left:AppConstants.paddingSmall, right: AppConstants.paddingSmall, top:AppConstants.paddingSmall ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.engineering_rounded, 'المهندسون:', engineersDisplay),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('employeeAssignments')
                  .snapshots(),
              builder: (context, snapshot) {
                String employeesDisplay = 'لا يوجد';
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  employeesDisplay = snapshot.data!.docs
                      .map((e) => (e.data() as Map<String, dynamic>)['employeeName'] ?? '')
                      .toSet()
                      .join('، ');
                }
                return _buildDetailRow(Icons.badge_rounded, 'الموظفون:', employeesDisplay);
              },
            ),
            _buildDetailRow(Icons.person_rounded, 'العميل:', clientName),
            if (_clientPhone != null && _clientPhone!.isNotEmpty)
              _buildPhoneRow(_clientPhone!),
            _buildDetailRow(statusIcon, 'حالة المشروع:', projectStatus, valueColor: statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    // ... (no changes in this function)
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

  Widget _buildPhoneRow(String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.5),
      child: Row(
        children: [
          const Icon(Icons.phone, size: 18, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Text(phone,
                style: const TextStyle(fontSize: 14, color: AppConstants.textPrimary, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: AppConstants.primaryColor, size: 20),
            onPressed: () async {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.green, size: 20),
            onPressed: () async {
              var normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
              if (normalized.startsWith('0')) {
                normalized = '966${normalized.substring(1)}';
              }
              final uri = Uri.parse('https://wa.me/$normalized');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> projectDataMap) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: _buildProjectSummaryCard(projectDataMap),
    );
  }

  Widget _buildPhasesTab() {
    // ... (no changes to the structure of this function, only the onPressed for PDF button calls the new _generateAndSharePdf)
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للمراحل."));
    }
    return ListView.builder(
      controller: _scrollController,
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
              bool canGeneratePdfForMainPhase =
                  isMainPhaseCompletedByAnyEngineer && _isCurrentEngineerResponsible();

              Widget? trailingWidget;
              if (canEngineerEditThisPhase) {
                trailingWidget = IconButton(
                  icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                  tooltip: 'إضافة ملاحظة/صورة للمرحلة الرئيسية',
                  onPressed: () => _showAddNoteOrImageDialog(phaseId, phaseName),
                );
              } else if (canGeneratePdfForMainPhase) {
                trailingWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                      tooltip: 'إنشاء ومشاركة تقرير PDF للمرحلة الرئيسية',
                      onPressed: () {
                        _generateAndSharePdf(phaseId, phaseName, isTestSection: false, isSubPhase: false);
                      },
                    ),
                  ],
                );
              } else if (isMainPhaseCompletedByAnyEngineer) {
                trailingWidget = IconButton(
                  icon: Icon(Icons.picture_as_pdf_outlined, color: Colors.grey[400]),
                  tooltip: 'أكملها مهندس آخر',
                  onPressed: null,
                );
              }


              return Card(
                key: _phaseKeys.putIfAbsent(phaseId, () => GlobalKey()),
                color: phaseId == _highlightPhaseId ? AppConstants.highlightColor : null,
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                child: ExpansionTile(
                  initiallyExpanded: phaseId == _highlightPhaseId ||
                      subPhasesStructure.any((sp) => sp['id'] == _highlightSubPhaseId),
                  leading: CircleAvatar(
                    backgroundColor: isMainPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.primaryColor,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phaseName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary, decoration: null)),                  subtitle: Text(isMainPhaseCompletedByAnyEngineer ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: isMainPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
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
                                  Widget? subPhaseTrailingWidget;
                                  if (canEngineerEditThisSubPhase) {
                                    subPhaseTrailingWidget = Checkbox(
                                      value: isSubPhaseCompletedByAnyEngineer,
                                      activeColor: AppConstants.successColor,
                                      onChanged: (value) {
                                        _updateSubPhaseCompletionStatus(phaseId, subPhaseId, subPhaseName, value ?? false);
                                      },
                                    );
                                  }


                                  return ListTile(
                                    key: _subPhaseKeys.putIfAbsent(subPhaseId, () => GlobalKey()),
                                    dense: true,
                                    tileColor: subPhaseId == _highlightSubPhaseId ? AppConstants.highlightColor : null,
                                    leading: Icon(
                                      isSubPhaseCompletedByAnyEngineer ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: isSubPhaseCompletedByAnyEngineer ? AppConstants.successColor : AppConstants.textSecondary,
                                    ),
                                    title: Text(subPhaseName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: null)),                                    trailing: subPhaseTrailingWidget,
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
    // ... (no changes to the structure of this function, only the onPressed for PDF button calls the new _generateAndSharePdf)
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للاختبارات."));
    }
    return ListView.builder(
      controller: _scrollController,
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
                    String? engineerNameOnTestCompletion; // Renamed for clarity
                    String? testCompletedByUid;

                    if (testStatusSnapshot.hasData && testStatusSnapshot.data!.exists) {
                      final statusData = testStatusSnapshot.data!.data() as Map<String, dynamic>;
                      isTestCompleted = statusData['completed'] ?? false;
                      testNote = statusData['note'] ?? '';
                      testImageUrl = statusData['imageUrl'] as String?;
                      engineerNameOnTestCompletion = statusData['lastUpdatedByName'] as String?; // Use lastUpdatedByName
                      testCompletedByUid = statusData['lastUpdatedByUid'] as String?;
                    }
                    bool canEngineerEditThisTest = !isTestCompleted;
                    bool canGeneratePdfForTest =
                        isTestCompleted && _isCurrentEngineerResponsible();

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
                      trailingWidget = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.teal),
                            tooltip: 'إنشاء ومشاركة تقرير PDF للاختبار',
                            onPressed: () {
                              _generateAndSharePdf(
                                  testId,
                                  testName,
                                  isTestSection: true,
                                  sectionName: sectionName,
                                  testNote: testNote,
                                  testImageUrl: testImageUrl,
                                  engineerNameOnTest: engineerNameOnTestCompletion ?? _currentEngineerName
                              );
                            },
                          ),
                        ],
                      );
                    } else if (isTestCompleted) {
                      trailingWidget = Icon(Icons.picture_as_pdf_outlined, color: Colors.grey[400]);
                    }

                    return ListTile(
                      key: _testKeys.putIfAbsent(testId, () => GlobalKey()),
                      tileColor: testId == _highlightTestId ? AppConstants.highlightColor : null,
                      title: Text(testName, style: TextStyle(fontSize: 14, color: AppConstants.textSecondary, decoration: null)),
                      leading: Icon(
                        isTestCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isTestCompleted ? AppConstants.successColor : AppConstants.textSecondary,
                        size: 20,
                      ),
                      trailing: trailingWidget,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (engineerNameOnTestCompletion != null && engineerNameOnTestCompletion.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("أكمل بواسطة: $engineerNameOnTestCompletion", style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic)),
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

  Widget _buildMaterialRequestsTab() {
    if (_currentEngineerUid == null) {
      return const Center(child: Text('لا يمكن تحميل طلبات المواد.'));
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentEngineerUid != null && _currentEngineerName != null) {
            Navigator.pushNamed(
              context,
              '/engineer/request_material',
              arguments: {
                'engineerId': _currentEngineerUid,
                'engineerName': _currentEngineerName,
                'projectId': widget.projectId,
                'projectName': (_projectDataSnapshot?.data() as Map<String, dynamic>?)?['name'],
              },
            );
          } else {
            _showFeedbackSnackBar(context, 'بيانات المهندس غير متوفرة.', isError: true);
          }
        },
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('partRequests')
            .where('projectId', isEqualTo: widget.projectId)
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('فشل تحميل طلبات المواد'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات مواد حالياً'));
          }

          final requests = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestDoc = requests[index];
              final data = requestDoc.data() as Map<String, dynamic>;
              final List<dynamic>? itemsData = data['items'];
              String partName;
              String quantity;
              if (itemsData != null && itemsData.isNotEmpty) {
                partName = itemsData.map((e) => '${e['name']} (${e['quantity']})').join('، ');
                quantity = '-';
              } else {
                partName = data['partName'] ?? 'مادة غير مسماة';
                quantity = data['quantity']?.toString() ?? 'N/A';
              }
              final status = data['status'] ?? 'غير معروف';
              final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
              final formattedDate = requestedAt != null
                  ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(requestedAt)
                  : 'غير معروف';

              Color statusColor;
              switch (status) {
                case 'معلق':
                  statusColor = AppConstants.warningColor;
                  break;
                case 'تمت الموافقة':
                  statusColor = AppConstants.successColor;
                  break;
                case 'مرفوض':
                  statusColor = AppConstants.errorColor;
                  break;
                case 'تم الطلب':
                  statusColor = AppConstants.infoColor;
                  break;
                case 'تم الاستلام':
                  statusColor = AppConstants.primaryColor;
                  break;
                default:
                  statusColor = AppConstants.textSecondary;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                child: ListTile(
                  title: Text('اسم المادة: $partName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text('الكمية: $quantity',
                      //     style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                      Row(
                        children: [
                          Icon(Icons.circle, color: statusColor, size: 10),
                          const SizedBox(width: 4),
                          Text(status, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Text('تاريخ الطلب: $formattedDate',
                          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary.withOpacity(0.8))),
                    ],
                  ),
                  onTap: () => _showPartRequestDetailsDialog(requestDoc),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (no changes in this function)
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  if (_projectDataSnapshot != null && _projectDataSnapshot!.exists)
                    _buildDetailsTab(_projectDataSnapshot!.data() as Map<String, dynamic>)
                  else
                    const SizedBox.shrink(),
                  _buildPhasesTab(),
                  _buildTestsTab(),
                  _buildMaterialRequestsTab(),
                  _buildEmployeesTab(),
                  _buildAttachmentsTab(),
                  _buildImportantNotesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePhaseCompletionStatus(String phaseId, String phaseName, bool newStatus) async {
    // ... (no changes in this function)
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
      }, SetOptions(merge: true));

      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة "$phaseName".', isError: false);
      // ... (notifications code)
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة: $e', isError: true);
    }
  }


  Future<void> _updateSubPhaseCompletionStatus(String mainPhaseId, String subPhaseId, String subPhaseName, bool newStatus) async {
    // ... (no changes in this function)
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

      // ... (notifications code)
      if (newStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) {
        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
        if (projectData == null) return;

        final projectNameVal = projectData['name'] ?? 'المشروع';
        final clientUid = projectData['clientId'] as String?;
        final List<String> adminUids = await getAdminUids();

        if (adminUids.isNotEmpty) {
          await sendNotificationsToMultiple(
            recipientUserIds: adminUids,
            title: 'تحديث مرحلة مشروع: $projectNameVal',
            body: 'قام المهندس ${_currentEngineerName ?? 'غير معروف'} بإكمال المرحلة الفرعية "$subPhaseName" في مشروع "$projectNameVal".',
            type: 'subphase_completed_by_engineer',
            projectId: widget.projectId,
            itemId: subPhaseId,
            senderName: _currentEngineerName,
          );
        }

        if (clientUid != null && clientUid.isNotEmpty) {
          await sendNotification(
            recipientUserId: clientUid,
            title: '🎉 مبروك! تحديث جديد في مشروعك: $projectNameVal',
            body: 'المهندس ${_currentEngineerName ?? 'فريق العمل'} قام بإكمال المرحلة الفرعية "$subPhaseName" في مشروعك. تبقى القليل والعمل مستمر على قدم وساق!',
            type: 'subphase_completed_for_client',
            projectId: widget.projectId,
            itemId: subPhaseId,
            senderName: _currentEngineerName,
          );
        }
      }

    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة الفرعية: $e', isError: true);
    }
  }

  Future<void> _showUpdateTestStatusDialog(String testId, String testName, bool initialStatus, {String? currentNote, String? currentImageUrl}) async {
    bool newStatus = initialStatus;
    final noteController = TextEditingController(text: currentNote ?? "");
    String? tempImageUrl = currentImageUrl;
    XFile? pickedImageXFile;
    bool isDialogLoading = false;

    String engineerNameForTest = _currentEngineerName ?? "مهندس";
    final empSnap = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('employeeAssignments')
        .get();
    final testEmployees = empSnap.docs;
    String? selectedTestEmployeeId;
    String? selectedTestEmployeeName;

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
                    if (testEmployees.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'الموظف'),
                        items: testEmployees.map((e) {
                          final data = e.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: data['employeeId'] as String? ?? '',
                            child: Text(data['employeeName'] as String? ?? 'موظف'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedTestEmployeeId = val;
                            final match = testEmployees.firstWhere((d) => (d.data() as Map<String,dynamic>)['employeeId'] == val);
                            selectedTestEmployeeName = (match.data() as Map<String,dynamic>)['employeeName'] as String? ?? 'موظف';
                          });
                        },
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'اختر الموظف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                    ],
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
                        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
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
                        var request = http.MultipartRequest('POST', Uri.parse(AppConstants.uploadUrl));
                        if (kIsWeb) {
                          // Read bytes for web
                          final bytes = await pickedImageXFile!.readAsBytes();
                          request.files.add(http.MultipartFile.fromBytes(
                            'image', // Field name on your PHP server
                            bytes,
                            filename: pickedImageXFile!.name,
                            contentType: MediaType.parse(pickedImageXFile!.mimeType ?? 'image/jpeg'),
                          ));
                        } else {
                          // Use fromPath for mobile (iOS/Android)
                          request.files.add(await http.MultipartFile.fromPath(
                            'image', // Field name on your PHP server
                            pickedImageXFile!.path,
                            contentType: MediaType.parse(pickedImageXFile!.mimeType ?? 'image/jpeg'),
                          ));
                        }

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

                    // ... (rest of the try-catch block for Firestore update)
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
                        'lastUpdatedByUid': _currentEngineerUid,
                        'lastUpdatedByName': selectedTestEmployeeName ?? engineerNameForTest,
                        'lastUpdatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      // ... (notifications code)
                      if (_projectDataSnapshot != null && _projectDataSnapshot!.exists) {
                        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
                        if (projectData == null) return;

                        final projectNameVal = projectData['name'] ?? 'المشروع';
                        final clientUid = projectData['clientId'] as String?;
                        final List<String> adminUids = await getAdminUids();

                        if (newStatus && adminUids.isNotEmpty) {
                          await sendNotificationsToMultiple(
                            recipientUserIds: adminUids,
                            title: 'تحديث اختبار مشروع: $projectNameVal',
                            body: 'قام الموظف ${selectedTestEmployeeName ?? engineerNameForTest} بإكمال الاختبار "$testName" في مشروع "$projectNameVal".',
                            type: 'test_completed_by_engineer',
                            projectId: widget.projectId,
                            itemId: testId,
                            senderName: selectedTestEmployeeName ?? engineerNameForTest,
                          );
                        } else if (!newStatus && adminUids.isNotEmpty) {
                          await sendNotificationsToMultiple(
                            recipientUserIds: adminUids,
                            title: 'تراجع عن اكتمال اختبار: $projectNameVal',
                            body: 'قام الموظف ${selectedTestEmployeeName ?? engineerNameForTest} بتغيير حالة الاختبار "$testName" في مشروع "$projectNameVal" إلى "قيد التنفيذ".',
                            type: 'test_reverted_by_engineer',
                            projectId: widget.projectId,
                            itemId: testId,
                            senderName: selectedTestEmployeeName ?? engineerNameForTest,
                          );
                        }


                        if (clientUid != null && clientUid.isNotEmpty) {
                          if (newStatus) {
                            await sendNotification(
                              recipientUserId: clientUid,
                              title: '🌟 إنجاز جديد في مشروعك: $projectNameVal',
                              body: 'الموظف ${selectedTestEmployeeName ?? engineerNameForTest} قام بإكمال اختبار "$testName" الهام في مشروعك. خطوة أخرى نحو الإنجاز!',
                              type: 'test_completed_for_client',
                              projectId: widget.projectId,
                              itemId: testId,
                              senderName: selectedTestEmployeeName ?? engineerNameForTest,
                            );
                          } else {
                            await sendNotification(
                              recipientUserId: clientUid,
                              title: '⚠ تحديث في مشروعك: $projectNameVal',
                              body: 'تم إعادة فتح اختبار "$testName" في مشروعك للمراجعة أو التعديل.',
                              type: 'test_reverted_for_client',
                              projectId: widget.projectId,
                              itemId: testId,
                              senderName: selectedTestEmployeeName ?? engineerNameForTest,
                            );
                          }
                        }
                      }

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
    // ... (no changes in this function)
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

  // lib/pages/engineer/project_details_page.dart

// ... (existing code)

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

    Query employeeQuery = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('employeeAssignments')
        .where('phaseId', isEqualTo: phaseId);
    if (subPhaseId != null) {
      employeeQuery = employeeQuery.where('subPhaseId', isEqualTo: subPhaseId);
    }
    final employeesSnap = await employeeQuery.get();
    final employees = employeesSnap.docs;
    String? selectedEmployeeId;
    String? selectedEmployeeName;

    List<XFile>? _selectedBeforeImages;
    List<XFile>? _selectedAfterImages;
    List<XFile>? _selectedOtherImages;

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
                      if (employees.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'الموظف'),
                          items: employees.map((e) {
                            final data = e.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: data['employeeId'] as String? ?? '',
                              child: Text(data['employeeName'] as String? ?? 'موظف'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogContentState(() {
                              selectedEmployeeId = val;
                              final match = employees.firstWhere((d) => (d.data() as Map<String,dynamic>)['employeeId'] == val);
                              selectedEmployeeName = (match.data() as Map<String, dynamic>)['employeeName'] as String? ?? 'موظف';
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'اختر الموظف المسؤول';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                      ],
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
                          if ((value == null || value.isEmpty) &&
                              (_selectedBeforeImages == null || _selectedBeforeImages!.isEmpty) &&
                              (_selectedAfterImages == null || _selectedAfterImages!.isEmpty) &&
                              (_selectedOtherImages == null || _selectedOtherImages!.isEmpty)) {
                            return 'الرجاء إدخال ملاحظة أو إضافة صورة واحدة على الأقل.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (_selectedBeforeImages != null && _selectedBeforeImages!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _selectedBeforeImages!.map((xFile) {
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
                                          _selectedBeforeImages!.remove(xFile);
                                          if (_selectedBeforeImages!.isEmpty) {
                                            _selectedBeforeImages = null;
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
                            (_selectedBeforeImages == null || _selectedBeforeImages!.isEmpty)
                                ? 'إضافة صور قبل (اختياري)'
                                : 'تغيير/إضافة المزيد من صور قبل',
                            style: const TextStyle(color: AppConstants.primaryColor)
                        ),
                        onPressed: () {
                          _showImageSourceActionSheet(context, (List<XFile>? images) {
                            if (images != null && images.isNotEmpty) {
                              setDialogContentState(() {
                                if (_selectedBeforeImages == null) {
                                  _selectedBeforeImages = [];
                                }
                                _selectedBeforeImages!.addAll(images);
                              });
                            }
                          });
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (_selectedAfterImages != null && _selectedAfterImages!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _selectedAfterImages!.map((xFile) {
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
                                          _selectedAfterImages!.remove(xFile);
                                          if (_selectedAfterImages!.isEmpty) {
                                            _selectedAfterImages = null;
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
                            (_selectedAfterImages == null || _selectedAfterImages!.isEmpty)
                                ? 'إضافة صور بعد (اختياري)'
                                : 'تغيير/إضافة المزيد من صور بعد',
                            style: const TextStyle(color: AppConstants.primaryColor)
                        ),
                        onPressed: () {
                          _showImageSourceActionSheet(context, (List<XFile>? images) {
                            if (images != null && images.isNotEmpty) {
                              setDialogContentState(() {
                                if (_selectedAfterImages == null) {
                                  _selectedAfterImages = [];
                                }
                                _selectedAfterImages!.addAll(images);
                              });
                            }
                          });
                        },
                      ),
                      const SizedBox(height: AppConstants.itemSpacing),
                      if (_selectedOtherImages != null && _selectedOtherImages!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _selectedOtherImages!.map((xFile) {
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
                                          _selectedOtherImages!.remove(xFile);
                                          if (_selectedOtherImages!.isEmpty) {
                                            _selectedOtherImages = null;
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
                            (_selectedOtherImages == null || _selectedOtherImages!.isEmpty)
                                ? 'إضافة صور أخرى (اختياري)'
                                : 'تغيير/إضافة المزيد من الصور',
                            style: const TextStyle(color: AppConstants.primaryColor)
                        ),
                        onPressed: () {
                          _showImageSourceActionSheet(context, (List<XFile>? images) {
                            if (images != null && images.isNotEmpty) {
                              setDialogContentState(() {
                                if (_selectedOtherImages == null) {
                                  _selectedOtherImages = [];
                                }
                                _selectedOtherImages!.addAll(images);
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
                    List<String> uploadedBeforeUrls = [];
                    List<String> uploadedAfterUrls = [];
                    List<String> uploadedOtherUrls = [];

                    Future<void> uploadImages(List<XFile> files, List<String> store) async {
                      for (int i = 0; i < files.length; i++) {
                        final XFile imageFile = files[i];
                        try {
                          var request = http.MultipartRequest('POST', Uri.parse(AppConstants.uploadUrl));
                          if (kIsWeb) {
                            final bytes = await imageFile.readAsBytes();
                            request.files.add(http.MultipartFile.fromBytes(
                              'image',
                              bytes,
                              filename: imageFile.name,
                              contentType: MediaType.parse(imageFile.mimeType ?? 'image/jpeg'),
                            ));
                          } else {
                            request.files.add(await http.MultipartFile.fromPath(
                              'image',
                              imageFile.path,
                              contentType: MediaType.parse(imageFile.mimeType ?? 'image/jpeg'),
                            ));
                          }

                          var streamedResponse = await request.send();
                          var response = await http.Response.fromStream(streamedResponse);

                          if (response.statusCode == 200) {
                            var responseData = json.decode(response.body);
                            if (responseData['status'] == 'success' && responseData['url'] != null) {
                              store.add(responseData['url']);
                            } else {
                              throw Exception(responseData['message'] ?? 'فشل رفع الصورة (${i+1}) من السيرفر.');
                            }
                          } else {
                            throw Exception('خطأ في الاتصال بالسيرفر لرفع الصورة (${i+1}): ${response.statusCode}');
                          }
                        } catch (e) {
                          if (mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع الصورة (${i+1}): $e', isError: true,);
                        }
                      }
                    }

                    if (_selectedBeforeImages != null && _selectedBeforeImages!.isNotEmpty) {
                      await uploadImages(_selectedBeforeImages!, uploadedBeforeUrls);
                    }

                    if (_selectedAfterImages != null && _selectedAfterImages!.isNotEmpty) {
                      await uploadImages(_selectedAfterImages!, uploadedAfterUrls);
                    }

                    if (_selectedOtherImages != null && _selectedOtherImages!.isNotEmpty) {
                      await uploadImages(_selectedOtherImages!, uploadedOtherUrls);
                    }

                    final uploadedImageUrls = [...uploadedBeforeUrls, ...uploadedAfterUrls, ...uploadedOtherUrls];

                    // ... (rest of the try-catch block for Firestore update)
                    try {
                      await FirebaseFirestore.instance.collection(entriesCollectionPath).add({
                        'type': uploadedImageUrls.isNotEmpty ? 'image_with_note' : 'note',
                        'note': noteController.text.trim(),
                        'imageUrls': uploadedOtherUrls.isNotEmpty ? uploadedOtherUrls : null,
                        if (uploadedBeforeUrls.isNotEmpty) 'beforeImageUrls': uploadedBeforeUrls,
                        if (uploadedAfterUrls.isNotEmpty) 'afterImageUrls': uploadedAfterUrls,
                        'engineerUid': _currentEngineerUid,
                        'engineerName': _currentEngineerName ?? 'مهندس',
                        if (selectedEmployeeId != null) 'employeeId': selectedEmployeeId,
                        if (selectedEmployeeName != null) 'employeeName': selectedEmployeeName,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      // ... (notifications code)
                      if (_projectDataSnapshot != null && _projectDataSnapshot!.exists) {
                        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
                        if (projectData == null) return;

                        final projectNameVal = projectData['name'] ?? 'المشروع';
                        final clientUid = projectData['clientId'] as String?;
                        final List<String> adminUids = await getAdminUids();

                        String actor = selectedEmployeeName ?? _currentEngineerName ?? 'غير معروف';
                        String notificationBody = "قام الموظف $actor بإضافة ${uploadedImageUrls.isNotEmpty ? 'صورة وملاحظة' : 'ملاحظة'} جديدة في ${subPhaseId != null ? 'المرحلة الفرعية' : 'المرحلة'}: '$phaseOrSubPhaseName'.";

                        if (adminUids.isNotEmpty) {
                          await sendNotificationsToMultiple(
                            recipientUserIds: adminUids,
                            title: 'إضافة جديدة في مشروع: $projectNameVal',
                            body: notificationBody,
                            type: 'project_entry_engineer',
                            projectId: widget.projectId,
                            itemId: subPhaseId ?? phaseId,
                            senderName: _currentEngineerName,
                          );
                        }

                        if (clientUid != null && clientUid.isNotEmpty) {
                          await sendNotification(
                            recipientUserId: clientUid,
                            title: '✨ تحديث جديد لمشروعك: $projectNameVal',
                            body: 'فريق العمل أضاف ${uploadedImageUrls.isNotEmpty ? 'صور وملاحظات' : 'ملاحظات'} جديدة حول تقدم العمل في المرحلة "$phaseOrSubPhaseName".',
                            type: 'project_entry_engineer_to_client',
                            projectId: widget.projectId,
                            itemId: subPhaseId ?? phaseId,
                            senderName: _currentEngineerName,
                          );
                        }
                      }
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
    // ... (no changes in this function)
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
                final List<String> beforeUrls = (entryData['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final List<String> afterUrls = (entryData['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];

                final String employeeName = entryData['employeeName'] ?? entryData['engineerName'] ?? 'مهندس';
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
                        if (beforeUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('صور قبل:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right),
                                const SizedBox(height: 4),
                                Wrap(
                                  textDirection: ui.TextDirection.rtl,
                                  spacing: AppConstants.paddingSmall / 2,
                                  runSpacing: AppConstants.paddingSmall / 2,
                                  children: beforeUrls.map((url) {
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
                              ],
                            ),
                          ),
                        if (afterUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('صور بعد:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right),
                                const SizedBox(height: 4),
                                Wrap(
                                  textDirection: ui.TextDirection.rtl,
                                  spacing: AppConstants.paddingSmall / 2,
                                  runSpacing: AppConstants.paddingSmall / 2,
                                  children: afterUrls.map((url) {
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
                              ],
                            ),
                          ),
                        if (imageUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('صور إضافية:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right),
                                const SizedBox(height: 4),
                                Wrap(
                                  textDirection: ui.TextDirection.rtl,
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
                              ],
                            ),
                          ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: beforeUrls.isNotEmpty || afterUrls.isNotEmpty || imageUrls.isNotEmpty ? AppConstants.paddingSmall : 0),
                            child: Text(note, style: const TextStyle(fontSize: 13.5)),
                          ),
                        const SizedBox(height: AppConstants.paddingSmall / 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'بواسطة: $employeeName - ${timestamp != null ? DateFormat('dd/MM/yy hh:mm a', 'ar').format(timestamp.toDate()) : 'غير معروف'}',
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
    // ... (no changes in this function)
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

  void _handleFileTap(String url) {
    final lower = url.toLowerCase();
    const exts = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
    if (exts.any((e) => lower.endsWith(e))) {
      _viewImageDialog(url);
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // --- Helper function to fetch entries for PDF ---
  Future<List<Map<String, dynamic>>> _fetchEntriesForPdf(String entriesCollectionPath) async {
    final List<Map<String, dynamic>> entriesList = [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(entriesCollectionPath)
          .orderBy('timestamp', descending: false) // Or true, depending on desired order in PDF
          .get();
      for (var doc in snapshot.docs) {
        entriesList.add(doc.data());
      }
    } catch (e) {
      print("Error fetching entries for PDF from $entriesCollectionPath: $e");
      // Optionally, include an error message in the PDF or handle otherwise
    }
    return entriesList;
  }

  Future<List<String>> _fetchEmployeeNamesForPdf(String id, {required bool isSub}) async {
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('employeeAssignments');
      q = isSub ? q.where('subPhaseId', isEqualTo: id) : q.where('phaseId', isEqualTo: id);
      final snap = await q.get();
      return snap.docs
          .map((d) => d.data()['employeeName']?.toString() ?? 'موظف')
          .toList();
    } catch (e) {
      print('Error fetching employees for PDF: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPartRequestsForPdf() async {
    final List<Map<String, dynamic>> requests = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('partRequests')
          .where('projectId', isEqualTo: widget.projectId)
          .orderBy('requestedAt', descending: false)
          .get();
      for (var doc in snap.docs) {
        requests.add(doc.data());
      }
    } catch (e) {
      print('Error fetching part requests for PDF: $e');
    }
    return requests;
  }

  Future<void> _updatePartRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('partRequests')
          .doc(requestId)
          .update({'status': newStatus});
      if (mounted) {
        _showFeedbackSnackBar(context, 'تم تحديث حالة الطلب.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل تحديث الطلب: $e', isError: true);
      }
    }
  }

  Future<void> _deletePartRequest(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('partRequests').doc(docId).delete();
      if (mounted) {
        _showFeedbackSnackBar(context, 'تم حذف الطلب بنجاح', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showFeedbackSnackBar(context, 'فشل حذف الطلب: $e', isError: true);
      }
    }
  }

  Future<void> _showPartRequestDetailsDialog(DocumentSnapshot requestDoc) async {
    final data = requestDoc.data() as Map<String, dynamic>?;
    if (data == null) return;
    String status = data['status'] ?? 'معلق';
    final List<dynamic>? items = data['items'];
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (stfCtx, setState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تفاصيل طلب المواد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items != null && items.isNotEmpty)
                      ...items.map((e) => Text('${e['name']} - ${e['quantity']}')).toList()
                    else
                      Text('${data['partName'] ?? ''} - ${data['quantity'] ?? ''}'),
                    const SizedBox(height: AppConstants.itemSpacing),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(value: 'معلق', child: Text('معلق')),
                        DropdownMenuItem(value: 'تمت الموافقة', child: Text('تمت الموافقة')),
                        DropdownMenuItem(value: 'مرفوض', child: Text('مرفوض')),
                        DropdownMenuItem(value: 'تم الطلب', child: Text('تم الطلب')),
                        DropdownMenuItem(value: 'تم الاستلام', child: Text('تم الاستلام')),
                      ],
                      onChanged: (val) => setState(() => status = val ?? status),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _deletePartRequest(requestDoc.id);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppConstants.errorColor),
                  child: const Text('حذف'),
                ),
                TextButton(
                  onPressed: () async {
                    final bytes = await PartRequestPdfGenerator.generate(data);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/pdf_preview', arguments: {
                      'bytes': bytes,
                      'fileName': 'part_request_${requestDoc.id}.pdf',
                      'text': "تقرير طلب مواد للمشروع ${data['projectName'] ?? ''}"
                    });
                  },
                  child: const Text('تقرير PDF'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _updatePartRequestStatus(requestDoc.id, status);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // Helper to fetch remote images for use in PDFs
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
        // Avoid downloading extremely large images that could exhaust memory.
        try {
          final head = await http
              .head(Uri.parse(url))
              .timeout(const Duration(seconds: 30));
          final lenStr = head.headers['content-length'];
          final len = lenStr != null ? int.tryParse(lenStr) : null;
          if (len != null && len > PdfReportGenerator.maxImageFileSize) {
            print('Skipping large image from URL $url: $len bytes');
            return;
          }
        } catch (_) {}

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
        } else {
          print('Failed to load image from URL $url');
        }
      } on TimeoutException catch (_) {
        print('Timeout fetching image from URL $url');
      } catch (e) {
        print('Error fetching image from URL $url: $e');
      }
    }));
    return fetched;
  }


  // ... (inside _ProjectDetailsPageState) ...

// --- MODIFIED PDF Generation and Sharing Function ---
  Future<void> _generateAndSharePdf(
      String phaseOrTestId,
      String name, {
        required bool isTestSection,
        bool isSubPhase = false, // True if PDF is for a single sub-phase
        String? sectionName, // For tests
        String? testNote, // For tests
        String? testImageUrl, // For tests
        String? engineerNameOnTest, // For tests - who completed it
      }) async {
    if (_arabicFont == null) {
      _showFeedbackSnackBar(context, "خطأ: الخط العربي غير متوفر لإنشاء PDF.", isError: true);
      await _loadArabicFont();
      if(_arabicFont == null){
        _showFeedbackSnackBar(context, "فشل تحميل الخط العربي. لا يمكن إنشاء PDF.", isError: true);
        return;
      }
    }

    _showLoadingDialog(context, "جاري إنشاء التقرير...");

    final ByteData logoByteData = await rootBundle.load('assets/images/app_logo.png');
    final Uint8List logoBytes = logoByteData.buffer.asUint8List();
    final pw.MemoryImage appLogo = pw.MemoryImage(logoBytes);

    // Load emoji fallback font
    pw.Font? emojiFont;
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmoji();
    } catch (e) {
      print('Error loading NotoColorEmoji font: $e');
    }

    final List<pw.Font> commonFontFallback = emojiFont != null ? [emojiFont!] : [];

    final pdf = pw.Document();
    final sanitizedName = name.replaceAll(RegExp(r'[^\w\s]+'),'').replaceAll(' ', '_');
    final fileName = "${sanitizedName}_report_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final token = generateReportToken();
    final qrLink = buildReportDownloadUrl(fileName, token);
    final List<pw.Widget> contentWidgets = [];

    final pw.TextStyle regularStyle =
        pw.TextStyle(font: _arabicFont, fontSize: 11, fontFallback: commonFontFallback);
    final pw.TextStyle boldStyle = pw.TextStyle(
        font: _arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 12, fontFallback: commonFontFallback);
    final pw.TextStyle headerStyle = pw.TextStyle(
        font: _arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blueGrey800, fontFallback: commonFontFallback);
    final pw.TextStyle subHeaderStyle = pw.TextStyle(
        font: _arabicFont,
        fontWeight: pw.FontWeight.bold,
        fontSize: 14,
        color: PdfColors.blueGrey600,
        fontFallback: commonFontFallback);
    final pw.TextStyle smallGreyStyle = pw.TextStyle(
        font: _arabicFont,
        fontSize: 9,
        color: PdfColors.grey600,
        fontFallback: commonFontFallback);

    String projectName = (_projectDataSnapshot?.data() as Map<String, dynamic>)?['name'] ?? 'اسم المشروع غير محدد';
    String clientName = (_projectDataSnapshot?.data() as Map<String, dynamic>)?['clientName'] ?? 'غير معروف';
    final List<dynamic> assignedEngs = (_projectDataSnapshot?.data() as Map<String, dynamic>?)?['assignedEngineers'] as List<dynamic>? ?? [];
    final String responsibleEngineers = assignedEngs.isNotEmpty
        ? assignedEngs.map((e) => (e as Map<String, dynamic>)['name'] ?? 'مهندس').join('، ')
        : '';

    final String headerText = 'تقرير مشروع: $projectName';

    contentWidgets.add(pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('بواسطة المهندس: ${_currentEngineerName ?? 'غير محدد'}', style: regularStyle, textDirection: pw.TextDirection.rtl),
      ],
    ));
    if (responsibleEngineers.isNotEmpty) {
      contentWidgets.add(pw.SizedBox(height: 4));
      contentWidgets.add(pw.Text('المهندس المسؤول: $responsibleEngineers', style: regularStyle, textDirection: pw.TextDirection.rtl));
    }

    final partRequests = await _fetchPartRequestsForPdf();
    if (partRequests.isNotEmpty) {
      contentWidgets.add(pw.SizedBox(height: 6));
      contentWidgets.add(pw.Text('القطع المطلوبة للمشروع:', style: boldStyle, textDirection: pw.TextDirection.rtl));
      contentWidgets.add(_buildPartSummaryTable(partRequests, _arabicFont!));
    }
    contentWidgets.add(pw.Divider(height: 20, thickness: 1, color: PdfColors.grey400));

    // Skip fetching images to speed up PDF generation

    // Identify all image URLs that might be needed in the PDF
    List<String> allImageUrlsToFetch = [];

    if (isTestSection) {
      if (testImageUrl != null) {
        allImageUrlsToFetch.add(testImageUrl);
      }
    } else { // It's a Phase (Main or specific Sub-Phase)
      if (isSubPhase) {
        String entriesPath = 'projects/${widget.projectId}/subphases_status/$phaseOrTestId/entries';
        List<Map<String, dynamic>> entries = await _fetchEntriesForPdf(entriesPath);
        for (var entry in entries) {
          final List<dynamic>? imageUrlsDynamic = entry['imageUrls'] as List<dynamic>?;
          if (imageUrlsDynamic != null) {
            allImageUrlsToFetch.addAll(imageUrlsDynamic.map((e) => e.toString()).toList());
          }
        }
      } else { // PDF for a Main Phase and ALL its sub-phases
        String mainPhaseEntriesPath = 'projects/${widget.projectId}/phases_status/$phaseOrTestId/entries';
        List<Map<String, dynamic>> mainPhaseEntries = await _fetchEntriesForPdf(mainPhaseEntriesPath);
        for (var entry in mainPhaseEntries) {
          final List<dynamic>? imageUrlsDynamic = entry['imageUrls'] as List<dynamic>?;
          if (imageUrlsDynamic != null) {
            allImageUrlsToFetch.addAll(imageUrlsDynamic.map((e) => e.toString()).toList());
          }
        }

        final mainPhaseStructure = predefinedPhasesStructure.firstWhere((p) => p['id'] == phaseOrTestId, orElse: () => {});
        if (mainPhaseStructure.isNotEmpty && (mainPhaseStructure['subPhases'] as List).isNotEmpty) {
          List<Map<String,dynamic>> subPhases = mainPhaseStructure['subPhases'] as List<Map<String,dynamic>>;
          for (var subPhaseMap in subPhases) {
            final subPhaseId = subPhaseMap['id'] as String;
            List<Map<String, dynamic>> subPhaseEntries = await _fetchEntriesForPdf('projects/${widget.projectId}/subphases_status/$subPhaseId/entries');
            for (var entry in subPhaseEntries) {
              final List<dynamic>? imageUrlsDynamic = entry['imageUrls'] as List<dynamic>?;
              if (imageUrlsDynamic != null) {
                allImageUrlsToFetch.addAll(imageUrlsDynamic.map((e) => e.toString()).toList());
              }
            }
          }
        }
      }
    }

    // Images are not fetched; use links instead for faster PDF generation


    if (isTestSection) {
      contentWidgets.add(pw.Text('تقرير اختبار', style: subHeaderStyle, textDirection: pw.TextDirection.rtl));
      contentWidgets.add(pw.SizedBox(height: 5));
      if (sectionName != null) {
        contentWidgets.add(pw.Text('قسم الاختبار: $sectionName', style: boldStyle, textDirection: pw.TextDirection.rtl));
      }
      contentWidgets.add(pw.Text('اسم الاختبار: $name', style: regularStyle, textDirection: pw.TextDirection.rtl));
      if (engineerNameOnTest != null) {
        contentWidgets.add(pw.Text('أكمل بواسطة: $engineerNameOnTest', style: regularStyle, textDirection: pw.TextDirection.rtl));
      }
      if (testNote != null && testNote.isNotEmpty) {
        contentWidgets.add(pw.Text('الملاحظات: $testNote', style: regularStyle, textDirection: pw.TextDirection.rtl));
      }
      contentWidgets.add(pw.SizedBox(height: 10));
      if (testImageUrl != null) {
        contentWidgets.add(pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('صورة الاختبار:', style: boldStyle, textDirection: pw.TextDirection.rtl),
                  pw.SizedBox(height: 5),
                  pw.UrlLink(
                    destination: testImageUrl,
                    child: pw.Text(
                      'عرض',
                      style: pw.TextStyle(
                        color: PdfColors.blue,
                        decoration: pw.TextDecoration.underline,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ]
            )
        ));
      }
    } else {
      if (isSubPhase) {
        contentWidgets.add(pw.Text('تقرير مرحلة فرعية', style: subHeaderStyle, textDirection: pw.TextDirection.rtl));
        contentWidgets.add(pw.SizedBox(height: 5));
        contentWidgets.add(pw.Text('اسم المرحلة الفرعية: $name', style: boldStyle, textDirection: pw.TextDirection.rtl));

        bool subCompleted = false;
        String subCompletedBy = 'غير معروف';
        try {
          final subDoc = await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('subphases_status')
              .doc(phaseOrTestId)
              .get();
          if (subDoc.exists) {
            subCompleted = subDoc.data()?['completed'] ?? false;
            subCompletedBy = subDoc.data()?['lastUpdatedByName'] ?? 'غير معروف';
          }
        } catch (e) { print('error fetching subphase status for pdf: $e'); }
        String subStatusText = subCompleted
            ? 'مكتملة (بواسطة: $subCompletedBy)'
            : 'قيد التنفيذ';
        contentWidgets.add(pw.Text('الحالة: $subStatusText', style: regularStyle.copyWith(color: subCompleted ? PdfColors.green700 : PdfColors.orange700), textDirection: pw.TextDirection.rtl));

        final subEmployees = await _fetchEmployeeNamesForPdf(phaseOrTestId, isSub: true);
        if (subEmployees.isNotEmpty) {
          contentWidgets.add(pw.Text('العمال المشاركون: ${subEmployees.join('، ')}', style: regularStyle, textDirection: pw.TextDirection.rtl));
        }

        String entriesPath = 'projects/${widget.projectId}/subphases_status/$phaseOrTestId/entries';
        List<Map<String, dynamic>> entries = await _fetchEntriesForPdf(entriesPath);
        if (entries.isNotEmpty) {
          contentWidgets.add(pw.SizedBox(height: 10));
          contentWidgets.add(pw.Text('الملاحظات والصور:', style: boldStyle, textDirection: pw.TextDirection.rtl));
          for (var entry in entries) {
            final String note = entry['note'] ?? '';
            final List<dynamic>? imageUrlsDynamic = entry['imageUrls'] as List<dynamic>?;
            final List<String> imageUrls = imageUrlsDynamic?.map((e) => e.toString()).toList() ?? [];
            final String entryEngineer = entry['employeeName'] ?? entry['engineerName'] ?? 'مهندس';
            final Timestamp? ts = entry['timestamp'] as Timestamp?;
            final String entryDate = ts != null ? DateFormat('dd/MM/yy hh:mm a', 'ar').format(ts.toDate()) : 'غير معروف';

            contentWidgets.add(pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 5),
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (note.isNotEmpty) pw.Text('ملاحظة: $note', style: regularStyle, textDirection: pw.TextDirection.rtl),
                      pw.SizedBox(height: 3),
                      for (String imgUrl in imageUrls)
                        pw.Padding(
                          padding: pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.UrlLink(
                            destination: imgUrl,
                            child: pw.Text(
                              'عرض',
                              style: pw.TextStyle(
                                color: PdfColors.blue,
                                decoration: pw.TextDecoration.underline,
                              ),
                              textDirection: pw.TextDirection.rtl,
                            ),
                          ),
                        ),
                      pw.Text('بواسطة: $entryEngineer - $entryDate', style: smallGreyStyle, textDirection: pw.TextDirection.rtl),
                    ]
                )
            ));
          }
        } else {
          contentWidgets.add(pw.Text('لا توجد ملاحظات أو صور لهذه المرحلة الفرعية.', style: regularStyle, textDirection: pw.TextDirection.rtl));
        }

      } else { // PDF for a Main Phase and ALL its sub-phases
        contentWidgets.add(pw.Text('تقرير مرحلة رئيسية', style: subHeaderStyle, textDirection: pw.TextDirection.rtl));
        contentWidgets.add(pw.SizedBox(height: 5));
        contentWidgets.add(pw.Text('اسم المرحلة: $name', style: boldStyle, textDirection: pw.TextDirection.rtl));

        bool mainCompleted = false;
        String mainCompletedBy = 'غير معروف';
        try {
          final phaseDoc = await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('phases_status')
              .doc(phaseOrTestId)
              .get();
          if (phaseDoc.exists) {
            mainCompleted = phaseDoc.data()?['completed'] ?? false;
            mainCompletedBy = phaseDoc.data()?['lastUpdatedByName'] ?? 'غير معروف';
          }
        } catch (e) { print('error fetching phase status for pdf: $e'); }
        String mainStatusText =
            mainCompleted ? 'مكتملة (بواسطة: $mainCompletedBy)' : 'قيد التنفيذ';
        contentWidgets.add(pw.Text('حالة المرحلة: $mainStatusText', style: regularStyle.copyWith(color: mainCompleted ? PdfColors.green700 : PdfColors.orange700), textDirection: pw.TextDirection.rtl));

        final mainEmployees = await _fetchEmployeeNamesForPdf(phaseOrTestId, isSub: false);
        if (mainEmployees.isNotEmpty) {
          contentWidgets.add(pw.Text('العمال المشاركون: ${mainEmployees.join('، ')}', style: regularStyle, textDirection: pw.TextDirection.rtl));
        }

        String mainPhaseEntriesPath = 'projects/${widget.projectId}/phases_status/$phaseOrTestId/entries';
        List<Map<String, dynamic>> mainPhaseEntries = await _fetchEntriesForPdf(mainPhaseEntriesPath);
        if (mainPhaseEntries.isNotEmpty) {
          contentWidgets.add(pw.SizedBox(height: 10));
          contentWidgets.add(pw.Text('ملاحظات وصور المرحلة الرئيسية:', style: boldStyle, textDirection: pw.TextDirection.rtl));
          for (var entry in mainPhaseEntries) {
            final String note = entry['note'] ?? '';
            final List<dynamic>? imageUrlsDynamic = entry['imageUrls'] as List<dynamic>?;
            final List<String> imageUrls = imageUrlsDynamic?.map((e) => e.toString()).toList() ?? [];
            final String entryEngineer = entry['employeeName'] ?? entry['engineerName'] ?? 'مهندس';
            final Timestamp? ts = entry['timestamp'] as Timestamp?;
            final String entryDate = ts != null ? DateFormat('dd/MM/yy hh:mm a', 'ar').format(ts.toDate()) : 'غير معروف';

            contentWidgets.add(pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 5),
                margin: pw.EdgeInsets.only(bottom:5),
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (note.isNotEmpty) pw.Text('ملاحظة: $note', style: regularStyle, textDirection: pw.TextDirection.rtl),
                      pw.SizedBox(height: 3),
                      for (String imgUrl in imageUrls)
                        pw.Padding(
                          padding: pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.UrlLink(
                            destination: imgUrl,
                            child: pw.Text(
                              'عرض',
                              style: pw.TextStyle(
                                color: PdfColors.blue,
                                decoration: pw.TextDecoration.underline,
                              ),
                              textDirection: pw.TextDirection.rtl,
                            ),
                          ),
                        ),
                      pw.Text('بواسطة: $entryEngineer - $entryDate', style: smallGreyStyle, textDirection: pw.TextDirection.rtl),
                    ]
                )
            ));
          }
        } else {
          contentWidgets.add(pw.Text('لا توجد ملاحظات أو صور للمرحلة الرئيسية.', style: regularStyle, textDirection: pw.TextDirection.rtl));
        }
        contentWidgets.add(pw.SizedBox(height: 15));


        final mainPhaseStructure = predefinedPhasesStructure.firstWhere((p) => p['id'] == phaseOrTestId, orElse: () => {});
        if (mainPhaseStructure.isNotEmpty && (mainPhaseStructure['subPhases'] as List).isNotEmpty) {
          contentWidgets.add(pw.Text('تفاصيل المهام (المراحل الفرعية):', style: subHeaderStyle, textDirection: pw.TextDirection.rtl));
          contentWidgets.add(pw.SizedBox(height: 5));

          List<Map<String,dynamic>> subPhases = mainPhaseStructure['subPhases'] as List<Map<String,dynamic>>;
          for (var subPhaseMap in subPhases) {
            final subPhaseId = subPhaseMap['id'] as String;
            final subPhaseName = subPhaseMap['name'] as String;

            bool isSubPhaseCompleted = false;
            String subPhaseCompletedBy = "غير معروف";
            try {
              final subPhaseStatusDoc = await FirebaseFirestore.instance
                  .collection('projects').doc(widget.projectId)
                  .collection('subphases_status').doc(subPhaseId).get();
              if (subPhaseStatusDoc.exists) {
                isSubPhaseCompleted = subPhaseStatusDoc.data()?['completed'] ?? false;
                subPhaseCompletedBy = subPhaseStatusDoc.data()?['lastUpdatedByName'] ?? "غير معروف";
              }
            } catch(e) { print("Error fetching subphase status: $e");}

            String statusText = isSubPhaseCompleted
                ? 'مكتملة (بواسطة: $subPhaseCompletedBy)'
                : 'قيد التنفيذ';

            contentWidgets.add(pw.Container(
                margin: pw.EdgeInsets.only(bottom: 10),
                padding: pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4)
                ),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(' المهمة: $subPhaseName', style: boldStyle, textDirection: pw.TextDirection.rtl),
                      pw.Text(' الحالة: $statusText', style: regularStyle.copyWith(color: isSubPhaseCompleted ? PdfColors.green700 : PdfColors.orange700), textDirection: pw.TextDirection.rtl),
                      pw.SizedBox(height: 5),
                    ]
                )
            ));
            final subEmpNames = await _fetchEmployeeNamesForPdf(subPhaseId, isSub: true);
            if (subEmpNames.isNotEmpty) {
              contentWidgets.add(pw.Text('العمال: ' + subEmpNames.join('، '), style: regularStyle, textDirection: pw.TextDirection.rtl));
            }
            List<Map<String, dynamic>> subPhaseEntries = await _fetchEntriesForPdf('projects/${widget.projectId}/subphases_status/$subPhaseId/entries');
            if(subPhaseEntries.isNotEmpty){
              contentWidgets.add(pw.Text('  ملاحظات وصور المهمة:', style: regularStyle.copyWith(fontWeight: pw.FontWeight.bold), textDirection: pw.TextDirection.rtl));
              for (var entry in subPhaseEntries) {
                final String note = entry['note'] ?? '';
                final List<dynamic>? imageUrlsDynamic = entry['imageUrls'] as List<dynamic>?;
                final List<String> imageUrls = imageUrlsDynamic?.map((e) => e.toString()).toList() ?? [];
                final String entryEngineer = entry['employeeName'] ?? entry['engineerName'] ?? 'مهندس';
                final Timestamp? ts = entry['timestamp'] as Timestamp?;
                final String entryDate = ts != null ? DateFormat('dd/MM/yy hh:mm a', 'ar').format(ts.toDate()) : 'غير معروف';

                contentWidgets.add(pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 3, horizontal: 5),
                    margin: pw.EdgeInsets.only(right: 10, bottom: 3, top:3),
                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (note.isNotEmpty) pw.Text('  $note', style: regularStyle, textDirection: pw.TextDirection.rtl),
                          pw.SizedBox(height: 2),
                          for (String imgUrl in imageUrls)
                            pw.Padding(
                              padding: pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.UrlLink(
                                destination: imgUrl,
                                child: pw.Text(
                                  'عرض',
                                  style: pw.TextStyle(
                                    color: PdfColors.blue,
                                    decoration: pw.TextDecoration.underline,
                                  ),
                                  textDirection: pw.TextDirection.rtl,
                                ),
                              ),
                            ),
                          pw.Text('  بواسطة: $entryEngineer - $entryDate', style: smallGreyStyle, textDirection: pw.TextDirection.rtl),
                        ]
                    )
                ));
              }
              contentWidgets.add(pw.SizedBox(height:5));
            }
          }
        }
      }
    }

    contentWidgets.add(pw.SizedBox(height: 30));
    contentWidgets.add(
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.red, width: 1.5),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            'ملاحظة هامة: في حال مضى 24 ساعة يعتبر هذا التقرير مكتمل وغير قابل للتعديل.',
            style: pw.TextStyle(font: _arabicFont, color: PdfColors.red, fontWeight: pw.FontWeight.bold, fontSize: 10),
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
          ),
        )
    );

    pdf.addPage(
        pw.MultiPage(
            maxPages: 1000000,
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              orientation: pw.PageOrientation.portrait,
              textDirection: pw.TextDirection.rtl,
              theme: pw.ThemeData.withFont(
                  base: _arabicFont, bold: _arabicFont, fontFallback: commonFontFallback),
              margin: PdfStyles.pageMargins,
            ),
            header: (context) => PdfStyles.buildHeader(
              font: _arabicFont!,
              logo: appLogo,
              headerText: headerText,
              now: DateTime.now(),
              projectName: projectName,
              clientName: clientName,
            ),
            build: (context) => contentWidgets,
            footer: (pw.Context context) => PdfStyles.buildFooter(
                context,
                font: _arabicFont!,
                fontFallback: commonFontFallback,
                qrData: qrLink,
                generatedByText:
                    'المهندس: ${_currentEngineerName ?? 'غير محدد'}'),
        )
    );

    try {
      final pdfBytes = await pdf.save();
      final link = await uploadReportPdf(pdfBytes, fileName, token);

      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, "تم إنشاء التقرير بنجاح.", isError: false);

      _openPdfPreview(
        pdfBytes,
        fileName,
        'الرجاء الإطلاع على تقرير ${isTestSection ? "الاختبار" : "المرحلة"}: $name لمشروع $projectName.',
        link,
      );

    } catch (e) {
      _hideLoadingDialog(context);
      _showFeedbackSnackBar(context, "فشل إنشاء أو مشاركة التقرير: $e", isError: true);
      print("Error generating/sharing PDF: $e");
    }
  }

  Future<void> _saveOrSharePdf(Uint8List pdfBytes, String fileName, String subject, String text) async {
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final outputDir = await getTemporaryDirectory();
      final filePath = "${outputDir.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      Share.shareXFiles(
        [XFile(filePath)],
        subject: subject,
        text: text,
      );
    }
  }

  void _openPdfPreview(
      Uint8List pdfBytes, String fileName, String text, String? link) {
    Navigator.of(context).pushNamed('/pdf_preview', arguments: {
      'bytes': pdfBytes,
      'fileName': fileName,
      'text': text,
      'link': link,
      'phone': _clientPhone,
    });
  }


} // End of _ProjectDetailsPageState

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
        if (_readMore && widget.text.length > endIndex && endIndex > 0) {
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