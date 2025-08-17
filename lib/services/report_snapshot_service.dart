import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for working with precomputed report snapshots.
class ReportSnapshotService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ReportSnapshotService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Fetches the snapshot document for [projectId].
  Future<Map<String, dynamic>?> fetchSnapshot(String projectId) async {
    final doc = await _firestore.collection('report_snapshots').doc(projectId).get();
    return doc.data();
  }

  /// Calls the cloud function to rebuild the snapshot for [projectId].
  Future<void> rebuildSnapshot(String projectId) async {
    final callable = _functions.httpsCallable('buildReportSnapshot');
    await callable.call(<String, dynamic>{'projectId': projectId});
  }

  /// Rebuild snapshots for all projects in the database. Progress is reported
  /// via [onProgress] where the value is between 0 and 1.
  Future<void> rebuildAllSnapshots({void Function(double progress)? onProgress}) async {
    final projects = await _firestore.collection('projects').get();
    final total = projects.docs.length;
    int index = 0;
    for (final doc in projects.docs) {
      await rebuildSnapshot(doc.id);
      index++;
      onProgress?.call(index / total);
    }
  }
}
