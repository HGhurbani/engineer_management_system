// lib/pages/admin/admin_project_details_page.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import '../../utils/pdf_styles.dart';
import '../../utils/pdf_image_cache.dart';
import '../../utils/report_storage.dart';
import '../../utils/pdf_report_generator.dart';
import '../../utils/part_request_pdf_generator.dart';
import '../../utils/progress_dialog.dart';

import 'package:engineer_management_system/html_stub.dart'
if (dart.library.html) 'dart:html' as html;

// import 'package:url_launcher/url_launcher.dart'; // Not used directly for notifications
// import 'package:share_plus/share_plus.dart'; // Not used directly for notifications
import 'dart:ui' as ui;

import 'edit_assigned_engineers_page.dart';

// --- MODIFICATION START: Import notification helper functions ---
// Make sure the path to your main.dart (or a dedicated notification service file) is correct.
import '../../main.dart'; // Assuming helper functions are in main.dart
import '../engineer/edit_phase_page.dart';
// --- MODIFICATION END ---


// ... (AppConstants class remains the same) ...


class AdminProjectDetailsPage extends StatefulWidget {
  final String projectId;
  final String? highlightItemId;
  final String? notificationType;
  const AdminProjectDetailsPage({
    super.key,
    required this.projectId,
    this.highlightItemId,
    this.notificationType,
  });

  @override
  State<AdminProjectDetailsPage> createState() =>
      _AdminProjectDetailsPageState();
}

class _AdminProjectDetailsPageState extends State<AdminProjectDetailsPage> with TickerProviderStateMixin {
  Key _projectFutureBuilderKey = UniqueKey();
  String? _currentUserRole;
  // --- MODIFICATION START: Variable for current admin name ---
  String? _currentAdminName;
  // --- MODIFICATION END ---
  bool _isPageLoading = true;
  DocumentSnapshot? _projectDataSnapshot;

  String? _highlightPhaseId;
  String? _highlightSubPhaseId;
  String? _highlightTestId;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _phaseKeys = {};
  final Map<String, GlobalKey> _subPhaseKeys = {};
  final Map<String, GlobalKey> _testKeys = {};

  late TabController _tabController;
  List<QueryDocumentSnapshot> _allAvailableEngineers = [];
  List<QueryDocumentSnapshot> _projectEmployees = [];
  List<QueryDocumentSnapshot> _projectAssignedEmployees = [];
  List<QueryDocumentSnapshot> _projectPartRequests = [];

