// lib/pages/client/client_home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:engineer_management_system/theme/app_constants.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:ui' as ui; // For TextDirection

import 'dart:async'; // تم إضافة هذا الاستيراد للـ StreamSubscription


class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> with TickerProviderStateMixin {
  final String? _currentClientUid = FirebaseAuth.instance.currentUser?.uid;
  String? _clientName;
  bool _isLoading = true;
  late TabController _tabController;

  int _unreadNotificationsCount = 0;
  StreamSubscription? _notificationsSubscription; // تم إضافة هذا الاستيراد

  static const List<Map<String, dynamic>> predefinedPhasesStructure = [
    // ... (قائمة المراحل كما هي في الكود الأصلي)
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
        {'id': 'sub_09_09', 'name': 'تركيب رداد ٤ إنش'},
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

    // ... more test sections
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
    _tabController = TabController(length: 3, vsync: this);
    if (_currentClientUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logout(showConfirmation: false);
      });
    } else {
      _fetchClientData();
      _listenForUnreadNotifications(); // ابدأ الاستماع للإشعارات
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationsSubscription?.cancel(); // إلغاء الاشتراك عند التخلص من الويدجت
    super.dispose();
  }

  // دالة جديدة للاستماع لعدد الإشعارات غير المقروءة
  void _listenForUnreadNotifications() {
    if (_currentClientUid == null) return;
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: _currentClientUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _fetchClientData() async {
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

  Future<void> _logout({bool showConfirmation = true}) async {
    if (showConfirmation) {
      final bool? confirmed = await _showLogoutConfirmationDialog();
      if (confirmed != true) return;
    }

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

  Future<bool?> _showLogoutConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            title: const Text(
              'تأكيد تسجيل الخروج',
              style: TextStyle(
                color: AppConstants.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
              style: TextStyle(color: AppConstants.textSecondary, fontSize: 16),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium,
                    vertical: AppConstants.paddingSmall,
                  ),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: AppConstants.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium,
                    vertical: AppConstants.paddingSmall,
                  ),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          ),
        );
      },
    );
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
                ? ExpandableText(value, valueColor: valueColor)
                : Text(
              value,
              style: TextStyle(fontSize: 15, color: valueColor ?? AppConstants.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: isExpandable ? null : 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppConstants.textSecondary)),
          const SizedBox(height: AppConstants.paddingSmall / 2),
          InkWell(
            onTap: () => _viewImageDialog(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2),
              child: Image.network(
                imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 150, alignment: Alignment.center, child: const CircularProgressIndicator(color: AppConstants.primaryColor)),
                errorBuilder: (ctx, err, st) => Container(height: 150, width: double.infinity, color: AppConstants.backgroundColor, child: const Icon(Icons.broken_image_outlined, color: AppConstants.textSecondary, size: 40)),
              ),
            ),
          ),
        ],
      ),
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
        Stack( // استخدام Stack لوضع العداد فوق الأيقونة
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              tooltip: 'الإشعارات',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            if (_unreadNotificationsCount > 0) // عرض العداد فقط إذا كان هناك إشعارات غير مقروءة
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppConstants.errorColor, // لون أحمر مميز
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1), // حدود بيضاء
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _unreadNotificationsCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
          ],
        ),
        IconButton(
          icon: const Icon(Icons.event_available, color: Colors.white),
          tooltip: 'الحجوزات',
          onPressed: () => Navigator.pushNamed(context, '/bookings'),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'change_password':
                Navigator.pushNamed(context, '/client/change_password');
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'change_password',
              child: Row(
                children: [
                  Icon(Icons.lock_reset, color: AppConstants.primaryColor),
                  SizedBox(width: 8),
                  Text('تغيير كلمة المرور'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppConstants.errorColor),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج', style: TextStyle(color: AppConstants.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'مراحل المشروع', icon: Icon(Icons.stairs_outlined)),
          Tab(text: 'الاختبارات النهائية', icon: Icon(Icons.checklist_rtl_rounded)),
          Tab(text: 'طلبات المواد', icon: Icon(Icons.build_circle_outlined)),
        ],
      ),
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
            Text('الرجاء التواصل مع إدارة المشروع لمزيد من المعلومات.', style: TextStyle(fontSize: 14, color: AppConstants.textSecondary.withOpacity(0.7)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // === إضافة دالة build هنا ===
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
        appBar: _buildAppBar(), // AppBar now includes TabBar
        body: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('projects').where('clientId', isEqualTo: _currentClientUid).limit(1).get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
            }
            if (projectSnapshot.hasError) {
              return _buildErrorState('حدث خطأ في تحميل بيانات المشروع: ${projectSnapshot.error}');
            }
            if (!projectSnapshot.hasData || projectSnapshot.data!.docs.isEmpty) {
              return _buildEmptyState('لم يتم ربط حسابك بأي مشروع حتى الآن.');
            }

            final projectDoc = projectSnapshot.data!.docs.first;
            final projectId = projectDoc.id;
            final projectData = projectDoc.data() as Map<String, dynamic>;

            return Column( // Wrap content in Column to place TabBarView below summary
              children: [
                Padding( // Add padding for the summary card
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: _buildProjectSummaryCard(projectData),
                ),
                Expanded( // TabBarView should take remaining space
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildClientPhasesTab(projectId),
                      _buildClientTestsTab(projectId),
                      _buildClientPartRequestsTab(projectId),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  // === نهاية دالة build ===

  Widget _buildProjectSummaryCard(Map<String, dynamic> projectData) {
    final projectName = projectData['name'] ?? 'مشروع غير مسمى';
    // Assuming 'assignedEngineers' is a list of maps like [{'name': 'Eng A'}, {'name': 'Eng B'}]
    final List<dynamic> assignedEngineersRaw = projectData['assignedEngineers'] as List<dynamic>? ?? [];
    String engineerName = "غير محدد";
    if (assignedEngineersRaw.isNotEmpty) {
      engineerName = assignedEngineersRaw.map((eng) => eng['name'] ?? 'م.غير معروف').join('، ');
    }

    final projectStatus = projectData['status'] ?? 'غير محدد';
    final generalNotes = projectData['generalNotes'] ?? '';
    final currentStageNumber = projectData['currentStage'] ?? 0;
    final currentPhaseName = projectData['currentPhaseName'] ?? 'غير محددة';

    IconData statusIcon;
    Color statusColor;
    switch (projectStatus) {
      case 'نشط': statusIcon = Icons.construction_rounded; statusColor = AppConstants.infoColor; break;
      case 'مكتمل': statusIcon = Icons.check_circle_outline_rounded; statusColor = AppConstants.successColor; break;
      case 'معلق': statusIcon = Icons.pause_circle_outline_rounded; statusColor = AppConstants.warningColor; break;
      default: statusIcon = Icons.help_outline_rounded; statusColor = AppConstants.textSecondary;
    }

    return Card(
      elevation: AppConstants.cardShadow.isNotEmpty
          ? AppConstants.cardShadow.first.blurRadius
          : 0,
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
            // _buildDetailRow(Icons.stairs_rounded, 'المرحلة الحالية:', '$currentStageNumber - $currentPhaseName'),
            if (generalNotes.isNotEmpty) ...[
              const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
              _buildDetailRow(Icons.speaker_notes_rounded, 'ملاحظات عامة من المهندس:', generalNotes, isExpandable: true),
            ],
          ],
        ),
      ),
    );
  }

  // Placeholder - Implement this based on AdminProjectDetailsPage logic (read-only)
  // Show only completed phases for the client
  Widget _buildClientPhasesTab(String projectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('phases_status')
          .where('completed', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ في تحميل المراحل المكتملة.');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد مهام أو مراحل مكتملة بعد.', icon: Icons.checklist_rtl_rounded);
        }

        final completedDocs = snapshot.data!.docs;
        final Map<String, Map<String, dynamic>> completedMap = {
          for (var doc in completedDocs) doc.id: doc.data() as Map<String, dynamic>
        };

        final List<Map<String, dynamic>> phasesToShow = [];
        for (var phase in predefinedPhasesStructure) {
          final id = phase['id'] as String;
          if (completedMap.containsKey(id)) {
            phasesToShow.add({...phase, 'status': completedMap[id]});
          }
        }

        return ListView.builder(
          key: const PageStorageKey<String>('clientPhasesTab'),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          itemCount: phasesToShow.length,
          itemBuilder: (context, index) {
            final phaseStructure = phasesToShow[index];
            final phaseId = phaseStructure['id'] as String;
            final statusData = phaseStructure['status'] as Map<String, dynamic>?;
            final phaseName = statusData?['name'] ?? phaseStructure['name'] as String;
            final subPhasesStructure = phaseStructure['subPhases'] as List<Map<String, dynamic>>;
            final lastUpdatedBy = statusData?['lastUpdatedByName'] ?? 'غير معروف';

            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
              child: ExpansionTile(
                key: PageStorageKey<String>(phaseId),
                leading: CircleAvatar(
                  backgroundColor: AppConstants.successColor,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(phaseName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                subtitle: Text('مكتملة بواسطة: $lastUpdatedBy ✅', style: const TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.w500)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingSmall).copyWith(right: AppConstants.paddingMedium + 8, left: AppConstants.paddingSmall),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEntriesListForClient(projectId, phaseId, isSubEntry: false),
                        if (subPhasesStructure.isNotEmpty)
                          const Divider(height: AppConstants.itemSpacing, thickness: 0.5),
                      ],
                    ),
                  ),
                  if (subPhasesStructure.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: AppConstants.paddingLarge, left: AppConstants.paddingSmall, bottom: AppConstants.paddingSmall),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppConstants.paddingSmall / 2),
                            child: Text('المراحل الفرعية:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                          ),
                          ...subPhasesStructure.map((subPhaseMap) {
                            final subPhaseId = subPhaseMap['id'] as String;
                            final subPhaseName = subPhaseMap['name'] as String;
                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('projects')
                                  .doc(projectId)
                                  .collection('subphases_status')
                                  .doc(subPhaseId)
                                  .snapshots(),
                              builder: (context, subPhaseStatusSnapshot) {
                                if (subPhaseStatusSnapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox.shrink();
                                }
                                if (!subPhaseStatusSnapshot.hasData || !subPhaseStatusSnapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                final subStatusData = subPhaseStatusSnapshot.data!.data() as Map<String, dynamic>;
                                if (subStatusData['completed'] != true) {
                                  return const SizedBox.shrink();
                                }
                                final subLastUpdatedBy = subStatusData['lastUpdatedByName'] ?? 'غير معروف';
                                final subPhaseActualName = subStatusData['name'] ?? subPhaseName;

                                return Card(
                                  elevation: 0.2,
                                  color: AppConstants.backgroundColor,
                                  margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
                                  child: ExpansionTile(
                                    key: PageStorageKey<String>('sub_$subPhaseId'),
                                    leading: const Icon(Icons.check_box_rounded, color: AppConstants.successColor, size: 20),
                                    title: Text(subPhaseActualName, style: const TextStyle(fontSize: 13.5, color: AppConstants.textSecondary)),
                                    subtitle: Text('مكتملة بواسطة: $subLastUpdatedBy', style: const TextStyle(fontSize: 11, color: AppConstants.successColor)),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: AppConstants.paddingSmall, right: AppConstants.paddingMedium + 8, bottom: AppConstants.paddingSmall, top: 0),
                                        child: _buildEntriesListForClient(projectId, phaseId, subPhaseId: subPhaseId, isSubEntry: true),
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
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
  Widget _buildEntriesListForClient(String projectId, String mainPhaseId, {String? subPhaseId, bool isSubEntry = false}) {
    String entriesCollectionPath = subPhaseId == null
        ? 'projects/$projectId/phases_status/$mainPhaseId/entries'
        : 'projects/$projectId/subphases_status/$subPhaseId/entries';

    // إضافة ScrollController هنا
    final ScrollController listViewController = ScrollController(keepScrollOffset: false);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(entriesCollectionPath).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall /2),
            child: Text(isSubEntry ? 'لا توجد ملاحظات أو صور لهذه المرحلة الفرعية.' : 'لا توجد ملاحظات أو صور لهذه المرحلة.', style: const TextStyle(color: AppConstants.textSecondary, fontStyle: FontStyle.italic, fontSize: 12)),
          );
        }
        final entries = snapshot.data!.docs;
        return ListView.builder(
          // --- بداية التعديل ---
          controller: listViewController, // استخدام الـ ScrollController المُعرف
          // --- نهاية التعديل ---
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entryData = entries[index].data() as Map<String, dynamic>;
            final String note = entryData['note'] ?? '';
            // التعامل مع كلا الحقلين imageUrl (مفرد) و imageUrls (قائمة) كما في صفحة المسؤول
            final List<String> imageUrlsToDisplay = [];
            final dynamic imagesField = entryData['imageUrls'];
            final dynamic singleImageField = entryData['imageUrl'];

            if (imagesField is List) {
              imageUrlsToDisplay.addAll(imagesField.map((e) => e.toString()).toList());
            } else if (singleImageField is String && singleImageField.isNotEmpty) {
              imageUrlsToDisplay.add(singleImageField);
            }

            final String engineerName = entryData['engineerName'] ?? 'مهندس';
            final Timestamp? timestamp = entryData['timestamp'] as Timestamp?;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عرض الصور المتعددة إذا وجدت
                  if (imageUrlsToDisplay.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: note.isNotEmpty ? AppConstants.paddingSmall / 2 : 0),
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
                                height: 80, // حجم أصغر للمعاينة في قائمة العميل
                                width: 80,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) => progress == null
                                    ? child
                                    : Container(height: 80, width: 80, alignment: Alignment.center, child: const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryLight))),
                                errorBuilder: (c, e, s) => Container(height: 80, width: 80, color: AppConstants.backgroundColor.withOpacity(0.5), child: Center(child: Icon(Icons.broken_image_outlined, color: AppConstants.textSecondary.withOpacity(0.7), size: 25))),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: imageUrlsToDisplay.isNotEmpty ? AppConstants.paddingSmall/2 : 0),
                      child: ExpandableText("ملاحظة المهندس: $note", valueColor: AppConstants.textPrimary, trimLines: 2),
                    ),
                  if (imageUrlsToDisplay.isNotEmpty || note.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        'بواسطة: $engineerName ${timestamp != null ? "- " + DateFormat('dd/MM/yy', 'ar').format(timestamp.toDate()) : ''}',
                        style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (index < entries.length -1) const Divider(height: AppConstants.paddingSmall, thickness: 0.3),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // Placeholder - Implement this based on AdminProjectDetailsPage logic (read-only)

  Widget _buildClientTestsTab(String projectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('tests_status')
          .where('completed', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ في تحميل الاختبارات المكتملة.');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد اختبارات مكتملة بعد.', icon: Icons.check_circle_outline_rounded);
        }

        final completedDocs = snapshot.data!.docs;
        final Map<String, Map<String, dynamic>> completedMap = {
          for (var doc in completedDocs) doc.id: doc.data() as Map<String, dynamic>
        };

        final sectionsToShow = <Map<String, dynamic>>[];
        for (var section in finalCommissioningTests) {
          final tests = <Map<String, dynamic>>[];
          for (var test in section['tests'] as List<Map<String, dynamic>>) {
            final id = test['id'] as String;
            if (completedMap.containsKey(id)) {
              tests.add({...test, 'status': completedMap[id]});
            }
          }
          if (tests.isNotEmpty) {
            sectionsToShow.add({'section_name': section['section_name'], 'tests': tests});
          }
        }

        return ListView.builder(
          key: const PageStorageKey<String>('clientTestsTab'),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          itemCount: sectionsToShow.length,
          itemBuilder: (context, sectionIndex) {
            final section = sectionsToShow[sectionIndex];
            final sectionName = section['section_name'] as String;
            final tests = section['tests'] as List<Map<String, dynamic>>;

            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
              child: ExpansionTile(
                key: PageStorageKey<String>(sectionName),
                title: Text(sectionName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                childrenPadding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: AppConstants.paddingSmall / 2),
                children: tests.map((test) {
                  final testId = test['id'] as String;
                  final testName = test['name'] as String;
                  final statusData = test['status'] as Map<String, dynamic>;
                  final testNote = statusData['note'] ?? '';
                  final testImageUrl = statusData['imageUrl'] as String?;
                  final engineerName = statusData['lastUpdatedByName'] as String?;

                  return ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 20),
                    title: Text(testName, style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (engineerName != null && engineerName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text('بواسطة: $engineerName', style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontStyle: FontStyle.italic)),
                          ),
                        if (testNote.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: ExpandableText('ملاحظة: $testNote', valueColor: AppConstants.infoColor, trimLines: 1),
                          ),
                        if (testImageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: InkWell(
                              onTap: () => _viewImageDialog(testImageUrl),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_outlined, size: 14, color: AppConstants.primaryLight),
                                  SizedBox(width: 2),
                                  Text('عرض الصورة', style: TextStyle(fontSize: 11, color: AppConstants.primaryLight, decoration: TextDecoration.underline)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
  // Placeholder - Implement to show part requests related to the project
  Widget _buildClientPartRequestsTab(String projectId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partRequests')
          .where('projectId', isEqualTo: projectId) // Filter by project ID
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        }
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ في تحميل طلبات المواد: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('لا توجد طلبات مواد لهذا المشروع حالياً.', icon: Icons.construction_rounded);
        }

        final requests = snapshot.data!.docs;
        return ListView.builder(
          key: const PageStorageKey<String>('clientPartRequestsTab'),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestDoc = requests[index];
            final data = requestDoc.data() as Map<String, dynamic>;
            final partName = data['partName'] ?? 'مادة غير مسماة';
            final quantity = data['quantity']?.toString() ?? 'N/A';
            final engineerName = data['engineerName'] ?? 'مهندس غير معروف';
            final status = data['status'] ?? 'غير معروف';
            final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
            final formattedDate = requestedAt != null
                ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(requestedAt)
                : 'غير معروف';

            Color statusColor;
            IconData statusIcon;
            switch (status) {
              case 'معلق': statusColor = AppConstants.warningColor; statusIcon = Icons.pending_actions_rounded; break;
              case 'تمت الموافقة': statusColor = AppConstants.successColor; statusIcon = Icons.check_circle_outline_rounded; break;
              case 'مرفوض': statusColor = AppConstants.errorColor; statusIcon = Icons.cancel_outlined; break;
              case 'تم الطلب': statusColor = AppConstants.infoColor; statusIcon = Icons.shopping_cart_checkout_rounded; break;
              case 'تم الاستلام': statusColor = AppConstants.primaryColor; statusIcon = Icons.inventory_2_outlined; break;
              default: statusColor = AppConstants.textSecondary; statusIcon = Icons.help_outline_rounded;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.itemSpacing),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 1.5)),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium / 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('اسم المادة: $partName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                    const SizedBox(height: AppConstants.paddingSmall / 2),
                    Text('الكمية: $quantity', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                    Text('مقدم الطلب: $engineerName', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                    Row(
                      children: [
                        // Text('الحالة: ', style: const TextStyle(fontSize: 14, color: AppConstants.textSecondary)),
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(status, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text('تاريخ الطلب: $formattedDate', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary.withOpacity(0.8))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // This was the old method, no longer directly used for the main body but kept for reference
  // if you want to re-introduce a specific list of completed phases elsewhere.
  Widget _buildCompletedPhasesList(String projectId) {
    return StreamBuilder<QuerySnapshot>(
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
          return _buildEmptyState('لا توجد مراحل مكتملة لعرضها حالياً.', icon: Icons.checklist_rtl_rounded);
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
            final name = data['name'] ?? 'مرحلة غير مسمى';
            final note = data['note'] ?? '';
            final imageUrl = data['imageUrl'] as String?;
            final image360Url = data['image360Url'] as String?;
            final hasSubPhases = data['hasSubPhases'] ?? false;

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
                        if (hasSubPhases) _buildCompletedSubPhasesList(projectId, phase.id),
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
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('projects').doc(projectId).collection('phases').doc(phaseId)
              .collection('subPhases').where('completed', isEqualTo: true).orderBy('timestamp').snapshots(),
          builder: (context, subPhaseSnapshot) {
            if (subPhaseSnapshot.connectionState == ConnectionState.waiting) return const Center(child: SizedBox(height:25, width:25, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryColor)));
            if (subPhaseSnapshot.hasError) return Text('خطأ: ${subPhaseSnapshot.error}', style: const TextStyle(color: AppConstants.errorColor));
            if (!subPhaseSnapshot.hasData || subPhaseSnapshot.data!.docs.isEmpty) return const Text('لا توجد مراحل فرعية مكتملة.', style: TextStyle(color: AppConstants.textSecondary));

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

                return Card(
                  elevation: 0.5,
                  color: AppConstants.successColor.withOpacity(0.03),
                  margin: const EdgeInsets.symmetric(vertical: AppConstants.paddingSmall / 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius / 2)),
                  child: ExpansionTile(
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
                      _buildImageSection('صورة فرعية عادية:', subImageUrl),
                      _buildImageSection('صورة فرعية 360°:', subImage360Url),
                      if (subNote.isEmpty && (subImageUrl == null || subImageUrl.isEmpty) && (subImage360Url == null || subImage360Url.isEmpty))
                        const Text('لا توجد تفاصيل إضافية لهذه المرحلة الفرعية.', style: TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
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
            text: _readMore && widget.text.length > endIndex && endIndex > 0 ? widget.text.substring(0, endIndex) + "..." : widget.text,
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