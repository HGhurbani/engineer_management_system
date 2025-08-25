const functions = require('firebase-functions');
const admin = require('firebase-admin');
const PdfKit = require('pdfkit');
const axios = require('axios');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const bucket = admin.storage().bucket();

const SNAPSHOT_VERSION = 2; // تحديث الإصدار

// توليد ملف PDF على الخادم من مجموعة من روابط الصور
exports.generatePdfReport = functions.https.onCall(async (data, context) => {
  const images = data.images || [];
  if (!Array.isArray(images) || images.length === 0) {
    return { error: 'No images provided' };
  }

  const doc = new PdfKit({ autoFirstPage: false });
  const buffers = [];
  doc.on('data', buffers.push.bind(buffers));

  return new Promise(async (resolve, reject) => {
    doc.on('end', async () => {
      try {
        const pdfBuffer = Buffer.concat(buffers);
        const fileName = `reports/server_report_${Date.now()}.pdf`;
        const file = bucket.file(fileName);
        await file.save(pdfBuffer, { contentType: 'application/pdf' });
        const [url] = await file.getSignedUrl({
          action: 'read',
          expires: Date.now() + 3600 * 1000,
        });
        resolve({ url });
      } catch (err) {
        reject(err);
      }
    });

    for (const url of images) {
      try {
        const response = await axios.get(url, { responseType: 'arraybuffer' });
        const img = doc.openImage(response.data);
        doc.addPage({ size: 'A4' });
        const pageWidth = doc.page.width;
        const pageHeight = doc.page.height;
        const scale = Math.min(pageWidth / img.width, pageHeight / img.height);
        const w = img.width * scale;
        const h = img.height * scale;
        doc.image(img, (pageWidth - w) / 2, (pageHeight - h) / 2, {
          width: w,
          height: h,
        });
      } catch (e) {
        console.error('Error processing image', e);
      }
    }

    doc.end();
  });
});

