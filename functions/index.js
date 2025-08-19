const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const bucket = admin.storage().bucket();

const SNAPSHOT_VERSION = 2; // تحديث الإصدار

async function buildReportSnapshot(projectId, startDate = null, endDate = null) {
  try {
    console.log(`Building report snapshot for project ${projectId} from ${startDate} to ${endDate}`);
    
    const projectRef = db.collection('projects').doc(projectId);
    const projectSnap = await projectRef.get();
    
    if (!projectSnap.exists) {
      console.log(`Project ${projectId} missing`);
      return null;
    }
    
    const project = projectSnap.data();
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    // تجميع البيانات مع فلترة التاريخ
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
      // تجميع إدخالات المراحل الرئيسية
      const phasesSnap = await projectRef.collection('phases_status').get();
      for (const phaseDoc of phasesSnap.docs) {
        const phaseData = phaseDoc.data();
        const phaseId = phaseDoc.id;
        const phaseName = phaseData.name || phaseId;
        
        // فلترة الإدخالات حسب التاريخ
        let entriesQuery = phaseDoc.ref.collection('entries').orderBy('timestamp', 'desc');
        if (startDate && endDate) {
          entriesQuery = entriesQuery
            .where('timestamp', '>=', startDate)
            .where('timestamp', '<', endDate);
        }
        
        const entriesSnap = await entriesQuery.get();
        const phaseEntries = [];
        
        for (const entry of entriesSnap.docs) {
          const entryData = entry.data();
          const entryWithMeta = {
            id: entry.id,
            ...entryData,
            phaseId: phaseId,
            phaseName: phaseName,
            subPhaseId: null,
            subPhaseName: null,
            collectionType: 'main_phase'
          };
          
          // تجميع الصور
          if (entryData.imageUrls && Array.isArray(entryData.imageUrls)) {
            entryData.imageUrls.forEach(url => {
              imagesData.push({
                url: url,
                source: 'main_phase',
                phaseId: phaseId,
                phaseName: phaseName,
                entryId: entry.id,
                timestamp: entryData.timestamp,
                type: 'progress'
              });
            });
          }
          
          if (entryData.beforeImageUrls && Array.isArray(entryData.beforeImageUrls)) {
            entryData.beforeImageUrls.forEach(url => {
              imagesData.push({
                url: url,
                source: 'main_phase',
                phaseId: phaseId,
                phaseName: phaseName,
                entryId: entry.id,
                timestamp: entryData.timestamp,
                type: 'before'
              });
            });
          }
          
          if (entryData.afterImageUrls && Array.isArray(entryData.afterImageUrls)) {
            entryData.afterImageUrls.forEach(url => {
              imagesData.push({
                url: url,
                source: 'main_phase',
                phaseId: phaseId,
                phaseName: phaseName,
                entryId: entry.id,
                timestamp: entryData.timestamp,
                type: 'after'
              });
            });
          }
          
          phaseEntries.push(entryWithMeta);
          summaryStats.totalEntries++;
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
      
      // تجميع إدخالات المراحل الفرعية
      const subPhasesSnap = await projectRef.collection('subphases_status').get();
      for (const subPhaseDoc of subPhasesSnap.docs) {
        const subPhaseData = subPhaseDoc.data();
        const subPhaseId = subPhaseDoc.id;
        const subPhaseName = subPhaseData.name || subPhaseId;
        const parentPhaseId = subPhaseData.parentPhaseId;
        const parentPhaseName = subPhaseData.parentPhaseName || 'غير محدد';
        
        // فلترة الإدخالات حسب التاريخ
        let entriesQuery = subPhaseDoc.ref.collection('entries').orderBy('timestamp', 'desc');
        if (startDate && endDate) {
          entriesQuery = entriesQuery
            .where('timestamp', '>=', startDate)
            .where('timestamp', '<', endDate);
        }
        
        const entriesSnap = await entriesQuery.get();
        const subPhaseEntries = [];
        
        for (const entry of entriesSnap.docs) {
          const entryData = entry.data();
          const entryWithMeta = {
            id: entry.id,
            ...entryData,
            phaseId: parentPhaseId,
            phaseName: parentPhaseName,
            subPhaseId: subPhaseId,
            subPhaseName: subPhaseName,
            collectionType: 'sub_phase'
          };
          
          // تجميع الصور
          if (entryData.imageUrls && Array.isArray(entryData.imageUrls)) {
            entryData.imageUrls.forEach(url => {
              imagesData.push({
                url: url,
                source: 'sub_phase',
                phaseId: parentPhaseId,
                phaseName: parentPhaseName,
                subPhaseId: subPhaseId,
                subPhaseName: subPhaseName,
                entryId: entry.id,
                timestamp: entryData.timestamp,
                type: 'progress'
              });
            });
          }
          
          if (entryData.beforeImageUrls && Array.isArray(entryData.beforeImageUrls)) {
            entryData.beforeImageUrls.forEach(url => {
              imagesData.push({
                url: url,
                source: 'sub_phase',
                phaseId: parentPhaseId,
                phaseName: parentPhaseName,
                subPhaseId: subPhaseId,
                subPhaseName: subPhaseName,
                entryId: entry.id,
                timestamp: entryData.timestamp,
                type: 'before'
              });
            });
          }
          
          if (entryData.afterImageUrls && Array.isArray(entryData.afterImageUrls)) {
            entryData.afterImageUrls.forEach(url => {
              imagesData.push({
                url: url,
                source: 'sub_phase',
                phaseId: parentPhaseId,
                phaseName: parentPhaseName,
                subPhaseId: subPhaseId,
                subPhaseName: subPhaseName,
                entryId: entry.id,
                timestamp: entryData.timestamp,
                type: 'after'
              });
            });
          }
          
          subPhaseEntries.push(entryWithMeta);
          summaryStats.totalEntries++;
          if (entryData.timestamp && (!summaryStats.lastUpdated || entryData.timestamp > summaryStats.lastUpdated)) {
            summaryStats.lastUpdated = entryData.timestamp;
          }
        }
        
        // إضافة الإدخالات للمراحل الرئيسية
        const parentPhase = phasesData.find(p => p.id === parentPhaseId);
        if (parentPhase) {
          parentPhase.subPhaseEntries = parentPhase.subPhaseEntries || [];
          parentPhase.subPhaseEntries.push(...subPhaseEntries);
          parentPhase.entryCount += subPhaseEntries.length;
        }
      }
      
      // تجميع الاختبارات
      const testsSnap = await projectRef.collection('tests_status').get();
      for (const testDoc of testsSnap.docs) {
        const testData = testDoc.data();
        
        // فلترة حسب التاريخ
        if (startDate && endDate && testData.lastUpdatedAt) {
          if (testData.lastUpdatedAt < startDate || testData.lastUpdatedAt >= endDate) {
            continue;
          }
        }
        
        const testWithMeta = {
          id: testDoc.id,
          ...testData,
          collectionType: 'test'
        };
        
        // تجميع صور الاختبار
        if (testData.imageUrl) {
          imagesData.push({
            url: testData.imageUrl,
            source: 'test',
            testId: testDoc.id,
            testName: testData.name || testDoc.id,
            timestamp: testData.lastUpdatedAt,
            type: 'test_result'
          });
        }
        
        testsData.push(testWithMeta);
        summaryStats.totalTests++;
        if (testData.lastUpdatedAt && (!summaryStats.lastUpdated || testData.lastUpdatedAt > summaryStats.lastUpdated)) {
          summaryStats.lastUpdated = testData.lastUpdatedAt;
        }
      }
      
      // تجميع طلبات المواد
      let materialsQuery = db.collection('partRequests').where('projectId', '==', projectId);
      if (startDate && endDate) {
        materialsQuery = materialsQuery
          .where('requestedAt', '>=', startDate)
          .where('requestedAt', '<', endDate);
      }
      
      const materialsSnap = await materialsQuery.orderBy('requestedAt', 'desc').get();
      for (const materialDoc of materialsSnap.docs) {
        const materialData = materialDoc.data();
        const materialWithMeta = {
          id: materialDoc.id,
          ...materialData,
          collectionType: 'material_request'
        };
        
        materialsData.push(materialWithMeta);
        summaryStats.totalRequests++;
        if (materialData.requestedAt && (!summaryStats.lastUpdated || materialData.requestedAt > summaryStats.lastUpdated)) {
          summaryStats.lastUpdated = materialData.requestedAt;
        }
      }
      
      // حساب إجمالي الصور
      summaryStats.totalImages = imagesData.length;
      
    } catch (e) {
      console.error(`Error collecting data for project ${projectId}:`, e);
      throw e;
    }

    // إنشاء Snapshot منظم
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
        totalDataSize: JSON.stringify(snapshot).length,
        imageCount: imagesData.length,
        entryCount: summaryStats.totalEntries,
        testCount: summaryStats.totalTests,
        requestCount: summaryStats.totalRequests
      }
    };

    // حفظ Snapshot
    const snapshotRef = db.collection('report_snapshots').doc(projectId);
    if (startDate && endDate) {
      // حفظ تقرير محدد بفترة زمنية
      const timeRangeId = `${projectId}_${startDate.toDate().getTime()}_${endDate.toDate().getTime()}`;
      await db.collection('report_snapshots').doc(timeRangeId).set(snapshot);
      console.log(`Time-range snapshot saved for ${projectId}: ${timeRangeId}`);
    } else {
      // حفظ Snapshot شامل
      await snapshotRef.set(snapshot);
      console.log(`Full snapshot saved for ${projectId}`);
    }
    
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

// Firestore Triggers لتحديث Snapshot تلقائياً
exports.onProjectWrite = functions.firestore
  .document('projects/{projectId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Project ${projectId} changed, scheduling snapshot rebuild`);
    
    // تأخير 5 دقائق لتجميع التغييرات
    setTimeout(() => {
      buildReportSnapshot(projectId).catch(console.error);
    }, 300000);
  });