  String? _clientTypeKeyFromFirestore;
  String? _clientTypeDisplayString;
  String? _clientPhone;
  pw.Font? _arabicFont;

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
    _tabController = TabController(length: 7, vsync: this);
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
    _loadArabicFont();
    _fetchInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
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
    await _fetchCurrentUserRoleAndName(); // --- MODIFICATION: Renamed and combined ---
    await _loadAllAvailableEngineers();
    await _fetchProjectAndPhasesData(); // This will also fetch client type
    if (mounted) {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  // --- MODIFICATION START: Combined function to get current user's role and name ---
  Future<void> _fetchCurrentUserRoleAndName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserRole = userData['role'] as String?;
            _currentAdminName = userData['name'] as String? ?? (_currentUserRole == 'admin' ? 'المسؤول' : 'مستخدم');
          });
        } else if (mounted) {
          _currentAdminName = _currentUserRole == 'admin' ? 'المسؤول' : 'مستخدم';
        }
      } catch (e) {
        print("Error fetching current user data: $e");
        if (mounted) {
          _currentAdminName = _currentUserRole == 'admin' ? 'المسؤول' : 'مستخدم'; // Fallback
        }
      }
    } else if (mounted) {
      _currentAdminName = 'زائر'; // Fallback if no user
    }
  }
  // --- MODIFICATION END ---

  Future<void> _showEditEntryDialog(String phaseId, String entryId, Map<String, dynamic> entryData, {String? subPhaseId}) async {
    if (!mounted) return;

    final noteController = TextEditingController(text: entryData['note'] ?? '');
    String? tempImageUrl = entryData['imageUrl'] as String?;
    File? pickedImageFile;
    bool isUploading = false;

    String collectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

    await showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (stfContext, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: Text(subPhaseId == null ? 'تعديل إدخال المرحلة' : 'تعديل إدخال المرحلة الفرعية',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'الملاحظة', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                    if (tempImageUrl != null && pickedImageFile == null)
                      Column(
                        children: [
                          Image.network(tempImageUrl!, height: 120, fit: BoxFit.contain),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor, size: 18),
                            label: const Text('إزالة الصورة الحالية', style: TextStyle(color: AppConstants.errorColor)),
                            onPressed: () => setDialogState(() => tempImageUrl = null),
                          ),
                        ],
                      ),
                    if (pickedImageFile != null)
                      Image.file(pickedImageFile!, height: 120, fit: BoxFit.contain),
                    TextButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined, color: AppConstants.primaryColor),
                      label: Text(pickedImageFile == null && tempImageUrl == null ? 'إضافة صورة (اختياري)' : 'تغيير الصورة',
                          style: const TextStyle(color: AppConstants.primaryColor)),
                      onPressed: () {
                        _showSingleImageSourceActionSheet(context, (xFile) {
                          if (xFile != null) {
                            setDialogState(() {
                              pickedImageFile = File(xFile.path);
                            });
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (noteController.text.trim().isEmpty && pickedImageFile == null && tempImageUrl == null) {
                            _showFeedbackSnackBar(context, 'الرجاء إدخال ملاحظة أو إضافة صورة.', isError: true);
                            return;
                          }
                          setDialogState(() => isUploading = true);
                          String? finalImageUrl = tempImageUrl;
                          if (pickedImageFile != null) {
                            try {
                              final currentUser = FirebaseAuth.instance.currentUser;
                              final timestampForPath = DateTime.now().millisecondsSinceEpoch;
                              final imageName = '${currentUser?.uid ?? 'user'}_$timestampForPath.jpg';
                              final refPath = subPhaseId == null
                                  ? 'project_entries/${widget.projectId}/$phaseId/$imageName'
                                  : 'project_entries/${widget.projectId}/$subPhaseId/$imageName';
                              final ref = FirebaseStorage.instance.ref().child(refPath);
                              await ref.putFile(pickedImageFile!);
                              finalImageUrl = await ref.getDownloadURL();
                            } catch (e) {
                              if (mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع الصورة: $e', isError: true);
                              setDialogState(() => isUploading = false);
                              return;
                            }
                          }

                          try {
                            await FirebaseFirestore.instance.collection(collectionPath).doc(entryId).update({
                              'note': noteController.text.trim(),
                              'imageUrl': finalImageUrl,
                              'lastEditedByUid': FirebaseAuth.instance.currentUser?.uid,
                              'lastEditedByName': _currentAdminName ?? 'المسؤول',
                              'lastEditedAt': FieldValue.serverTimestamp(),
                            });
                            if (mounted) Navigator.pop(dialogContext);
                            if (mounted) _showFeedbackSnackBar(context, 'تم تحديث الإدخال بنجاح.', isError: false);
                          } catch (e) {
                            if (mounted) _showFeedbackSnackBar(stfContext, 'فشل تحديث الإدخال: $e', isError: true);
                          } finally {
                            if (mounted) setDialogState(() => isUploading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                  child: isUploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('حفظ'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _deleteEntry(String phaseId, String entryId, {String? subPhaseId}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإدخال'),
        content: const Text('هل أنت متأكد من حذف هذا الإدخال؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deleteColor, foregroundColor: Colors.white), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;

    final collectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

    try {
      await FirebaseFirestore.instance.collection(collectionPath).doc(entryId).delete();
      if (mounted) _showFeedbackSnackBar(context, 'تم حذف الإدخال.', isError: false);
    } catch (e) {
      if (mounted) _showFeedbackSnackBar(context, 'فشل حذف الإدخال: $e', isError: true);
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

        final empSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'employee')
            .get();
        if (mounted) setState(() => _projectEmployees = empSnap.docs);

        final partSnap = await FirebaseFirestore.instance
            .collection('partRequests')
            .where('projectId', isEqualTo: widget.projectId)
            .get();
        if (mounted) setState(() => _projectPartRequests = partSnap.docs);

        final assignedEmpSnap = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('employeeAssignments')
            .get();
        if (mounted) setState(() => _projectAssignedEmployees = assignedEmpSnap.docs);

        final String? clientId = projectData?['clientId'] as String?;
        if (clientId != null && clientId.isNotEmpty) {
          try {
            final clientDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
            if (clientDoc.exists && mounted) {
              final clientDataMap = clientDoc.data() as Map<String, dynamic>?;
              final String? fetchedClientTypeKey = clientDataMap?['clientType'] as String?;
              final String? fetchedPhone = clientDataMap?['phone'] as String?;
              setState(() {
                _clientTypeKeyFromFirestore = fetchedClientTypeKey;
                _clientTypeDisplayString = _getClientTypeDisplayValue(fetchedClientTypeKey);
                _clientPhone = fetchedPhone;
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

  // --- MODIFICATION START: Renamed and adapted this function ---
  // This function was originally _sendNotificationToMultipleEngineers
  // It's now more generic but still used here primarily by admin.
  // For a truly generic solution, use the helpers from main.dart
  Future<void> _notifyProjectStakeholders({
    required String title,
    required String body,
    required String notificationType,
    String? phaseOrItemId, // Can be phaseId, subPhaseId, testId
    List<String>? specificRecipientUids, // If null, send to assigned engineers and client
  }) async {
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) return;
    final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>;
    final projectNameVal = projectData['name'] ?? 'المشروع';
    final clientUid = projectData['clientId'] as String?;
    final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
    final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

    List<String> recipients = [];
    if (specificRecipientUids != null) {
      recipients.addAll(specificRecipientUids);
    } else {
      recipients.addAll(assignedEngineerUids);
      if (clientUid != null && clientUid.isNotEmpty) {
        recipients.add(clientUid);
      }
    }
    // Remove duplicates just in case
    recipients = recipients.toSet().toList();


    if (recipients.isEmpty) {
      print("No recipients found for notification type: $notificationType");
      return;
    }

    await sendNotificationsToMultiple(
      recipientUserIds: recipients,
      title: title,
      body: body,
      type: notificationType,
      projectId: widget.projectId,
      itemId: phaseOrItemId,
      senderName: _currentAdminName ?? "المسؤول",
    );
  }
  // --- MODIFICATION END ---


  PreferredSizeWidget _buildAppBar() {
    // ... (same as provided)
    return AppBar(
      title: const Text('تفاصيل المشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22)),
      backgroundColor: AppConstants.primaryColor,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppConstants.primaryColor, AppConstants.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      elevation: 4,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          tooltip: 'تقرير اليوم',
          onPressed: _selectReportDate,
        ),
      ],
      bottom: TabBar(
        controller: _tabController, // Ensure this is using your state's _tabController
        indicatorColor: Colors.white,
        indicatorWeight: 3.0,
        labelColor: Colors.white,
        isScrollable: true,
        labelPadding: EdgeInsets.symmetric(horizontal: 12.0), // يمكنك الإبقاء على هذا أو تعديله
        tabAlignment: TabAlignment.start,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, fontFamily: 'Tajawal'),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
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
      elevation: AppConstants.cardShadow.isNotEmpty
          ? AppConstants.cardShadow.first.blurRadius
          : 0,
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
            _buildDetailRow(
                Icons.badge_rounded,
                'الموظفون:',
                _projectAssignedEmployees.isNotEmpty
                    ? _projectAssignedEmployees
                    .map((e) => (e.data() as Map<String, dynamic>)['employeeName'] ?? '')
                    .toSet()
                    .join('، ')
                    : 'لا يوجد'),
            _buildDetailRow(Icons.person_rounded, 'العميل:', clientName),
            if (_clientPhone != null && _clientPhone!.isNotEmpty)
              _buildPhoneRow(_clientPhone!),
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
            _buildDetailRow(Icons.build_circle_outlined, 'طلبات المواد:', '${_projectPartRequests.length}'),
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

  Widget _buildPhoneRow(String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 1.2),
      child: Row(
        children: [
          const Icon(Icons.phone, size: 20, color: AppConstants.primaryLight),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: Text(phone,
                style: const TextStyle(fontSize: 15, color: AppConstants.textPrimary, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: AppConstants.primaryColor, size: 22),
            onPressed: () async {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.green, size: 22),
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
    // ... (remains structurally similar, calls the updated _buildEntriesList) ...
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للمراحل."));
    }
    return ListView.builder(
      key: const PageStorageKey<String>('adminProjectDetails_phasesTabListView'), // For scroll position restoration
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
              bool isCompleted = false;
              String phaseActualName = phaseName; // Default to predefined name

              if (phaseStatusSnapshot.hasData && phaseStatusSnapshot.data!.exists) {
                final statusData = phaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                isCompleted = statusData['completed'] ?? false;
                phaseActualName = statusData['name'] ?? phaseName; // Use stored name if available
              }

              return Card(
                key: _phaseKeys.putIfAbsent(phaseId, () => GlobalKey()),
                color: phaseId == _highlightPhaseId ? AppConstants.highlightColor : null,
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
                child: ExpansionTile(
                  key: PageStorageKey<String>(phaseId), // For scroll position restoration of individual tiles
                  initiallyExpanded: phaseId == _highlightPhaseId ||
                      subPhasesStructure.any((sp) => sp['id'] == _highlightSubPhaseId),
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? AppConstants.successColor : AppConstants.primaryColor,
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phaseActualName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary, decoration: null)),                  subtitle: Text(isCompleted ? 'مكتملة ✅' : 'قيد التنفيذ ⏳', style: TextStyle(color: isCompleted ? AppConstants.successColor : AppConstants.warningColor, fontWeight: FontWeight.w500)),
                  trailing: Row( // Combine icons in a Row
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Admin can add notes/images
                      // Admin can add notes/images or edit phase
                      if (_currentUserRole == 'admin') ...[
                        IconButton(
                          icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                          tooltip: 'إضافة ملاحظة/صورة للمرحلة الرئيسية',
                          onPressed: () => _showAddNoteOrImageDialog(phaseId, phaseActualName),
                        ),
                        // IconButton(
                        //   icon: const Icon(Icons.edit_note_outlined, color: AppConstants.primaryLight),
                        //   tooltip: 'تعديل بيانات المرحلة',
                        //   onPressed: () async {
                        //     final snapshot = await FirebaseFirestore.instance
                        //         .collection('projects')
                        //         .doc(widget.projectId)
                        //         .collection('phases')
                        //         .doc(phaseId)
                        //         .get();
                        //     final data = snapshot.data() as Map<String, dynamic>? ?? {};
                        //     if (!mounted) return;
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (_) => EditPhasePage(
                        //           projectId: widget.projectId,
                        //           phaseId: phaseId,
                        //           phaseData: data,
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                      // Admin can always toggle
                      if (_currentUserRole == 'admin')
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
                                      key: _subPhaseKeys.putIfAbsent(subPhaseId, () => GlobalKey()),
                                      elevation: 0.5,
                                      color: subPhaseId == _highlightSubPhaseId ? AppConstants.highlightColor : AppConstants.backgroundColor,
                                      margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2, horizontal: AppConstants.paddingSmall /2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                                      child: ExpansionTile( // Sub-phases are also ExpansionTiles
                                        key: PageStorageKey<String>('sub_$subPhaseId'), // Key for sub-phase tile
                                        initiallyExpanded: subPhaseId == _highlightSubPhaseId,
                                        leading: Icon(
                                          isSubCompleted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                          color: isSubCompleted ? AppConstants.successColor : AppConstants.textSecondary, size: 20,
                                        ),
                                        title: Text(subPhaseActualName, style: TextStyle(fontSize: 13.5, color: AppConstants.textSecondary, decoration: null)),
                                        trailing: (_currentUserRole == 'admin')
                                            ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.add_comment_outlined, color: AppConstants.primaryLight),
                                              tooltip: 'إضافة ملاحظة/صورة للمرحلة الفرعية',
                                              onPressed: () => _showAddNoteOrImageDialog(phaseId, subPhaseActualName, subPhaseId: subPhaseId),
                                            ),
                                            Checkbox(
                                              value: isSubCompleted,
                                              activeColor: AppConstants.successColor,
                                              visualDensity: VisualDensity.compact,
                                              onChanged: (value) {
                                                _updateSubPhaseCompletionStatus(phaseId, subPhaseId, subPhaseActualName, value ?? false);
                                              },
                                            ),
                                          ],
                                        )
                                            : null,
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
    if (_projectDataSnapshot == null || !_projectDataSnapshot!.exists) {
      return const Center(child: Text("لا يمكن تحميل تفاصيل المشروع للاختبارات."));
    }
    return ListView.builder(
      key: const PageStorageKey<String>('adminProjectDetails_testsTabListView'),
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
            key: PageStorageKey<String>(sectionId),
            initiallyExpanded: tests.any((t) => t['id'] == _highlightTestId),
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
                    String? engineerName; // Name of engineer who completed, if any

                    if (testStatusSnapshot.hasData && testStatusSnapshot.data!.exists) {
                      final statusData = testStatusSnapshot.data!.data() as Map<String, dynamic>;
                      isTestCompleted = statusData['completed'] ?? false;
                      testNote = statusData['note'] ?? '';
                      testImageUrl = statusData['imageUrl'] as String?;
                      engineerName = statusData['lastUpdatedByName'] as String?; // Changed from 'engineerName' for consistency
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
                      trailing: (_currentUserRole == 'admin') // Only admin can mark tests as complete/incomplete directly from this view
                          ? Checkbox(
                        value: isTestCompleted,
                        activeColor: AppConstants.successColor,
                        onChanged: (value) {
                          // Admin updates test status, potentially overwriting engineer's completion.
                          // The dialog allows admin to add their own notes/image.
                          _updateTestStatus(testId, testName, value ?? false, currentNote: testNote, currentImageUrl: testImageUrl);
                        },
                      )
                          : null,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (engineerName != null && engineerName.isNotEmpty && isTestCompleted)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("أكمل بواسطة: $engineerName", style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic)),
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
                        // Allow admin to edit details or mark complete/incomplete
                        if (_currentUserRole == 'admin') {
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

  Widget _buildPartRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
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
          return _buildErrorState('حدث خطأ في تحميل طلبات المواد: ${snapshot.error}');
        }

        final requests = snapshot.data?.docs ?? [];
        Widget listContent;
        if (requests.isEmpty) {
          listContent = _buildEmptyState('لا توجد طلبات مواد لهذا المشروع حالياً.', icon: Icons.build_circle_outlined);
        } else {
          listContent = ListView.builder(
            key: const PageStorageKey<String>('adminPartRequestsTab'),
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestDoc = requests[index];
              final data = requestDoc.data() as Map<String, dynamic>;
              final List<dynamic>? itemsData = data['items'];
              String partName;
              String quantity;
              if (itemsData != null && itemsData.isNotEmpty) {
                partName = itemsData
                    .map((e) => '${e['name']} (${e['quantity']})')
                    .join('، ');
                quantity = '-';
              } else {
                partName = data['partName'] ?? 'مادة غير مسماة';
                quantity = data['quantity']?.toString() ?? 'N/A';
              }
              final engineerName = data['engineerName'] ?? 'مهندس غير معروف';
              final status = data['status'] ?? 'غير معروف';
              final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
              final formattedDate = requestedAt != null
                  ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(requestedAt)
                  : 'غير معروف';

              Color statusColor;
              IconData statusIcon;
              switch (status) {
                case 'معلق':
                  statusColor = AppConstants.warningColor;
                  statusIcon = Icons.pending_actions_rounded;
                  break;
                case 'تمت الموافقة':
                  statusColor = AppConstants.successColor;
                  statusIcon = Icons.check_circle_outline_rounded;
                  break;
                case 'مرفوض':
                  statusColor = AppConstants.errorColor;
                  statusIcon = Icons.cancel_outlined;
                  break;
                case 'تم الطلب':
                  statusColor = AppConstants.infoColor;
                  statusIcon = Icons.shopping_cart_checkout_rounded;
                  break;
                case 'تم الاستلام':
                  statusColor = AppConstants.primaryColor;
                  statusIcon = Icons.inventory_2_outlined;
                  break;
                default:
                  statusColor = AppConstants.textSecondary;
                  statusIcon = Icons.help_outline_rounded;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
                child: ListTile(
                  title: Text('اسم المادة: $partName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الكمية: $quantity', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                      Text('مقدم الطلب: $engineerName', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(status, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Text('تاريخ الطلب: $formattedDate', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary.withOpacity(0.8))),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        color: AppConstants.primaryColor),
                    tooltip: 'تقرير PDF',
                    onPressed: () async {
                      final bytes = await PartRequestPdfGenerator.generate(data);
                      if (!mounted) return;
                      Navigator.pushNamed(context, '/pdf_preview', arguments: {
                        'bytes': bytes,
                        'fileName': 'part_request_${requestDoc.id}.pdf',
                        'text':
                            'تقرير طلب مواد للمشروع ${data['projectName'] ?? ''}'
                      });
                    },
                  ),
                ),
              );
            },
          );
        }

        return Column(
          children: [
            if (_currentUserRole == 'admin')
              Padding(
                padding: const EdgeInsets.all(AppConstants.paddingSmall),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                    label: const Text('إضافة طلب مواد', style: TextStyle(color: Colors.white)),
                    onPressed: _openAddPartRequestPage,
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  ),
                ),
              ),
            Expanded(child: listContent),
          ],
        );
      },
    );
  }

  Widget _buildEmployeesTab() {
    return StreamBuilder<QuerySnapshot>(
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
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
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
                  subtitle: Text('المرحلة: $phaseName${subPhaseName != null ? ' > $subPhaseName' : ''}\n$attendanceInfo'),
                );
              },
            );
          },
        );
      },
    );
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

  Future<void> _showEditPartRequestDialog(DocumentSnapshot requestDoc) async {
    final data = requestDoc.data() as Map<String, dynamic>?;
    if (data == null) return;
    final partController = TextEditingController(text: data['partName'] ?? '');
    final quantityController = TextEditingController(text: data['quantity']?.toString() ?? '');
    String status = data['status'] ?? 'معلق';

    await showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعديل طلب المواد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: partController,
                  decoration: const InputDecoration(labelText: 'اسم المادة'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
                const SizedBox(height: 8),
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
                  onChanged: (val) => status = val ?? status,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance.collection('partRequests').doc(requestDoc.id).update({
                      'partName': partController.text.trim(),
                      'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
                      'status': status,
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      _showFeedbackSnackBar(context, 'تم تحديث الطلب', isError: false);
                    }
                  } catch (e) {
                    if (mounted) {
                      _showFeedbackSnackBar(context, 'فشل تحديث الطلب: $e', isError: true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAddPartRequestPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final projectName =
    (_projectDataSnapshot?.data() as Map<String, dynamic>?)?['name'] as String?;
    await Navigator.pushNamed(
      context,
      '/engineer/request_material',
      arguments: {
        'engineerId': user.uid,
        'engineerName': _currentAdminName ?? 'المسؤول',
        'projectId': widget.projectId,
        'projectName': projectName,
      },
    );
  }

  Widget _buildAttachmentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingSmall),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.attach_file, color: Colors.white, size: 18),
              label: const Text('إضافة مرفق', style: TextStyle(color: Colors.white)),
              onPressed: _showAddAttachmentDialog,
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            ),
          ),
        ),
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
                    onTap: fileUrl != null ? () => launchUrl(Uri.parse(fileUrl)) : null,
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
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingSmall),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.note_add, color: Colors.white, size: 18),
              label: const Text('إضافة ملاحظة', style: TextStyle(color: Colors.white)),
              onPressed: _showAddImportantNoteDialog,
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            ),
          ),
        ),
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
                      'uploaderUid': FirebaseAuth.instance.currentUser?.uid,
                      'uploaderName': _currentAdminName ?? 'مسؤول',
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
                  'authorUid': FirebaseAuth.instance.currentUser?.uid,
                  'authorName': _currentAdminName ?? 'مسؤول',
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
                _generateDailyReportPdf(
                    start: start, end: start.add(const Duration(days: 1)));
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
                  final start = DateTime(
                      range.start.year, range.start.month, range.start.day);
                  final end = DateTime(
                      range.end.year, range.end.month, range.end.day);
                  _generateDailyReportPdf(
                      start: start, end: end.add(const Duration(days: 1)));
                }
              },
              child: const Text('تقرير فترة محددة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateDailyReportPdf({DateTime? start, DateTime? end}) async {
    DateTime now = DateTime.now();
    final bool isFullReport = start == null && end == null;
    bool useRange = !isFullReport;
    if (useRange) {
      start ??= DateTime(now.year, now.month, now.day);
      end ??= start.add(const Duration(days: 1));
    }

    final fileName = 'daily_report_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final String headerText = isFullReport
        ? 'التقرير الشامل'
        : useRange
            ? 'التقرير التراكمي'
            : 'التقرير اليومي';

    final progress = ProgressDialog.show(context, 'جاري تحميل البيانات...');

    try {
      PdfReportResult result;
      try {
        result = await PdfReportGenerator.generateWithIsolate(
          projectId: widget.projectId,
          projectData: _projectDataSnapshot?.data() as Map<String, dynamic>?,
          phases: predefinedPhasesStructure,
          testsStructure: finalCommissioningTests,
          generatedBy: _currentAdminName,
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
          generatedBy: _currentAdminName,
          start: start,
          end: end,
          onProgress: (p) => progress.value = p,
          lowMemory: true,
        );
      }

      await ProgressDialog.hide(context);
      _showFeedbackSnackBar(context, 'تم إنشاء التقرير بنجاح.', isError: false);

      _openPdfPreview(
        result.bytes,
        fileName,
        'يرجى الإطلاع على $headerText للمشروع.',
        result.downloadUrl,
      );
    } catch (e) {
      await ProgressDialog.hide(context);
      _showFeedbackSnackBar(context, 'فشل إنشاء أو مشاركة التقرير: $e', isError: true);
      print('Error generating daily report PDF: $e');
    }
  }

  Future<void> _loadArabicFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      _arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
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
              Text(message, style: const TextStyle(fontFamily: 'NotoSansArabic')),
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

  Future<Map<String, pw.MemoryImage>> _fetchImagesForUrls(List<String> urls) async {
    final Map<String, pw.MemoryImage> fetched = {};
    await Future.wait(urls.map((url) async {
      if (fetched.containsKey(url)) return;

      final cached = PdfImageCache.get(url);
      if (cached != null) {
        fetched[url] = cached;
        return;
      }

      try {
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
        }
      } on TimeoutException catch (_) {
        print('Timeout fetching image from URL $url');
      } catch (e) {
        print('Error fetching image from URL $url: $e');
      }
    }));
    return fetched;
  }

  Future<void> _saveOrSharePdf(Uint8List pdfBytes, String fileName, String subject, String text) async {
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

  Widget _buildEmptyState(String message, {IconData icon = Icons.info_outline}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppConstants.textSecondary.withOpacity(0.4)),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.textSecondary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 80, color: AppConstants.errorColor),
            const SizedBox(height: AppConstants.itemSpacing),
            Text(message, style: const TextStyle(fontSize: 17, color: AppConstants.errorColor, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }


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
                final String engineerName = entryData['employeeName'] ?? entryData['engineerName'] ?? 'غير معروف';
                final Timestamp? timestamp = entryData['timestamp'] as Timestamp?;

                final List<String> beforeUrls = (entryData['beforeImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final List<String> afterUrls = (entryData['afterImageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final List<String> imageUrlsToDisplay = [];
                final dynamic imagesField = entryData['imageUrls'];
                final dynamic singleImageField = entryData['imageUrl'];

                if (imagesField is List) {
                  imageUrlsToDisplay.addAll(imagesField.map((e) => e.toString()).toList());
                } else if (singleImageField is String && singleImageField.isNotEmpty) {
                  imageUrlsToDisplay.add(singleImageField);
                }

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
                                const Text('صور قبل:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Wrap(
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
                                const Text('صور بعد:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Wrap(
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
                                      height: 100,
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
                            padding: EdgeInsets.only(top: (imageUrlsToDisplay.isNotEmpty || beforeUrls.isNotEmpty || afterUrls.isNotEmpty) ? AppConstants.paddingSmall : 0),
                            child: ExpandableText(note, valueColor: AppConstants.textPrimary),
                          ),
                        const SizedBox(height: AppConstants.paddingSmall / 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'بواسطة: $engineerName - ${timestamp != null ? DateFormat('dd/MM/yy hh:mm a', 'ar').format(timestamp.toDate()) : 'غير معروف'}',
                              style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                            ),
                            if (_currentUserRole == 'admin')
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: AppConstants.primaryLight),
                                    tooltip: 'تعديل الإدخال',
                                    onPressed: () => _showEditEntryDialog(
                                      phaseOrMainPhaseId,
                                      entries[index].id,
                                      entryData,
                                      subPhaseId: subPhaseId,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppConstants.deleteColor),
                                    tooltip: 'حذف الإدخال',
                                    onPressed: () => _deleteEntry(
                                      phaseOrMainPhaseId,
                                      entries[index].id,
                                      subPhaseId: subPhaseId,
                                    ),
                                  ),
                                ],
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
      ],
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

  void _showSingleImageSourceActionSheet(BuildContext context, Function(XFile?) onImageSelected) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppConstants.primaryColor),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  onImageSelected(image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppConstants.primaryColor),
                title: const Text('اختيار صورة من المعرض'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  onImageSelected(image);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImageSourceActionSheet(BuildContext context, Function(List<XFile>?) onImagesSelected) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppConstants.primaryColor),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final picker = ImagePicker();
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
                  final picker = ImagePicker();
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

  // --- MODIFICATION START: _showAddNoteOrImageDialog - Send notifications ---
  Future<void> _showAddNoteOrImageDialog(String phaseId, String phaseOrSubPhaseName, {String? subPhaseId}) async {
    if (!mounted) return;

    final noteController = TextEditingController();
    List<XFile>? _selectedBeforeImages;
    List<XFile>? _selectedAfterImages;
    List<XFile>? _selectedOtherImages;
    bool isUploadingDialog = false;
    final formKeyDialog = GlobalKey<FormState>();

    String dialogTitle = subPhaseId == null
        ? 'إضافة إدخال للمرحلة: $phaseOrSubPhaseName'
        : 'إضافة إدخال للمرحلة الفرعية: $phaseOrSubPhaseName';

    String collectionPath = subPhaseId == null
        ? 'projects/${widget.projectId}/phases_status/$phaseId/entries'
        : 'projects/${widget.projectId}/subphases_status/$subPhaseId/entries';

    await showDialog(
      context: context,
      barrierDismissible: !isUploadingDialog,
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
                          if ((value == null || value.isEmpty) &&
                              (_selectedBeforeImages == null || _selectedBeforeImages!.isEmpty) &&
                              (_selectedAfterImages == null || _selectedAfterImages!.isEmpty) &&
                              (_selectedOtherImages == null || _selectedOtherImages!.isEmpty)) {
                            return 'الرجاء إدخال ملاحظة أو إضافة صورة.';
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
                                        setDialogState(() {
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
                              setDialogState(() {
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
                                        setDialogState(() {
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
                              setDialogState(() {
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
                                        setDialogState(() {
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
                              setDialogState(() {
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
                  onPressed: isUploadingDialog ? null : () async {
                    if (!formKeyDialog.currentState!.validate()) return;

                    setDialogState(() => isUploadingDialog = true);
                    final currentUser = FirebaseAuth.instance.currentUser;
                    String actorName = _currentAdminName ?? "المسؤول";

                    List<String> uploadedBeforeUrls = [];
                    List<String> uploadedAfterUrls = [];
                    List<String> uploadedOtherUrls = [];

                    Future<void> uploadImages(List<XFile> files, List<String> store) async {
                      for (int i = 0; i < files.length; i++) {
                        final XFile imageFile = files[i];
                        try {
                          final timestampForPath = DateTime.now().millisecondsSinceEpoch;
                          final imageName = '${currentUser?.uid ?? 'unknown_user'}_${timestampForPath}_$i.jpg';
                          final refPath = subPhaseId == null
                              ? 'project_entries/${widget.projectId}/$phaseId/$imageName'
                              : 'project_entries/${widget.projectId}/$subPhaseId/$imageName';
                          final ref = FirebaseStorage.instance.ref().child(refPath);
                          if (kIsWeb) {
                            await ref.putData(await imageFile.readAsBytes());
                          } else {
                            await ref.putFile(File(imageFile.path));
                          }
                          final url = await ref.getDownloadURL();
                          store.add(url);
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

                    try {
                      await FirebaseFirestore.instance.collection(collectionPath).add({
                        'type': uploadedImageUrls.isNotEmpty ? 'image_with_note' : 'note',
                        'note': noteController.text.trim(),
                        'imageUrls': uploadedOtherUrls.isNotEmpty ? uploadedOtherUrls : null,
                        if (uploadedBeforeUrls.isNotEmpty) 'beforeImageUrls': uploadedBeforeUrls,
                        if (uploadedAfterUrls.isNotEmpty) 'afterImageUrls': uploadedAfterUrls,
                        'engineerUid': currentUser?.uid,
                        'engineerName': actorName,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (_projectDataSnapshot != null && _projectDataSnapshot!.exists) {
                        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
                        if (projectData == null) return;

                        final projectNameVal = projectData['name'] ?? 'المشروع';
                        final clientUid = projectData['clientId'] as String?;
                        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
                        final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

                        String notificationBody = "قام المسؤول '$actorName' بإضافة ${uploadedImageUrls.isNotEmpty ? 'صورة وملاحظة' : 'ملاحظة'} جديدة في ${subPhaseId != null ? 'المرحلة الفرعية' : 'المرحلة'}: '$phaseOrSubPhaseName'.";

                        // Notify Assigned Engineers
                        if(assignedEngineerUids.isNotEmpty) {
                          await sendNotificationsToMultiple(
                            recipientUserIds: assignedEngineerUids,
                            title: "إضافة جديدة في مشروع: $projectNameVal",
                            body: notificationBody,
                            type: "project_entry_admin",
                            projectId: widget.projectId,
                            itemId: subPhaseId ?? phaseId,
                            senderName: actorName,
                          );
                        }
                        // Notify Client
                        if (clientUid != null && clientUid.isNotEmpty) {
                          await sendNotification(
                            recipientUserId: clientUid,
                            title: "ℹ️ تحديث جديد في مشروعك: $projectNameVal",
                            body: notificationBody,
                            type: "project_entry_admin_to_client",
                            projectId: widget.projectId,
                            itemId: subPhaseId ?? phaseId,
                            senderName: actorName,
                          );
                        }
                      }

                      // --- Notification Logic for Admin Adding Entry ---
                      if (_projectDataSnapshot != null && _projectDataSnapshot!.exists) {
                        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>;
                        final projectNameVal = projectData['name'] ?? 'المشروع';
                        final clientUid = projectData['clientId'] as String?;
                        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
                        final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

                        String notificationBody = "قام المسؤول '$actorName' بإضافة ${uploadedImageUrls.isNotEmpty ? 'صورة وملاحظة' : 'ملاحظة'} جديدة في ${subPhaseId != null ? 'المرحلة الفرعية' : 'المرحلة'}: '$phaseOrSubPhaseName'.";

                        // Notify Assigned Engineers
                        if(assignedEngineerUids.isNotEmpty) {
                          await sendNotificationsToMultiple(
                            recipientUserIds: assignedEngineerUids,
                            title: "إضافة جديدة في مشروع: $projectNameVal",
                            body: notificationBody,
                            type: "project_entry_admin",
                            projectId: widget.projectId,
                            itemId: subPhaseId ?? phaseId,
                            senderName: actorName,
                          );
                        }
                        // Notify Client
                        if (clientUid != null && clientUid.isNotEmpty) {
                          await sendNotification(
                            recipientUserId: clientUid,
                            title: "تحديث في مشروعك: $projectNameVal",
                            body: notificationBody, // Same body for client for simplicity
                            type: "project_entry_admin_to_client", // More specific type if needed for client handling
                            projectId: widget.projectId,
                            itemId: subPhaseId ?? phaseId,
                            senderName: actorName,
                          );
                        }
                      }
                      // --- End Notification Logic ---

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
  // --- MODIFICATION END ---

  // --- MODIFICATION START: _updatePhaseCompletionStatus - Send notifications ---
  // lib/pages/admin/admin_project_details_page.dart
// ... (الكود السابق للدالة)

  Future<void> _updatePhaseCompletionStatus(String phaseId, String phaseName, bool newStatus) async {
    if (!mounted) return;
    try {
      final phaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases_status')
          .doc(phaseId);

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = _currentAdminName ?? "المسؤول";


      await phaseDocRef.set({
        'completed': newStatus,
        'name': phaseName,
        'lastUpdatedByUid': currentUser?.uid,
        'lastUpdatedByName': actorName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // --- ADDITION START: Send notifications for phase completion (Admin) ---
      if (newStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) { // الإشعار فقط عند اكتمال المرحلة
        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
        if (projectData == null) return;

        final projectNameVal = projectData['name'] ?? 'المشروع';
        final clientUid = projectData['clientId'] as String?;
        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
        final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

        // إشعار للمهندسين المعينين
        if (assignedEngineerUids.isNotEmpty) {
          await sendNotificationsToMultiple(
              recipientUserIds: assignedEngineerUids,
              title: 'تحديث مرحلة مشروع: $projectNameVal',
              body: 'المرحلة "$phaseName" في مشروع "$projectNameVal" أصبحت مكتملة (بواسطة المسؤول $actorName).',
              type: 'phase_update_by_admin',
              projectId: widget.projectId,
              itemId: phaseId,
              senderName: actorName
          );
        }
        // إشعار للعميل
        if (clientUid != null && clientUid.isNotEmpty) {
          await sendNotification(
              recipientUserId: clientUid,
              title: '🎉 تحديث رئيسي في مشروعك: $projectNameVal',
              body: 'لقد تم إكمال المرحلة الرئيسية "$phaseName" في مشروعك "$projectNameVal". تهانينا على هذا التقدم الكبير!',
              type: 'phase_completed_for_client',
              projectId: widget.projectId,
              itemId: phaseId,
              senderName: actorName
          );
        }
      } else if (!newStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) { // إشعار عند إلغاء اكتمال المرحلة
        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
        if (projectData == null) return;

        final projectNameVal = projectData['name'] ?? 'المشروع';
        final clientUid = projectData['clientId'] as String?;
        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
        final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

        // إشعار للمهندسين المعينين
        if (assignedEngineerUids.isNotEmpty) {
          await sendNotificationsToMultiple(
              recipientUserIds: assignedEngineerUids,
              title: 'تراجع عن اكتمال مرحلة: $projectNameVal',
              body: 'قام المسؤول $actorName بتغيير حالة المرحلة "$phaseName" في مشروع "$projectNameVal" إلى "قيد التنفيذ".',
              type: 'phase_reverted_by_admin',
              projectId: widget.projectId,
              itemId: phaseId,
              senderName: actorName
          );
        }
        // إشعار للعميل
        if (clientUid != null && clientUid.isNotEmpty) {
          await sendNotification(
              recipientUserId: clientUid,
              title: '⚠ تحديث في مشروعك: $projectNameVal',
              body: 'تم إعادة فتح المرحلة "$phaseName" في مشروعك "$projectNameVal" للمراجعة أو التعديل. سيتم تزويدك بالتفاصيل قريباً.',
              type: 'phase_reverted_for_client',
              projectId: widget.projectId,
              itemId: phaseId,
              senderName: actorName
          );
        }
      }
      // --- ADDITION END ---
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة "$phaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة: $e', isError: true);
    }
  }
  // --- MODIFICATION END ---

  // --- MODIFICATION START: _updateSubPhaseCompletionStatus - Send notifications ---
  // lib/pages/admin/admin_project_details_page.dart
// ... (الكود السابق للدالة)

  Future<void> _updateSubPhaseCompletionStatus(String mainPhaseId, String subPhaseId, String subPhaseName, bool newStatus) async {
    if (!mounted) return;
    try {
      final subPhaseDocRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('subphases_status')
          .doc(subPhaseId);

      final currentUser = FirebaseAuth.instance.currentUser;
      String actorName = _currentAdminName ?? "المسؤول";

      await subPhaseDocRef.set({
        'completed': newStatus,
        'mainPhaseId': mainPhaseId,
        'name': subPhaseName,
        'lastUpdatedByUid': currentUser?.uid,
        'lastUpdatedByName': actorName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // --- ADDITION START: Send notifications for sub-phase completion (Admin) ---
      if (newStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) {
        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
        if (projectData == null) return;

        final projectNameVal = projectData['name'] ?? 'المشروع';
        final clientUid = projectData['clientId'] as String?;
        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
        final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

        // إشعار للمهندسين المعينين
        if (assignedEngineerUids.isNotEmpty) {
          await sendNotificationsToMultiple(
              recipientUserIds: assignedEngineerUids,
              title: 'تحديث مرحلة مشروع: $projectNameVal',
              body: 'المرحلة الفرعية "$subPhaseName" في مشروع "$projectNameVal" أصبحت مكتملة (بواسطة المسؤول $actorName).',
              type: 'subphase_update_by_admin',
              projectId: widget.projectId,
              itemId: subPhaseId, // Use subPhaseId as itemId
              senderName: actorName
          );
        }
        // إشعار للعميل
        if (clientUid != null && clientUid.isNotEmpty) {
          await sendNotification(
              recipientUserId: clientUid,
              title: '✅ تحديث جديد في مشروعك: $projectNameVal',
              body: 'العمل يتقدم! تم إكمال المرحلة الفرعية "$subPhaseName" في مشروعك "$projectNameVal".',
              type: 'subphase_completed_for_client',
              projectId: widget.projectId,
              itemId: subPhaseId, // Use subPhaseId as itemId
              senderName: actorName
          );
        }
      } else if (!newStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) { // إشعار عند إلغاء اكتمال المرحلة
        final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
        if (projectData == null) return;

        final projectNameVal = projectData['name'] ?? 'المشروع';
        final clientUid = projectData['clientId'] as String?;
        final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
        final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

        // إشعار للمهندسين المعينين
        if (assignedEngineerUids.isNotEmpty) {
          await sendNotificationsToMultiple(
              recipientUserIds: assignedEngineerUids,
              title: 'تراجع عن اكتمال مرحلة: $projectNameVal',
              body: 'قام المسؤول $actorName بتغيير حالة المرحلة الفرعية "$subPhaseName" في مشروع "$projectNameVal" إلى "قيد التنفيذ".',
              type: 'subphase_reverted_by_admin',
              projectId: widget.projectId,
              itemId: subPhaseId,
              senderName: actorName
          );
        }
        // إشعار للعميل
        if (clientUid != null && clientUid.isNotEmpty) {
          await sendNotification(
              recipientUserId: clientUid,
              title: '⚠ تحديث في مشروعك: $projectNameVal',
              body: 'تم إعادة فتح المرحلة الفرعية "$subPhaseName" في مشروعك "$projectNameVal" للمراجعة أو التعديل.',
              type: 'subphase_reverted_for_client',
              projectId: widget.projectId,
              itemId: subPhaseId,
              senderName: actorName
          );
        }
      }
      // --- ADDITION END ---
      _showFeedbackSnackBar(context, 'تم تحديث حالة المرحلة الفرعية "$subPhaseName".', isError: false);
    } catch (e) {
      _showFeedbackSnackBar(context, 'فشل تحديث حالة المرحلة الفرعية: $e', isError: true);
    }
  }
  // --- MODIFICATION END ---

  // --- MODIFICATION START: _updateTestStatus - Send notifications ---
  Future<void> _updateTestStatus(String testId, String testName, bool newStatus, {String? currentNote, String? currentImageUrl}) async {
    if (!mounted) return;

    final noteController = TextEditingController(text: currentNote ?? "");
    String? tempImageUrl = currentImageUrl;
    File? pickedImageFile;
    bool isUploadingDialog = false;

    final currentUser = FirebaseAuth.instance.currentUser;
    String actorName = _currentAdminName ?? "المسؤول";

    bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: !isUploadingDialog,
        builder: (dialogContext) {
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
                        value: dialogNewStatus,
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
                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppConstants.primaryColor),
                        label: Text(pickedImageFile == null && tempImageUrl == null ? 'إضافة صورة (اختياري)' : (pickedImageFile == null ? 'تغيير الصورة الحالية' : 'تغيير الصورة المختارة'), style: const TextStyle(color: AppConstants.primaryColor)),
                        onPressed: () {
                          _showSingleImageSourceActionSheet(context, (xFile) {
                            if (xFile != null) {
                              setDialogState(() {
                                pickedImageFile = File(xFile.path);
                              });
                            }
                          });
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
                          final refPath = 'project_tests/${widget.projectId}/$testId/${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final ref = FirebaseStorage.instance.ref().child(refPath);
                          await ref.putFile(pickedImageFile!);
                          finalImageUrl = await ref.getDownloadURL();
                        } catch (e) {
                          if(mounted) _showFeedbackSnackBar(stfContext, 'فشل رفع صورة الاختبار: $e', isError: true);
                          setDialogState(() => isUploadingDialog = false);
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
                          'completed': dialogNewStatus,
                          'name': testName,
                          'note': noteController.text.trim(),
                          'imageUrl': finalImageUrl,
                          'lastUpdatedByUid': currentUser?.uid,
                          'lastUpdatedByName': actorName,
                          'lastUpdatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                        if (dialogNewStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) { // الإشعار فقط عند اكتمال الاختبار
                          final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
                          if (projectData == null) return;

                          final projectNameVal = projectData['name'] ?? 'المشروع';
                          final clientUid = projectData['clientId'] as String?;
                          final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
                          final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

                          // إشعار للمهندسين المعينين
                          if (assignedEngineerUids.isNotEmpty) {
                            await sendNotificationsToMultiple(
                                recipientUserIds: assignedEngineerUids,
                                title: 'تحديث اختبار مشروع: $projectNameVal',
                                body: 'قام المسؤول $actorName بإكمال الاختبار "$testName" في مشروع "$projectNameVal".',
                                type: 'test_update_by_admin',
                                projectId: widget.projectId,
                                itemId: testId,
                                senderName: actorName
                            );
                          }
                          // إشعار للعميل
                          if (clientUid != null && clientUid.isNotEmpty) {
                            await sendNotification(
                                recipientUserId: clientUid,
                                title: '🚀 تقدم رائع في مشروعك: $projectNameVal',
                                body: 'لقد اجتاز مشروعك اختبار "$testName" بنجاح! نواصل العمل بجد لتحقيق أفضل النتائج.',
                                type: 'test_completed_for_client',
                                projectId: widget.projectId,
                                itemId: testId,
                                senderName: actorName
                            );
                          }
                        } else if (!dialogNewStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) { // إشعار عند إلغاء اكتمال الاختبار
                          final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>?;
                          if (projectData == null) return;

                          final projectNameVal = projectData['name'] ?? 'المشروع';
                          final clientUid = projectData['clientId'] as String?;
                          final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
                          final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

                          // إشعار للمهندسين المعينين
                          if (assignedEngineerUids.isNotEmpty) {
                            await sendNotificationsToMultiple(
                                recipientUserIds: assignedEngineerUids,
                                title: 'تراجع عن اكتمال اختبار: $projectNameVal',
                                body: 'قام المسؤول $actorName بتغيير حالة الاختبار "$testName" في مشروع "$projectNameVal" إلى "قيد التنفيذ".',
                                type: 'test_reverted_by_admin',
                                projectId: widget.projectId,
                                itemId: testId,
                                senderName: actorName
                            );
                          }
                          // إشعار للعميل
                          if (clientUid != null && clientUid.isNotEmpty) {
                            await sendNotification(
                                recipientUserId: clientUid,
                                title: '⚠ تحديث في مشروعك: $projectNameVal',
                                body: 'تم إعادة فتح اختبار "$testName" في مشروعك "$projectNameVal" للمراجعة أو التعديل.',
                                type: 'test_reverted_for_client',
                                projectId: widget.projectId,
                                itemId: testId,
                                senderName: actorName
                            );
                          }
                        }

                        // --- Notification Logic for Admin Updating Test ---
                        if (dialogNewStatus && _projectDataSnapshot != null && _projectDataSnapshot!.exists) { // Only notify on completion
                          final projectData = _projectDataSnapshot!.data() as Map<String, dynamic>;
                          final projectNameVal = projectData['name'] ?? 'المشروع';
                          final clientUid = projectData['clientId'] as String?;
                          final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
                          final List<String> assignedEngineerUids = assignedEngineersRaw.map((e) => Map<String,dynamic>.from(e)['uid'].toString()).toList();

                          // Notify Assigned Engineers
                          if (assignedEngineerUids.isNotEmpty) {
                            await sendNotificationsToMultiple(
                                recipientUserIds: assignedEngineerUids,
                                title: 'تحديث اختبار مشروع: $projectNameVal',
                                body: 'الاختبار "$testName" في مشروع "$projectNameVal" أصبح مكتملًا (بواسطة المسؤول).',
                                type: 'test_update_by_admin',
                                projectId: widget.projectId,
                                itemId: testId,
                                senderName: actorName
                            );
                          }
                          // Notify Client
                          if (clientUid != null && clientUid.isNotEmpty) {
                            await sendNotification(
                                recipientUserId: clientUid,
                                title: 'تحديث مشروعك: $projectNameVal',
                                body: 'الاختبار "$testName" في مشروعك "$projectNameVal" أصبح مكتملًا.',
                                type: 'test_completed_for_client',
                                projectId: widget.projectId,
                                itemId: testId,
                                senderName: actorName
                            );
                          }
                        }
                        // --- End Notification Logic ---

                        if(mounted) Navigator.pop(dialogContext, true);
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
  }
  // --- MODIFICATION END ---


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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(projectDataMap),
                  _buildPhasesTab(),
                  _buildTestsTab(),
                  _buildPartRequestsTab(),
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
        if (_readMore && widget.text.length > endIndex && endIndex > 0) { // Added checks for endIndex
          textSpan = TextSpan(
            text: widget.text.substring(0, endIndex) + "...",
            style: TextStyle(fontSize: 14.5, color: widget.valueColor ?? AppConstants.textSecondary, height: 1.5),
            children: <TextSpan>[link], // Removed const TextSpan(text: "... ")
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