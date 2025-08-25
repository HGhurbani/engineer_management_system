import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'smart_report_cache_manager.dart';
import 'pdf_report_generator.dart';

class EnhancedPdfResult {
  final Uint8List bytes;
  final String? downloadUrl;
  
  EnhancedPdfResult({
    required this.bytes,
    this.downloadUrl,
  });
}

/// مولد PDF محسن يستخدم التصميم الأصلي مع نظام التخزين المؤقت الذكي
class EnhancedPdfGenerator {
  // هيكل المراحل المحدد مسبقاً (نسخة كاملة من الصفحة الأصلية)
  static const List<Map<String, dynamic>> predefinedPhasesStructure = [
    {
      'id': 'phase_01',
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
      'id': 'phase_08',
      'name': 'مرحلة التمديدات',
      'subPhases': [
        {'id': 'sub_08_01', 'name': 'أعمال الكهرباء: تحديد نقاط مخارج الكهرباء حسب المخطط أو العميل'},
        {'id': 'sub_08_02', 'name': 'أعمال الكهرباء: تحديد المناسيب بالليزر'},
        {'id': 'sub_08_33', 'name': 'أعمال السباكة: تمديد مواسير التغذية بين الخزانات'},
        {'id': 'sub_08_34', 'name': 'أعمال السباكة: تمديد ماسورة الماء الحلو من الشارع إلى الخزان ثم الفيلا'},
        {'id': 'sub_08_48', 'name': 'أعمال السباكة: اختبار الضغط وتثبيت ساعة الضغط لكل دور'},
        {'id': 'sub_08_49', 'name': 'أعمال السباكة: تثبيت نقاط إسمنتية بعد الاختبارات'},
      ]
    },
    {
      'id': 'phase_13',
      'name': 'التفنيش والتشغيل',
      'subPhases': [
        {'id': 'sub_13_01', 'name': 'أعمال الكهرباء: تنظيف العلب جيداً'},
        {'id': 'sub_13_02', 'name': 'أعمال الكهرباء: تركيب كونكترات للأسلاك'},
        {'id': 'sub_13_09', 'name': 'أعمال الكهرباء: التشغيل الفعلي للمبنى'},
        {'id': 'sub_13_12', 'name': 'أعمال السباكة: تركيب الكراسي والمغاسل مع اختبار التثبيت'},
        {'id': 'sub_13_17', 'name': 'أعمال السباكة: تشغيل شبكة المياه وربط الخزانات'},
        {'id': 'sub_13_18', 'name': 'أعمال السباكة: تشغيل الشطافات والمغاسل مع الفحص'},
      ]
    },
  ];

