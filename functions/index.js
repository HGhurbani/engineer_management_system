const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sharp = require('sharp');

admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

const THUMB_MAX = 800;
const THUMB_QUALITY = 80;
const SNAPSHOT_VERSION = 1;

async function buildSnapshot(projectId) {
  const projectRef = db.collection('projects').doc(projectId);
  const projectSnap = await projectRef.get();
  if (!projectSnap.exists) {
    console.log(`Project ${projectId} missing`);
    return;
  }
  const project = projectSnap.data();

  const sectionsSnap = await projectRef.collection('sections').get();
  const sections = [];
  for (const sec of sectionsSnap.docs) {
    const data = sec.data();
    const imagesMeta = data.images || [];
    const processedImages = [];
    for (const imgMeta of imagesMeta) {
      const originalPath = imgMeta.path;
      const thumbPath = `thumbnails/${projectId}/${imgMeta.id}.jpg`;
      const thumbFile = bucket.file(thumbPath);
      const [exists] = await thumbFile.exists();
      if (!exists) {
        const [bytes] = await bucket.file(originalPath).download();
        const resized = await sharp(bytes)
          .resize({ width: THUMB_MAX, height: THUMB_MAX, fit: 'inside' })
          .jpeg({ quality: THUMB_QUALITY })
          .toBuffer();
        await thumbFile.save(resized, {
          contentType: 'image/jpeg',
        });
      }
      processedImages.push({
        id: imgMeta.id,
        caption: imgMeta.caption || null,
        thumbPath,
      });
    }
    sections.push({
      id: sec.id,
      title: data.title || '',
      body: data.body || '',
      images: processedImages,
    });
  }

  const snapshot = {
    version: SNAPSHOT_VERSION,
    summary: project.summary || '',
    stats: project.stats || {},
    sections,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('report_snapshots').doc(projectId).set(snapshot);
  console.log(`Snapshot built for ${projectId}`);
}

exports.buildReportSnapshot = functions.https.onCall(async (data, context) => {
  const projectId = data.projectId;
  if (!projectId) {
    throw new functions.https.HttpsError('invalid-argument', 'projectId is required');
  }
  await buildSnapshot(projectId);
});

// --- Debounced triggers ---
const pending = {};
function scheduleBuild(projectId) {
  if (pending[projectId]) {
    clearTimeout(pending[projectId]);
  }
  pending[projectId] = setTimeout(() => {
    buildSnapshot(projectId).catch(console.error);
    delete pending[projectId];
  }, 60000); // 60s debounce
}

exports.onProjectWrite = functions.firestore
  .document('projects/{projectId}')
  .onWrite(async (change, context) => {
    scheduleBuild(context.params.projectId);
  });

exports.onProjectItemWrite = functions.firestore
  .document('projects/{projectId}/{colId}/{docId}')
  .onWrite(async (change, context) => {
    scheduleBuild(context.params.projectId);
  });