async function buildReportSnapshot(projectId, startDate = null, endDate = null) {
  try {
    console.log(`Building report snapshot for project ${projectId}`);
    
    const projectRef = db.collection('projects').doc(projectId);
    const projectSnap = await projectRef.get();
    
    if (!projectSnap.exists) {
      console.log(`Project ${projectId} missing`);
      return null;
    }
    
    const project = projectSnap.data();
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    // تجميع البيانات
    let phasesData = [];
    let testsData = [];
    let materialsData = [];
    let imagesData = [];
    let summaryStats = {
      totalEntries: 0,
      totalImages: 0,
      totalTests: 0,
      totalRequests: 0,
      lastUpdated: null
    };
    
    try {
      // تجميع إدخالات المراحل الرئيسية - مع fallback شامل
      let phasesSnap = await projectRef.collection('phases_status').get();
      console.log(`Found ${phasesSnap.docs.length} phases in phases_status for project ${projectId}`);
      
      // إذا لم توجد مراحل في phases_status، جرب phases
      if (phasesSnap.docs.length === 0) {
        phasesSnap = await projectRef.collection('phases').get();
        console.log(`Found ${phasesSnap.docs.length} phases in phases for project ${projectId}`);
      }
      
      // إذا لم توجد مراحل في أي من المجموعتين، جرب البحث في جميع المجموعات
      if (phasesSnap.docs.length === 0) {
        console.log(`No phases found in standard collections, searching all collections...`);
        const allCollections = await projectRef.listCollections();
        console.log(`Available collections: ${allCollections.map(col => col.id).join(', ')}`);
        
        // البحث في جميع المجموعات التي قد تحتوي على مراحل
        for (const collection of allCollections) {
          if (collection.id.includes('phase') || collection.id.includes('Phase')) {
            const altPhasesSnap = await collection.get();
            if (altPhasesSnap.docs.length > 0) {
              console.log(`Found ${altPhasesSnap.docs.length} phases in alternative collection: ${collection.id}`);
              phasesSnap = altPhasesSnap;
              break;
            }
          }
        }
      }
      
      console.log(`Processing ${phasesSnap.docs.length} phases for project ${projectId}`);
      
      for (const phaseDoc of phasesSnap.docs) {
        const phaseData = phaseDoc.data();
        const phaseId = phaseDoc.id;
        const phaseName = phaseData.name || phaseId;
        
        // تجميع الإدخالات - مع fallback شامل
        let entriesSnap = await phaseDoc.ref.collection('entries').get();
        console.log(`Found ${entriesSnap.docs.length} entries for phase ${phaseId} in main collection`);
        
        // إذا لم توجد إدخالات، جرب المجموعات البديلة
        if (entriesSnap.docs.length === 0) {
          // جرب phases.entries إذا كنا في phases_status
          if (phaseDoc.ref.parent.id === 'phases_status') {
            const altEntriesSnap = await projectRef.collection('phases').doc(phaseId).collection('entries').get();
            if (altEntriesSnap.docs.length > 0) {
              console.log(`Found ${altEntriesSnap.docs.length} entries for phase ${phaseId} in phases.entries`);
              entriesSnap = altEntriesSnap;
            }
          }
          // جرب phases_status.entries إذا كنا في phases
          else if (phaseDoc.ref.parent.id === 'phases') {
            const altEntriesSnap = await projectRef.collection('phases_status').doc(phaseId).collection('entries').get();
            if (altEntriesSnap.docs.length > 0) {
              console.log(`Found ${altEntriesSnap.docs.length} entries for phase ${phaseId} in phases_status.entries`);
              entriesSnap = altEntriesSnap;
            }
          }
        }
        
        const phaseEntries = [];
        for (const entry of entriesSnap.docs) {
          const entryData = entry.data();
          
          // تسامح أكثر مع البيانات - لا نتطلب timestamp إجباري
          if (!entryData) {
            console.warn(`Skipping entry ${entry.id} - no data`);
            continue;
          }
          
          // فحص وجود محتوى فعلي - تحسين الفحص
          const hasNotes = (entryData.notes && entryData.notes.toString().trim().length > 0) ||
                           (entryData.note && entryData.note.toString().trim().length > 0) ||
                           (entryData.description && entryData.description.toString().trim().length > 0);
          const hasImages = (entryData.imageUrls && entryData.imageUrls.length > 0) ||
                           (entryData.otherImages && entryData.otherImages.length > 0) ||
                           (entryData.beforeImages && entryData.beforeImages.length > 0) ||
                           (entryData.afterImages && entryData.afterImages.length > 0) ||
                           (entryData.beforeImageUrls && entryData.beforeImageUrls.length > 0) ||
                           (entryData.afterImageUrls && entryData.afterImageUrls.length > 0) ||
                           (entryData.images && entryData.images.length > 0);
          const hasStatus = entryData.status || entryData.phaseStatus || entryData.completionStatus;
          const hasDate = entryData.timestamp || entryData.createdAt || entryData.date;
          
          // تسامح أكثر - نقبل الإدخالات حتى لو كانت فارغة نسبياً
          const hasContent = hasNotes || hasImages || hasStatus || hasDate;

          if (!hasContent) {
            console.log(`Skipping empty entry ${entry.id}`);
            continue;
          }

          console.log(`Including entry ${entry.id} with content: notes=${hasNotes}, images=${hasImages}, status=${hasStatus}, date=${hasDate}`);
          
          const entryWithMeta = {
            id: entry.id,
            ...entryData,
            phaseId: phaseId,
            phaseName: phaseName,
            collectionType: 'main_phase',
            // إضافة timestamp افتراضي إذا لم يكن موجود
            timestamp: entryData.timestamp || entryData.createdAt || entryData.date || admin.firestore.Timestamp.now()
          };
          
          phaseEntries.push(entryWithMeta);
          summaryStats.totalEntries++;
          
          // تجميع الصور
          const imageFields = ['imageUrls', 'otherImages', 'otherImageUrls', 'beforeImages', 'beforeImageUrls', 'afterImages', 'afterImageUrls', 'images'];
          for (const field of imageFields) {
            const urls = entryData[field];
            if (urls && Array.isArray(urls)) {
              for (const url of urls) {
                if (url && url.trim().length > 0) {
                  imagesData.push({
                    url: url,
                    field: field,
                    entryId: entry.id,
                    phaseId: phaseId,
                    timestamp: entryData.timestamp || entryData.createdAt || entryData.date || admin.firestore.Timestamp.now()
                  });
                  summaryStats.totalImages++;
                }
              }
            }
          }
          
          if (entryData.timestamp && (!summaryStats.lastUpdated || entryData.timestamp > summaryStats.lastUpdated)) {
            summaryStats.lastUpdated = entryData.timestamp;
          }
        }
        
        phasesData.push({
          id: phaseId,
          name: phaseName,
          entries: phaseEntries,
          entryCount: phaseEntries.length
        });
      }
      
      // تجميع إدخالات المراحل الفرعية - مع fallback شامل
      let subphasesSnap = await projectRef.collection('subphases_status').get();
      console.log(`Found ${subphasesSnap.docs.length} subphases in subphases_status for project ${projectId}`);
      
      // إذا لم توجد مراحل فرعية في subphases_status، جرب subphases
      if (subphasesSnap.docs.length === 0) {
        subphasesSnap = await projectRef.collection('subphases').get();
        console.log(`Found ${subphasesSnap.docs.length} subphases in subphases for project ${projectId}`);
      }
      
      console.log(`Processing ${subphasesSnap.docs.length} subphases for project ${projectId}`);
      
      for (const subphaseDoc of subphasesSnap.docs) {
        const subphaseData = subphaseDoc.data();
        const subphaseId = subphaseDoc.id;
        const subphaseName = subphaseData.name || subphaseId;
        
        // تجميع الإدخالات للمراحل الفرعية - مع fallback شامل
        let entriesSnap = await subphaseDoc.ref.collection('entries').get();
        console.log(`Found ${entriesSnap.docs.length} entries for subphase ${subphaseId} in main collection`);
        
        // إذا لم توجد إدخالات، جرب المجموعات البديلة
        if (entriesSnap.docs.length === 0) {
          // جرب subphases.entries إذا كنا في subphases_status
          if (subphaseDoc.ref.parent.id === 'subphases_status') {
            const altEntriesSnap = await projectRef.collection('subphases').doc(subphaseId).collection('entries').get();
            if (altEntriesSnap.docs.length > 0) {
              console.log(`Found ${altEntriesSnap.docs.length} entries for subphase ${subphaseId} in subphases.entries`);
              entriesSnap = altEntriesSnap;
            }
          }
          // جرب subphases_status.entries إذا كنا في subphases
          else if (subphaseDoc.ref.parent.id === 'subphases') {
            const altEntriesSnap = await projectRef.collection('subphases_status').doc(subphaseId).collection('entries').get();
            if (altEntriesSnap.docs.length > 0) {
              console.log(`Found ${altEntriesSnap.docs.length} entries for subphase ${subphaseId} in subphases_status.entries`);
              entriesSnap = altEntriesSnap;
            }
          }
        }
        
        const subphaseEntries = [];
        for (const entry of entriesSnap.docs) {
          const entryData = entry.data();
          
          // تسامح أكثر مع البيانات - لا نتطلب timestamp إجباري
          if (!entryData) {
            console.warn(`Skipping subphase entry ${entry.id} - no data`);
            continue;
          }
          
          // فحص وجود محتوى فعلي - تحسين الفحص
          const hasNotes = (entryData.notes && entryData.notes.toString().trim().length > 0) ||
                           (entryData.note && entryData.note.toString().trim().length > 0) ||
                           (entryData.description && entryData.description.toString().trim().length > 0);
          const hasImages = (entryData.imageUrls && entryData.imageUrls.length > 0) ||
                           (entryData.otherImages && entryData.otherImages.length > 0) ||
                           (entryData.beforeImages && entryData.beforeImages.length > 0) ||
                           (entryData.afterImages && entryData.afterImages.length > 0) ||
                           (entryData.beforeImageUrls && entryData.beforeImageUrls.length > 0) ||
                           (entryData.afterImageUrls && entryData.afterImageUrls.length > 0) ||
                           (entryData.images && entryData.images.length > 0);
          const hasStatus = entryData.status || entryData.phaseStatus || entryData.completionStatus;
          const hasDate = entryData.timestamp || entryData.createdAt || entryData.date;
          
          // تسامح أكثر - نقبل الإدخالات حتى لو كانت فارغة نسبياً
          const hasContent = hasNotes || hasImages || hasStatus || hasDate;

          if (!hasContent) {
            console.log(`Skipping empty subphase entry ${entry.id}`);
            continue;
          }

          console.log(`Including subphase entry ${entry.id} with content: notes=${hasNotes}, images=${hasImages}, status=${hasStatus}, date=${hasDate}`);
          
          const entryWithMeta = {
            id: entry.id,
            ...entryData,
            subphaseId: subphaseId,
            subphaseName: subphaseName,
            collectionType: 'sub_phase',
            // إضافة timestamp افتراضي إذا لم يكن موجود
            timestamp: entryData.timestamp || entryData.createdAt || entryData.date || admin.firestore.Timestamp.now()
          };
          
          subphaseEntries.push(entryWithMeta);
          summaryStats.totalEntries++;
          
          // تجميع الصور
          const imageFields = ['imageUrls', 'otherImages', 'otherImageUrls', 'beforeImages', 'beforeImageUrls', 'afterImages', 'afterImageUrls', 'images'];
          for (const field of imageFields) {
            const urls = entryData[field];
            if (urls && Array.isArray(urls)) {
              for (const url of urls) {
                if (url && url.trim().length > 0) {
                  imagesData.push({
                    url: url,
                    field: field,
                    entryId: entry.id,
                    subphaseId: subphaseId,
                    timestamp: entryData.timestamp || entryData.createdAt || entryData.date || admin.firestore.Timestamp.now()
                  });
                  summaryStats.totalImages++;
                }
              }
            }
          }
          
          if (entryData.timestamp && (!summaryStats.lastUpdated || entryData.timestamp > summaryStats.lastUpdated)) {
            summaryStats.lastUpdated = entryData.timestamp;
          }
        }
        
        console.log(`Subphase ${subphaseId} has ${subphaseEntries.length} valid entries`);
        
        // إضافة المرحلة الفرعية مع إدخالاتها (حتى لو كانت فارغة للتشخيص)
        phasesData.push({
          id: subphaseId,
          name: subphaseName,
          entries: subphaseEntries,
          entryCount: subphaseEntries.length,
          isSubphase: true
        });
      }
      
      // تجميع الاختبارات - مع fallback
      let testsSnap = await projectRef.collection('tests_status').get();
      console.log(`Found ${testsSnap.docs.length} tests in tests_status for project ${projectId}`);
      
      // إذا لم توجد اختبارات في tests_status، جرب tests
      if (testsSnap.docs.length === 0) {
        testsSnap = await projectRef.collection('tests').get();
        console.log(`Found ${testsSnap.docs.length} tests in tests for project ${projectId}`);
      }
      
      for (const testDoc of testsSnap.docs) {
        const testData = testDoc.data();
        testsData.push({
          id: testDoc.id,
          ...testData,
          collectionType: 'test'
        });
        summaryStats.totalTests++;
      }
      
      // تجميع طلبات المواد
      const materialsSnap = await db.collection('partRequests')
        .where('projectId', '==', projectId)
        .get();
      console.log(`Found ${materialsSnap.docs.length} material requests for project ${projectId}`);
      
      for (const materialDoc of materialsSnap.docs) {
        const materialData = materialDoc.data();
        materialsData.push({
          id: materialDoc.id,
          ...materialData,
          collectionType: 'material_request'
        });
        summaryStats.totalRequests++;
      }
      
      // فحص إضافي - البحث في جميع المجموعات المتبقية
      if (summaryStats.totalEntries === 0) {
        console.log(`No entries found in standard collections, performing deep search...`);
        const allCollections = await projectRef.listCollections();
        
        for (const collection of allCollections) {
          if (!['phases_status', 'phases', 'subphases_status', 'subphases', 'tests_status', 'tests'].includes(collection.id)) {
            console.log(`Searching in collection: ${collection.id}`);
            const collectionSnap = await collection.get();
            
            if (collectionSnap.docs.length > 0) {
              console.log(`Found ${collectionSnap.docs.length} documents in ${collection.id}`);
              
              // البحث عن إدخالات في هذه المجموعة
              for (const doc of collectionSnap.docs) {
                if (doc.id === 'entries' || doc.id.includes('entry')) {
                  const entriesSnap = await doc.ref.get();
                  if (entriesSnap.exists) {
                    console.log(`Found entries subcollection in ${collection.id}/${doc.id}`);
                    // يمكن إضافة معالجة إضافية هنا إذا لزم الأمر
                  }
                }
              }
            }
          }
        }
      }
      
    } catch (e) {
      console.error(`Error collecting data for project ${projectId}:`, e);
      // لا نريد أن نفشل إذا كانت هناك مشكلة في تجميع البيانات
      // نستمر بإنشاء snapshot أساسي
    }

    // إنشاء Snapshot - حتى لو كانت البيانات فارغة
    const snapshot = {
      version: SNAPSHOT_VERSION,
      projectId: projectId,
      projectData: project,
      phasesData: phasesData,
      testsData: testsData,
      materialsData: materialsData,
      imagesData: imagesData,
      summaryStats: summaryStats,
      reportMetadata: {
        generatedAt: now,
        startDate: startDate,
        endDate: endDate,
        isFullReport: !startDate && !endDate,
        totalDataSize: 0, // سيتم تحديثه لاحقاً
        imageCount: imagesData.length,
        entryCount: summaryStats.totalEntries,
        testCount: summaryStats.totalTests,
        requestCount: summaryStats.totalRequests,
        // إضافة معلومات تشخيصية
        diagnosticInfo: {
          collectionsSearched: ['phases_status', 'phases', 'subphases_status', 'subphases', 'tests_status', 'tests'],
          totalCollectionsFound: phasesData.length + testsData.length,
          hasData: summaryStats.totalEntries > 0 || summaryStats.totalTests > 0 || summaryStats.totalRequests > 0
        }
      }
    };

    // حساب حجم البيانات
    snapshot.reportMetadata.totalDataSize = JSON.stringify(snapshot).length;

    // حفظ Snapshot - حتى لو كانت البيانات فارغة
    const snapshotRef = db.collection('report_snapshots').doc(projectId);
    await snapshotRef.set(snapshot);
    console.log(`Snapshot saved for ${projectId} with ${summaryStats.totalEntries} entries, ${summaryStats.totalTests} tests, ${summaryStats.totalRequests} requests`);
    
    return snapshot;
    
  } catch (error) {
    console.error(`Error building report snapshot for ${projectId}:`, error);
    throw error;
  }
}