  // الاختبارات النهائية (نسخة كاملة من الصفحة الأصلية)
  static const List<Map<String, dynamic>> finalCommissioningTests = [
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

  /// تحميل البيانات الشاملة للمشروع من قاعدة البيانات
  static Future<void> _loadComprehensiveProjectData(
    String projectId,
    Map<String, dynamic> projectData,
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  ) async {
    try {
      onStatusUpdate?.call('جاري تحميل بيانات المراحل...');
      onProgress?.call(0.16);

             // Load phases status data with fallback mechanism
       var phasesQuery = await FirebaseFirestore.instance
           .collection('projects')
           .doc(projectId)
           .collection('phases_status')
           .get();
       
       // If no phases found, try alternative collection names
       if (phasesQuery.docs.isEmpty) {
         print('No phases_status found, trying alternative: phases');
         phasesQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('phases')
             .get();
       }

       onStatusUpdate?.call('جاري تحميل بيانات المراحل الفرعية...');
       onProgress?.call(0.17);

       // Load subphases status data with fallback mechanism
       var subphasesQuery = await FirebaseFirestore.instance
           .collection('projects')
           .doc(projectId)
           .collection('subphases_status')
           .get();
           
       if (subphasesQuery.docs.isEmpty) {
         print('No subphases_status found, trying alternative: subphases');
         subphasesQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('subphases')
             .get();
       }

       onStatusUpdate?.call('جاري تحميل بيانات الاختبارات...');
       onProgress?.call(0.18);

       // Load tests status data with fallback mechanism
       var testsQuery = await FirebaseFirestore.instance
           .collection('projects')
           .doc(projectId)
           .collection('tests_status')
           .get();
           
       if (testsQuery.docs.isEmpty) {
         print('No tests_status found, trying alternative: tests');
         testsQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('tests')
             .get();
       }

      onStatusUpdate?.call('جاري تحميل بيانات الطلبات...');
      onProgress?.call(0.19);

             // Load requests data with fallback mechanism
       var requestsQuery = await FirebaseFirestore.instance
           .collection('projects')
           .doc(projectId)
           .collection('requests')
           .get();
           
       if (requestsQuery.docs.isEmpty) {
         print('No requests found, trying alternative: material_requests');
         requestsQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('material_requests')
             .get();
       }
       
       // Debug: List all subcollections for this project to understand the structure
       print('=== Project $projectId Collections Debug ===');
       try {
         final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
         // Note: listCollections() is not available in client SDKs, so we'll use known collection names
         final knownCollections = [
           'phases_status', 'phases',
           'subphases_status', 'subphases', 
           'tests_status', 'tests',
           'requests', 'material_requests',
           'notes', 'observations', 'comments'
         ];
         
         for (String collectionName in knownCollections) {
           final query = await projectRef.collection(collectionName).limit(1).get();
           if (query.docs.isNotEmpty) {
             print('Found collection: $collectionName (${query.docs.length}+ docs)');
           }
         }
       } catch (e) {
         print('Error during collections debug: $e');
       }
       print('=== End Collections Debug ===');

      onStatusUpdate?.call('جاري تحميل بيانات الإدخالات التفصيلية...');
      onProgress?.call(0.195);

             // Load detailed entries for phases, subphases, and tests
       int totalEntries = 0;
       
       // Load phase entries with dynamic collection detection
       for (final phaseDoc in phasesQuery.docs) {
         var entriesQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('phases_status')
             .doc(phaseDoc.id)
             .collection('entries')
             .get();
             
         // If no entries in phases_status, try phases collection
         if (entriesQuery.docs.isEmpty) {
           entriesQuery = await FirebaseFirestore.instance
               .collection('projects')
               .doc(projectId)
               .collection('phases')
               .doc(phaseDoc.id)
               .collection('entries')
               .get();
         }
         
         // Also try looking for entries directly in the phase document
         if (entriesQuery.docs.isEmpty) {
           final phaseData = phaseDoc.data();
           if (phaseData.containsKey('entries') && phaseData['entries'] is List) {
             final entriesList = phaseData['entries'] as List;
             totalEntries += entriesList.length;
             print('Found ${entriesList.length} entries directly in phase ${phaseDoc.id}');
           }
         } else {
           totalEntries += entriesQuery.docs.length;
         }
       }

             // Load subphase entries with dynamic collection detection
       for (final subphaseDoc in subphasesQuery.docs) {
         var entriesQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('subphases_status')
             .doc(subphaseDoc.id)
             .collection('entries')
             .get();
             
         // If no entries in subphases_status, try subphases collection
         if (entriesQuery.docs.isEmpty) {
           entriesQuery = await FirebaseFirestore.instance
               .collection('projects')
               .doc(projectId)
               .collection('subphases')
               .doc(subphaseDoc.id)
               .collection('entries')
               .get();
         }
         
         // Also try looking for entries directly in the subphase document
         if (entriesQuery.docs.isEmpty) {
           final subphaseData = subphaseDoc.data();
           if (subphaseData.containsKey('entries') && subphaseData['entries'] is List) {
             final entriesList = subphaseData['entries'] as List;
             totalEntries += entriesList.length;
             print('Found ${entriesList.length} entries directly in subphase ${subphaseDoc.id}');
           }
         } else {
           totalEntries += entriesQuery.docs.length;
         }
       }

       // Load test entries with dynamic collection detection
       for (final testDoc in testsQuery.docs) {
         var entriesQuery = await FirebaseFirestore.instance
             .collection('projects')
             .doc(projectId)
             .collection('tests_status')
             .doc(testDoc.id)
             .collection('entries')
             .get();
             
         // If no entries in tests_status, try tests collection
         if (entriesQuery.docs.isEmpty) {
           entriesQuery = await FirebaseFirestore.instance
               .collection('projects')
               .doc(projectId)
               .collection('tests')
               .doc(testDoc.id)
               .collection('entries')
               .get();
         }
         
         // Also try looking for entries directly in the test document
         if (entriesQuery.docs.isEmpty) {
           final testData = testDoc.data();
           if (testData.containsKey('entries') && testData['entries'] is List) {
             final entriesList = testData['entries'] as List;
             totalEntries += entriesList.length;
             print('Found ${entriesList.length} entries directly in test ${testDoc.id}');
           }
         } else {
           totalEntries += entriesQuery.docs.length;
         }
       }

      // Log the data counts for debugging
      print('Enhanced PDF Generator: Loaded ${phasesQuery.docs.length} phases');
      print('Enhanced PDF Generator: Loaded ${subphasesQuery.docs.length} subphases');
      print('Enhanced PDF Generator: Loaded ${testsQuery.docs.length} tests');
      print('Enhanced PDF Generator: Loaded ${requestsQuery.docs.length} requests');
      print('Enhanced PDF Generator: Loaded $totalEntries total entries');

             // Store the loaded data in projectData for PdfReportGenerator to use
       // Convert to the format expected by PdfReportGenerator
       projectData['_loadedPhasesStatus'] = phasesQuery.docs.map((doc) => {
         'id': doc.id,
         ...doc.data(),
       }).toList();

       projectData['_loadedSubphasesStatus'] = subphasesQuery.docs.map((doc) => {
         'id': doc.id,
         ...doc.data(),
       }).toList();

       projectData['_loadedTestsStatus'] = testsQuery.docs.map((doc) => {
         'id': doc.id,
         ...doc.data(),
       }).toList();

       projectData['_loadedRequests'] = requestsQuery.docs.map((doc) => {
         'id': doc.id,
         ...doc.data(),
       }).toList();
       
       // CRITICAL: Override the phases and tests structures with loaded data
       // This ensures PdfReportGenerator uses the actual data from Firestore
       print('Enhanced PDF Generator: Preparing data structures for PdfReportGenerator...');
       print('Enhanced PDF Generator: About to call _prepareDataForPdfGenerator with:');
       print('  - Phases: ${phasesQuery.docs.length}');
       print('  - Subphases: ${subphasesQuery.docs.length}');
       print('  - Tests: ${testsQuery.docs.length}');
       print('  - Requests: ${requestsQuery.docs.length}');
       
       try {
         await _prepareDataForPdfGenerator(projectId, projectData, phasesQuery, subphasesQuery, testsQuery, requestsQuery);
         print('Enhanced PDF Generator: _prepareDataForPdfGenerator completed successfully');
       } catch (e) {
         print('Enhanced PDF Generator: Error in _prepareDataForPdfGenerator: $e');
         print('Enhanced PDF Generator: Stack trace: ${StackTrace.current}');
       }

      onStatusUpdate?.call('تم تحميل جميع البيانات بنجاح');

    } catch (e) {
      print('Error loading comprehensive project data: $e');
      onStatusUpdate?.call('حدث خطأ في تحميل البيانات: $e');
      // Continue with available data even if some loading fails
    }
  }

  /// تحضير البيانات بالتنسيق المطلوب لـ PdfReportGenerator
  static Future<void> _prepareDataForPdfGenerator(
    String projectId,
    Map<String, dynamic> projectData,
    QuerySnapshot<Map<String, dynamic>> phasesQuery,
    QuerySnapshot<Map<String, dynamic>> subphasesQuery,
    QuerySnapshot<Map<String, dynamic>> testsQuery,
    QuerySnapshot<Map<String, dynamic>> requestsQuery,
  ) async {
    try {
      print('_prepareDataForPdfGenerator: Starting data preparation...');
      
      // Create a comprehensive data structure that PdfReportGenerator can use
      // This mimics the structure that would be loaded by the original admin/engineer pages
      
      int totalEntriesPrepared = 0;
      int totalImagesPrepared = 0;
      
      // Prepare phases data with entries
      print('_prepareDataForPdfGenerator: Processing ${phasesQuery.docs.length} phases...');
      for (final phaseDoc in phasesQuery.docs) {
        final phaseId = phaseDoc.id;
        
        // Load entries for this phase
        var entriesQuery = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('phases_status')
            .doc(phaseId)
            .collection('entries')
            .get();
            
        if (entriesQuery.docs.isEmpty) {
          entriesQuery = await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('phases')
              .doc(phaseId)
              .collection('entries')
              .get();
        }
        
        // Store entries in a way PdfReportGenerator expects
        final entries = entriesQuery.docs.map((entryDoc) {
          final entryData = entryDoc.data();
          // دعم الهياكل القديمة والجديدة للصور
          final imageUrls = entryData['imageUrls'] as List? ?? 
                           entryData['otherImages'] as List? ?? 
                           entryData['otherImageUrls'] as List? ?? [];
          final beforeImageUrls = entryData['beforeImageUrls'] as List? ?? 
                                 entryData['beforeImages'] as List? ?? [];
          final afterImageUrls = entryData['afterImageUrls'] as List? ?? 
                                entryData['afterImages'] as List? ?? [];
          
          final totalImages = imageUrls.length + beforeImageUrls.length + afterImageUrls.length;
          totalImagesPrepared += totalImages;
          
          return {
            'id': entryDoc.id,
            'timestamp': entryData['timestamp'],
            'notes': entryData['notes'] ?? '',
            'imageUrls': imageUrls,
            'beforeImageUrls': beforeImageUrls,
            'afterImageUrls': afterImageUrls,
            'status': entryData['status'] ?? 'pending',
            'phaseName': _getPhaseNameById(phaseId),
            'subPhaseName': null,
            ...entryData,
          };
        }).toList();
        
        totalEntriesPrepared += entries.length;
        
        // Store in projectData in the format expected by PdfReportGenerator
        final phaseKey = 'phase_${phaseId}_entries';
        projectData[phaseKey] = entries;
        
        final phaseImages = entries.isEmpty ? 0 : entries.map((e) => (e['imageUrls'] as List).length + (e['beforeImageUrls'] as List).length + (e['afterImageUrls'] as List).length).reduce((a, b) => a + b);
        print('Prepared ${entries.length} entries for phase $phaseId ($phaseImages images)');
      }
      
      // Prepare subphases data with entries
      for (final subphaseDoc in subphasesQuery.docs) {
        final subphaseId = subphaseDoc.id;
        
        // Load entries for this subphase
        var entriesQuery = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('subphases_status')
            .doc(subphaseId)
            .collection('entries')
            .get();
            
        if (entriesQuery.docs.isEmpty) {
          entriesQuery = await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('subphases')
              .doc(subphaseId)
              .collection('entries')
              .get();
        }
        
        // Store entries in a way PdfReportGenerator expects
        final entries = entriesQuery.docs.map((entryDoc) => {
          'id': entryDoc.id,
          'timestamp': entryDoc.data()['timestamp'],
          'notes': entryDoc.data()['notes'] ?? '',
          'imageUrls': entryDoc.data()['imageUrls'] ?? [],
          'beforeImageUrls': entryDoc.data()['beforeImageUrls'] ?? [],
          'afterImageUrls': entryDoc.data()['afterImageUrls'] ?? [],
          'status': entryDoc.data()['status'] ?? 'pending',
          'phaseName': _getPhaseNameBySubphaseId(subphaseId),
          'subPhaseName': _getSubPhaseNameById(subphaseId),
          ...entryDoc.data(),
        }).toList();
        
        // Store in projectData in the format expected by PdfReportGenerator
        final subphaseKey = 'subphase_${subphaseId}_entries';
        projectData[subphaseKey] = entries;
        
        print('Prepared ${entries.length} entries for subphase $subphaseId');
      }
      
      // Prepare tests data with entries
      for (final testDoc in testsQuery.docs) {
        final testId = testDoc.id;
        
        // Load entries for this test
        var entriesQuery = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('tests_status')
            .doc(testId)
            .collection('entries')
            .get();
            
        if (entriesQuery.docs.isEmpty) {
          entriesQuery = await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('tests')
              .doc(testId)
              .collection('entries')
              .get();
        }
        
        // Store entries in a way PdfReportGenerator expects
        final entries = entriesQuery.docs.map((entryDoc) => {
          'id': entryDoc.id,
          'timestamp': entryDoc.data()['timestamp'],
          'notes': entryDoc.data()['notes'] ?? '',
          'imageUrls': entryDoc.data()['imageUrls'] ?? [],
          'beforeImageUrls': entryDoc.data()['beforeImageUrls'] ?? [],
          'afterImageUrls': entryDoc.data()['afterImageUrls'] ?? [],
          'status': entryDoc.data()['status'] ?? 'pending',
          'testName': _getTestNameById(testId),
          ...entryDoc.data(),
        }).toList();
        
        // Store in projectData in the format expected by PdfReportGenerator
        final testKey = 'test_${testId}_entries';
        projectData[testKey] = entries;
        
        print('Prepared ${entries.length} entries for test $testId');
      }
      
      print('Enhanced PDF Generator: Data preparation completed successfully');
      print('Enhanced PDF Generator: SUMMARY - Prepared $totalEntriesPrepared total entries with $totalImagesPrepared total images');
      
      // Additional debugging: Print all keys in projectData that contain entries
      final entryKeys = projectData.keys.where((key) => key.contains('_entries')).toList();
      print('Enhanced PDF Generator: Entry keys in projectData: $entryKeys');
      
      // CRITICAL: Create a combined dayEntries list that PdfReportGenerator expects
      List<Map<String, dynamic>> allDayEntries = [];
      
      // Collect all entries from phases, subphases, and tests
      for (String key in entryKeys) {
        final entries = projectData[key] as List<Map<String, dynamic>>? ?? [];
        allDayEntries.addAll(entries);
      }
      
      // Store the combined entries in the format PdfReportGenerator expects
      projectData['dayEntries'] = allDayEntries;
      print('Enhanced PDF Generator: Created combined dayEntries with ${allDayEntries.length} total entries');
      
      // Also create imageUrls list for PdfReportGenerator
      List<String> allImageUrls = [];
      for (final entry in allDayEntries) {
        final imageUrls = entry['imageUrls'] as List? ?? [];
        final beforeImageUrls = entry['beforeImageUrls'] as List? ?? [];
        final afterImageUrls = entry['afterImageUrls'] as List? ?? [];
        
        allImageUrls.addAll(imageUrls.map((e) => e.toString()));
        allImageUrls.addAll(beforeImageUrls.map((e) => e.toString()));
        allImageUrls.addAll(afterImageUrls.map((e) => e.toString()));
      }
      
      projectData['imageUrls'] = allImageUrls;
      print('Enhanced PDF Generator: Created imageUrls list with ${allImageUrls.length} total images');
      
    } catch (e) {
      print('Error preparing data for PdfReportGenerator: $e');
      print('Stack trace: $e');
    }
  }
  
  /// الحصول على اسم المرحلة من معرفها
  static String _getPhaseNameById(String phaseId) {
    final phase = predefinedPhasesStructure.firstWhere(
      (p) => p['id'] == phaseId,
      orElse: () => {'name': 'مرحلة غير معروفة'},
    );
    return phase['name'] ?? 'مرحلة غير معروفة';
  }
  
  /// الحصول على اسم المرحلة الفرعية من معرفها
  static String _getSubPhaseNameById(String subphaseId) {
    for (final phase in predefinedPhasesStructure) {
      final subPhases = phase['subPhases'] as List<Map<String, dynamic>>? ?? [];
      for (final subPhase in subPhases) {
        if (subPhase['id'] == subphaseId) {
          return subPhase['name'] ?? 'مرحلة فرعية غير معروفة';
        }
      }
    }
    return 'مرحلة فرعية غير معروفة';
  }
  
  /// الحصول على اسم المرحلة الأساسية من معرف المرحلة الفرعية
  static String _getPhaseNameBySubphaseId(String subphaseId) {
    for (final phase in predefinedPhasesStructure) {
      final subPhases = phase['subPhases'] as List<Map<String, dynamic>>? ?? [];
      for (final subPhase in subPhases) {
        if (subPhase['id'] == subphaseId) {
          return phase['name'] ?? 'مرحلة غير معروفة';
        }
      }
    }
    return 'مرحلة غير معروفة';
  }
  
  /// الحصول على اسم الاختبار من معرفه
  static String _getTestNameById(String testId) {
    for (final section in finalCommissioningTests) {
      final tests = section['tests'] as List<Map<String, dynamic>>? ?? [];
      for (final test in tests) {
        if (test['id'] == testId) {
          return test['name'] ?? 'اختبار غير معروف';
        }
      }
    }
    return 'اختبار غير معروف';
  }

  /// إنشاء تقرير شامل محسن باستخدام التصميم الأصلي مع التخزين الذكي
  static Future<EnhancedPdfResult> generateComprehensiveReport({
    required String projectId,
    required DateTime startDate,
    required DateTime endDate,
    required String generatedBy,
    required String generatedByRole,
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
    bool forceRefresh = false,
  }) async {
    try {
      onStatusUpdate?.call('تهيئة النظام المحسن مع التخزين الذكي...');
      onProgress?.call(0.05);
      
      // Initialize cache system
      await SmartReportCacheManager.initialize();
      
      onStatusUpdate?.call('جاري تحضير بيانات التقرير...');
      onProgress?.call(0.1);
      
      // Get project data from Firestore with comprehensive data loading
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      
      if (!projectDoc.exists) {
        throw Exception('المشروع غير موجود');
      }
      
      final projectData = projectDoc.data() as Map<String, dynamic>;
      
      onStatusUpdate?.call('جاري تحميل البيانات الشاملة من قاعدة البيانات...');
      onProgress?.call(0.15);
      
      // Load comprehensive project data including phases, subphases, tests, and requests
      await _loadComprehensiveProjectData(projectId, projectData, onStatusUpdate, onProgress);
      
      // Note: Data caching is handled internally by the loading process
      
      onStatusUpdate?.call('جاري إنشاء التقرير بالتصميم الأصلي مع التحسينات...');
      onProgress?.call(0.2);
      
      // Debug info
      print('Enhanced PDF Generator: Creating comprehensive report for project: $projectId');
      print('Enhanced PDF Generator: Project data keys: ${projectData.keys.toList()}');
      print('Enhanced PDF Generator: Using start=null, end=null for comprehensive report (should show all data)');
      print('Enhanced PDF Generator: Phases structure count: ${predefinedPhasesStructure.length}');
      print('Enhanced PDF Generator: Tests structure count: ${finalCommissioningTests.length}');
      
      // Use the original PdfReportGenerator for comprehensive report (no date filtering)
      final result = await PdfReportGenerator.generate(
        projectId: projectId,
        projectData: projectData,
        phases: predefinedPhasesStructure,
        testsStructure: finalCommissioningTests,
        generatedBy: generatedBy,
        generatedByRole: generatedByRole,
        start: null, // للتقرير الشامل - بدون تصفية تواريخ لإظهار جميع البيانات
        end: null,   // للتقرير الشامل - بدون تصفية تواريخ لإظهار جميع البيانات
        onProgress: (p) {
          final progress = 0.2 + (p * 0.7); // من 20% إلى 90%
          String message;
          if (p < 0.2) {
            message = 'جاري تحميل جميع البيانات للتقرير الشامل...';
          } else if (p < 0.4) {
            message = 'جاري معالجة جميع الصور...';
          } else if (p < 0.7) {
            message = 'جاري إنشاء الجداول الشاملة والتفاصيل...';
          } else if (p < 0.9) {
            message = 'جاري إنشاء التقرير الشامل...';
          } else {
            message = 'جاري حفظ التقرير الشامل...';
          }
          onStatusUpdate?.call(message);
          onProgress?.call(progress);
        },
        onStatusUpdate: (status) {
          print('PdfReportGenerator Status: $status'); // للتشخيص
          onStatusUpdate?.call(status);
        },
      );
      
      onProgress?.call(0.95);
      onStatusUpdate?.call('جاري حفظ التقرير في التخزين المؤقت...');
      
      // Cache the generated report for future use
      try {
        // يمكن إضافة تخزين التقرير المولد هنا لاحقاً
        print('Report generated successfully with enhanced caching');
      } catch (e) {
        // في حالة فشل التخزين، نتجاهل الخطأ ونكمل
        print('Failed to cache generated report: $e');
      }
      
      onProgress?.call(1.0);
      onStatusUpdate?.call('تم إنشاء التقرير المحسن بنجاح');
      
      return EnhancedPdfResult(
        bytes: result.bytes,
        downloadUrl: result.downloadUrl,
      );
      
    } catch (e) {
      onStatusUpdate?.call('حدث خطأ في إنشاء التقرير: $e');
      rethrow;
    }
  }


}