exports.onProjectItemWrite = functions.firestore
  .document('projects/{projectId}/{colId}/{docId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Project item ${projectId} changed, scheduling snapshot rebuild`);
    
    // تأخير دقيقتين لتجميع التغييرات
    setTimeout(() => {
      buildReportSnapshot(projectId).catch(console.error);
    }, 120000);
  });

// Trigger لإدخالات المراحل
exports.onPhaseEntryWrite = functions.firestore
  .document('projects/{projectId}/phases_status/{phaseId}/entries/{entryId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Phase entry ${context.params.entryId} changed for project ${projectId}, scheduling snapshot rebuild`);
    
    setTimeout(() => {
      buildReportSnapshot(projectId).catch(console.error);
    }, 60000);
  });

// Trigger لإدخالات المراحل الفرعية
exports.onSubPhaseEntryWrite = functions.firestore
  .document('projects/{projectId}/subphases_status/{subPhaseId}/entries/{entryId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Sub-phase entry ${context.params.entryId} changed for project ${projectId}, scheduling snapshot rebuild`);
    
    setTimeout(() => {
      buildReportSnapshot(projectId).catch(console.error);
    }, 60000);
  });

// Trigger للاختبارات
exports.onTestWrite = functions.firestore
  .document('projects/{projectId}/tests_status/{testId}')
  .onWrite(async (change, context) => {
    const projectId = context.params.projectId;
    console.log(`Test ${context.params.testId} changed for project ${projectId}, scheduling snapshot rebuild`);
    
    setTimeout(() => {
      buildReportSnapshot(projectId).catch(console.error);
    }, 60000);
  });

// Trigger لطلبات المواد
exports.onMaterialRequestWrite = functions.firestore
  .document('partRequests/{requestId}')
  .onWrite(async (change, context) => {
    const requestData = change.after.exists ? change.after.data() : change.before.data();
    if (requestData && requestData.projectId) {
      const projectId = requestData.projectId;
      console.log(`Material request ${context.params.requestId} changed for project ${projectId}, scheduling snapshot rebuild`);
      
      setTimeout(() => {
        buildReportSnapshot(projectId).catch(console.error);
      }, 60000);
    }
  });