// HTTP Callable Function لإنشاء Snapshot
exports.buildReportSnapshot = functions.https.onCall(async (data, context) => {
  const { projectId, startDate, endDate } = data;
  
  if (!projectId) {
    throw new functions.https.HttpsError('invalid-argument', 'projectId is required');
  }
  
  try {
    let start = null;
    let end = null;
    
    if (startDate) {
      start = admin.firestore.Timestamp.fromDate(new Date(startDate));
    }
    if (endDate) {
      end = admin.firestore.Timestamp.fromDate(new Date(endDate));
    }
    
    const snapshot = await buildReportSnapshot(projectId, start, end);
    return { 
      success: true, 
      projectId,
      snapshotId: snapshot ? snapshot.reportMetadata.generatedAt : null,
      dataSize: snapshot ? snapshot.reportMetadata.totalDataSize : 0
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// دالة محسنة لإعادة بناء جميع snapshots
exports.rebuildAllSnapshots = functions.https.onCall(async (data, context) => {
  // التحقق من الصلاحيات (فقط للإدارة)
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  
  try {
    const projectsSnap = await admin.firestore().collection('projects').get();
    const results = [];
    
    console.log(`Starting to rebuild snapshots for ${projectsSnap.docs.length} projects`);
    
    for (const projectDoc of projectsSnap.docs) {
      const projectId = projectDoc.id;
      console.log(`Rebuilding snapshot for project: ${projectId}`);
      
      try {
        const result = await buildReportSnapshot(projectId);
        results.push({
          projectId: projectId,
          success: true,
          dataSize: result ? result.reportMetadata.totalDataSize : 0,
          hasData: result ? true : false
        });
      } catch (error) {
        console.error(`Failed to rebuild snapshot for project ${projectId}:`, error);
        results.push({
          projectId: projectId,
          success: false,
          error: error.message
        });
      }
    }
    
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;
    const hasDataCount = results.filter(r => r.hasData).length;
    
    console.log(`Snapshot rebuild completed: ${successCount} success, ${failureCount} failures, ${hasDataCount} have data`);
    
    return {
      success: true,
      totalProjects: projectsSnap.docs.length,
      successCount: successCount,
      failureCount: failureCount,
      hasDataCount: hasDataCount,
      results: results
    };
  } catch (error) {
    console.error('Error in rebuildAllSnapshots function:', error);
    throw new functions.https.HttpsError('internal', 'Failed to rebuild snapshots: ' + error.message);
  }
});

// دالة جديدة لفحص حالة Snapshots
exports.checkSnapshotsStatus = functions.https.onCall(async (data, context) => {
  try {
    const projectsSnap = await admin.firestore().collection('projects').get();
    const snapshotsSnap = await admin.firestore().collection('report_snapshots').get();
    
    const projectIds = projectsSnap.docs.map(doc => doc.id);
    const snapshotIds = snapshotsSnap.docs.map(doc => doc.id);
    
    const missingSnapshots = projectIds.filter(id => !snapshotIds.includes(id));
    const existingSnapshots = projectIds.filter(id => snapshotIds.includes(id));
    
    return {
      success: true,
      totalProjects: projectIds.length,
      existingSnapshots: existingSnapshots.length,
      missingSnapshots: missingSnapshots.length,
      missingProjectIds: missingSnapshots,
      existingProjectIds: existingSnapshots
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// HTTP Callable Function لإنشاء Snapshot شامل
exports.buildFullReportSnapshot = functions.https.onCall(async (data, context) => {
  const { projectId } = data;
  
  if (!projectId) {
    throw new functions.https.HttpsError('invalid-argument', 'projectId is required');
  }
  
  try {
    const snapshot = await buildReportSnapshot(projectId);
    return { 
      success: true, 
      projectId,
      snapshotId: snapshot ? snapshot.reportMetadata.generatedAt : null,
      dataSize: snapshot ? snapshot.reportMetadata.totalDataSize : 0
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// دالة للتحقق من مشروع واحد - محسنة
exports.checkSingleProjectSnapshot = functions.https.onCall(async (data, context) => {
  const { projectId } = data;
  
  if (!projectId) {
    throw new functions.https.HttpsError('invalid-argument', 'projectId is required');
  }
  
  try {
    // فحص وجود المشروع
    const projectSnap = await admin.firestore().collection('projects').doc(projectId).get();
    if (!projectSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Project not found');
    }
    
    // فحص وجود Snapshot
    const snapshotSnap = await admin.firestore().collection('report_snapshots').doc(projectId).get();
    const hasSnapshot = snapshotSnap.exists;
    
    // فحص شامل للبيانات الفعلية - مع fallback
    let totalEntries = 0;
    let totalPhases = 0;
    
    // فحص phases_status
    const phasesStatusSnap = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .collection('phases_status')
      .get();
    
    for (const phaseDoc of phasesStatusSnap.docs) {
      const entriesSnap = await phaseDoc.ref.collection('entries').get();
      totalEntries += entriesSnap.docs.length;
    }
    totalPhases += phasesStatusSnap.docs.length;
    
    // فحص phases (بديل)
    const phasesSnap = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .collection('phases')
      .get();
    
    for (const phaseDoc of phasesSnap.docs) {
      const entriesSnap = await phaseDoc.ref.collection('entries').get();
      totalEntries += entriesSnap.docs.length;
    }
    totalPhases += phasesSnap.docs.length;
    
    // فحص subphases_status
    const subphasesStatusSnap = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .collection('subphases_status')
      .get();
    
    for (const subphaseDoc of subphasesStatusSnap.docs) {
      const entriesSnap = await subphaseDoc.ref.collection('entries').get();
      totalEntries += entriesSnap.docs.length;
    }
    
    // فحص subphases (بديل)
    const subphasesSnap = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .collection('subphases')
      .get();
    
    for (const subphaseDoc of subphasesSnap.docs) {
      const entriesSnap = await subphaseDoc.ref.collection('entries').get();
      totalEntries += entriesSnap.docs.length;
    }
    
    // فحص الاختبارات
    let totalTests = 0;
    const testsStatusSnap = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .collection('tests_status')
      .get();
    totalTests += testsStatusSnap.docs.length;
    
    const testsSnap = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .collection('tests')
      .get();
    totalTests += testsSnap.docs.length;
    
    // فحص طلبات المواد
    const materialsSnap = await admin.firestore()
      .collection('partRequests')
      .where('projectId', '==', projectId)
      .get();
    
    // فحص إضافي - البحث في جميع المجموعات
    const allCollections = await admin.firestore()
      .collection('projects')
      .doc(projectId)
      .listCollections();
    
    let additionalDataFound = false;
    for (const collection of allCollections) {
      if (!['phases_status', 'phases', 'subphases_status', 'subphases', 'tests_status', 'tests'].includes(collection.id)) {
        const collectionSnap = await collection.get();
        if (collectionSnap.docs.length > 0) {
          additionalDataFound = true;
          console.log(`Found additional data in collection: ${collection.id} (${collectionSnap.docs.length} docs)`);
        }
      }
    }
    
    return {
      success: true,
      projectId,
      projectName: projectSnap.data().name || 'غير مسمى',
      hasSnapshot,
      snapshotDate: hasSnapshot ? snapshotSnap.data().reportMetadata?.generatedAt : null,
      actualData: {
        phases: totalPhases,
        entries: totalEntries,
        tests: totalTests,
        materials: materialsSnap.docs.length,
        additionalCollections: allCollections.length,
        hasAdditionalData: additionalDataFound
      },
      snapshotData: hasSnapshot ? {
        entries: snapshotSnap.data().summaryStats?.totalEntries || 0,
        tests: snapshotSnap.data().summaryStats?.totalTests || 0,
        materials: snapshotSnap.data().summaryStats?.totalRequests || 0
      } : null,
      // إضافة معلومات تشخيصية
      diagnosticInfo: {
        collectionsSearched: allCollections.map(col => col.id),
        totalCollections: allCollections.length,
        hasData: totalEntries > 0 || totalTests > 0 || materialsSnap.docs.length > 0 || additionalDataFound
      }
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// دالة إعادة بناء جميع Snapshots للمشاريع الموجودة
exports.rebuildAllSnapshots = functions.https.onCall(async (data, context) => {
  try {
    console.log('Starting to rebuild all snapshots...');
    
    const projectsSnap = await admin.firestore().collection('projects').get();
    const results = {
      total: projectsSnap.docs.length,
      successful: 0,
      failed: 0,
      errors: []
    };
    
    // معالجة المشاريع بالتوازي (مع حد أقصى)
    const batchSize = 5;
    const batches = [];
    
    for (let i = 0; i < projectsSnap.docs.length; i += batchSize) {
      const batch = projectsSnap.docs.slice(i, i + batchSize);
      batches.push(batch);
    }
    
    for (const batch of batches) {
      const batchPromises = batch.map(async (projectDoc) => {
        try {
          const projectId = projectDoc.id;
          const projectName = projectDoc.data().name || 'غير مسمى';
          
          console.log(`Rebuilding snapshot for project: ${projectId} (${projectName})`);
          
          const snapshot = await buildReportSnapshot(projectId);
          if (snapshot) {
            results.successful++;
            console.log(`✅ Successfully rebuilt snapshot for ${projectId}`);
          } else {
            results.failed++;
            results.errors.push(`Failed to build snapshot for ${projectId}: No data returned`);
            console.log(`❌ Failed to rebuild snapshot for ${projectId}: No data returned`);
          }
        } catch (error) {
          results.failed++;
          results.errors.push(`Failed to build snapshot for ${projectDoc.id}: ${error.message}`);
          console.error(`❌ Failed to rebuild snapshot for ${projectDoc.id}:`, error);
        }
      });
      
      await Promise.all(batchPromises);
      
      // إضافة تأخير صغير بين الدفعات لتجنب إرهاق قاعدة البيانات
      if (batches.indexOf(batch) < batches.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    console.log('Finished rebuilding snapshots:', results);
    
    return {
      success: true,
      message: `تم إعادة بناء ${results.successful} من أصل ${results.total} مشروع`,
      details: results
    };
    
  } catch (error) {
    console.error('Error rebuilding all snapshots:', error);
    throw new functions.https.HttpsError('internal', 'Failed to rebuild snapshots: ' + error.message);
  }
});

// دالة إعادة بناء Snapshots لمشاريع محددة
exports.rebuildSelectedSnapshots = functions.https.onCall(async (data, context) => {
  const { projectIds } = data;
  
  if (!projectIds || !Array.isArray(projectIds) || projectIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'projectIds array is required');
  }
  
  try {
    console.log(`Rebuilding snapshots for ${projectIds.length} projects:`, projectIds);
    
    const results = {
      total: projectIds.length,
      successful: 0,
      failed: 0,
      errors: [],
      details: []
    };
    
    // معالجة المشاريع بالتوازي
    const promises = projectIds.map(async (projectId) => {
      try {
        // فحص وجود المشروع أولاً
        const projectSnap = await admin.firestore().collection('projects').doc(projectId).get();
        if (!projectSnap.exists) {
          throw new Error(`Project ${projectId} does not exist`);
        }
        
        const projectName = projectSnap.data().name || 'غير مسمى';
        console.log(`Rebuilding snapshot for: ${projectId} (${projectName})`);
        
        const snapshot = await buildReportSnapshot(projectId);
        if (snapshot) {
          results.successful++;
          results.details.push({
            projectId,
            projectName,
            status: 'success',
            entries: snapshot.summaryStats.totalEntries,
            tests: snapshot.summaryStats.totalTests,
            materials: snapshot.summaryStats.totalRequests
          });
          console.log(`✅ Successfully rebuilt snapshot for ${projectId}`);
        } else {
          results.failed++;
          results.errors.push(`No data found for project ${projectId}`);
          results.details.push({
            projectId,
            projectName,
            status: 'failed',
            error: 'No data found'
          });
        }
      } catch (error) {
        results.failed++;
        const errorMsg = `Failed to rebuild snapshot for ${projectId}: ${error.message}`;
        results.errors.push(errorMsg);
        results.details.push({
          projectId,
          status: 'failed',
          error: error.message
        });
        console.error(`❌ ${errorMsg}`);
      }
    });
    
    await Promise.all(promises);
    
    console.log('Finished rebuilding selected snapshots:', results);
    
    return {
      success: true,
      message: `تم إعادة بناء ${results.successful} من أصل ${results.total} مشروع`,
      results
    };
    
  } catch (error) {
    console.error('Error rebuilding selected snapshots:', error);
    throw new functions.https.HttpsError('internal', 'Failed to rebuild snapshots: ' + error.message);
  }
});

// دالة جديدة لفحص شامل لجميع المشاريع
exports.comprehensiveProjectCheck = functions.https.onCall(async (data, context) => {
  try {
    console.log('Starting comprehensive project check...');
    
    const projectsSnap = await admin.firestore().collection('projects').get();
    const results = [];
    
    for (const projectDoc of projectsSnap.docs) {
      const projectId = projectDoc.id;
      const projectName = projectDoc.data().name || 'غير مسمى';
      
      console.log(`Checking project: ${projectId} (${projectName})`);
      
      try {
        // فحص شامل للمشروع
        const projectCheck = await _comprehensiveSingleProjectCheck(projectId);
        results.push({
          projectId,
          projectName,
          ...projectCheck
        });
      } catch (error) {
        console.error(`Error checking project ${projectId}:`, error);
        results.push({
          projectId,
          projectName,
          error: error.message,
          hasData: false
        });
      }
    }
    
    const projectsWithData = results.filter(r => r.hasData);
    const projectsWithoutData = results.filter(r => !r.hasData);
    const projectsWithSnapshots = results.filter(r => r.hasSnapshot);
    const projectsNeedingRebuild = results.filter(r => r.needsRebuild);
    
    console.log(`Comprehensive check completed: ${projectsWithData.length} have data, ${projectsWithoutData.length} no data, ${projectsWithSnapshots.length} have snapshots, ${projectsNeedingRebuild.length} need rebuild`);
    
    return {
      success: true,
      totalProjects: results.length,
      projectsWithData: projectsWithData.length,
      projectsWithoutData: projectsWithoutData.length,
      projectsWithSnapshots: projectsWithSnapshots.length,
      projectsNeedingRebuild: projectsNeedingRebuild.length,
      results: results
    };
    
  } catch (error) {
    console.error('Error in comprehensive project check:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check projects: ' + error.message);
  }
});

// دالة مساعدة لفحص مشروع واحد بشكل شامل
async function _comprehensiveSingleProjectCheck(projectId) {
  const projectRef = admin.firestore().collection('projects').doc(projectId);
  
  // فحص وجود المشروع
  const projectSnap = await projectRef.get();
  if (!projectSnap.exists) {
    return { hasProject: false, hasData: false };
  }
  
  // فحص وجود Snapshot
  const snapshotSnap = await admin.firestore().collection('report_snapshots').doc(projectId).get();
  const hasSnapshot = snapshotSnap.exists;
  
  // فحص شامل للبيانات
  let totalEntries = 0;
  let totalPhases = 0;
  let totalTests = 0;
  let totalMaterials = 0;
  let collectionsWithData = [];
  
  // فحص جميع المجموعات المحتملة
  const allCollections = await projectRef.listCollections();
  
  for (const collection of allCollections) {
    const collectionSnap = await collection.get();
    
    if (collectionSnap.docs.length > 0) {
      collectionsWithData.push({
        name: collection.id,
        documentCount: collectionSnap.docs.length
      });
      
      // فحص الإدخالات في المراحل
      if (['phases_status', 'phases', 'subphases_status', 'subphases'].includes(collection.id)) {
        totalPhases += collectionSnap.docs.length;
        
        for (const doc of collectionSnap.docs) {
          try {
            const entriesSnap = await doc.ref.collection('entries').get();
            totalEntries += entriesSnap.docs.length;
          } catch (e) {
            // تجاهل الأخطاء في المجموعات الفرعية
          }
        }
      }
      
      // فحص الاختبارات
      if (['tests_status', 'tests'].includes(collection.id)) {
        totalTests += collectionSnap.docs.length;
      }
    }
  }
  
  // فحص طلبات المواد
  const materialsSnap = await admin.firestore()
    .collection('partRequests')
    .where('projectId', '==', projectId)
    .get();
  totalMaterials = materialsSnap.docs.length;
  
  const hasData = totalEntries > 0 || totalTests > 0 || totalMaterials > 0;
  
  // تحديد إذا كان يحتاج إعادة بناء
  let needsRebuild = false;
  let rebuildReason = '';
  
  if (!hasSnapshot) {
    needsRebuild = true;
    rebuildReason = 'لا يوجد snapshot';
  } else if (hasData) {
    const snapshotData = snapshotSnap.data();
    const snapshotEntries = snapshotData?.summaryStats?.totalEntries || 0;
    const snapshotTests = snapshotData?.summaryStats?.totalTests || 0;
    const snapshotMaterials = snapshotData?.summaryStats?.totalRequests || 0;
    
    if (snapshotEntries != totalEntries || snapshotTests != totalTests || snapshotMaterials != totalMaterials) {
      needsRebuild = true;
      rebuildReason = `البيانات مختلفة: Entries(${snapshotEntries} vs ${totalEntries}), Tests(${snapshotTests} vs ${totalTests}), Materials(${snapshotMaterials} vs ${totalMaterials})`;
    }
  }
  
  return {
    hasProject: true,
    hasSnapshot,
    hasData,
    needsRebuild,
    rebuildReason,
    dataSummary: {
      totalEntries,
      totalPhases,
      totalTests,
      totalMaterials,
      collectionsWithData: collectionsWithData.length
    },
    collections: collectionsWithData,
    snapshotInfo: hasSnapshot ? {
      version: snapshotSnap.data()?.version,
      generatedAt: snapshotSnap.data()?.reportMetadata?.generatedAt,
      totalEntries: snapshotSnap.data()?.summaryStats?.totalEntries || 0,
      totalTests: snapshotSnap.data()?.summaryStats?.totalTests || 0,
      totalMaterials: snapshotSnap.data()?.summaryStats?.totalRequests || 0
    } : null
  };
}

// Firestore Triggers لتحديث Snapshot تلقائياً
exports.onProjectWrite = functions.firestore
  .document('projects/{projectId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Project ${projectId} changed, rebuilding snapshot`);
    
    try {
      // تنفيذ مباشر بدون تأخير
      await buildReportSnapshot(projectId);
      console.log(`Snapshot rebuilt for project: ${projectId}`);
    } catch (error) {
      console.error(`Failed to rebuild snapshot for ${projectId}:`, error);
    }
  });

exports.onProjectItemWrite = functions.firestore
  .document('projects/{projectId}/{colId}/{docId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Project item ${projectId} changed, rebuilding snapshot`);
    
    try {
      await buildReportSnapshot(projectId);
      console.log(`Snapshot rebuilt for project: ${projectId}`);
    } catch (error) {
      console.error(`Failed to rebuild snapshot for ${projectId}:`, error);
    }
  });

// Trigger لإدخالات المراحل
exports.onPhaseEntryWrite = functions.firestore
  .document('projects/{projectId}/phases_status/{phaseId}/entries/{entryId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Phase entry ${context.params.entryId} changed for project ${projectId}, rebuilding snapshot`);
    
    try {
      await buildReportSnapshot(projectId);
      console.log(`Snapshot rebuilt for project: ${projectId}`);
    } catch (error) {
      console.error(`Failed to rebuild snapshot for ${projectId}:`, error);
    }
  });

// Trigger لإدخالات المراحل الفرعية
exports.onSubPhaseEntryWrite = functions.firestore
  .document('projects/{projectId}/subphases_status/{subPhaseId}/entries/{entryId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Sub-phase entry ${context.params.entryId} changed for project ${projectId}, rebuilding snapshot`);
    
    try {
      await buildReportSnapshot(projectId);
      console.log(`Snapshot rebuilt for project: ${projectId}`);
    } catch (error) {
      console.error(`Failed to rebuild snapshot for ${projectId}:`, error);
    }
  });

// Trigger للاختبارات
exports.onTestWrite = functions.firestore
  .document('projects/{projectId}/tests_status/{testId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Test ${context.params.testId} changed for project ${projectId}, rebuilding snapshot`);
    
    try {
      await buildReportSnapshot(projectId);
      console.log(`Snapshot rebuilt for project: ${projectId}`);
    } catch (error) {
      console.error(`Failed to rebuild snapshot for ${projectId}:`, error);
    }
  });

// Trigger لطلبات المواد
exports.onMaterialRequestWrite = functions.firestore
  .document('partRequests/{requestId}')
  .onWrite(async (change, context) => {
    const requestData = change.after.exists ? change.after.data() : change.before.data();
    if (requestData && requestData.projectId) {
      const projectId = requestData.projectId;
      console.log(`Material request ${context.params.requestId} changed for project ${projectId}, rebuilding snapshot`);
      
      try {
        await buildReportSnapshot(projectId);
        console.log(`Snapshot rebuilt for project: ${projectId}`);
      } catch (error) {
        console.error(`Failed to rebuild snapshot for ${projectId}:`, error);
      }
    }
  });