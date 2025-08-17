import 'package:flutter/material.dart';
import '../../services/report_snapshot_service.dart';
import '../../theme/app_constants.dart';

class ReportSnapshotMigrationPage extends StatefulWidget {
  const ReportSnapshotMigrationPage({super.key});

  @override
  State<ReportSnapshotMigrationPage> createState() => _ReportSnapshotMigrationPageState();
}

class _ReportSnapshotMigrationPageState extends State<ReportSnapshotMigrationPage> {
  final ReportSnapshotService _service = ReportSnapshotService();
  double _progress = 0;
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _progress = 0;
    });
    await _service.rebuildAllSnapshots(onProgress: (p) {
      setState(() {
        _progress = p;
      });
    });
    if (!mounted) return;
    setState(() {
      _running = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اكتملت عملية بناء التقارير')),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بناء تقارير المشاريع'),
        backgroundColor: AppConstants.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_running)
              Padding(
                padding: const EdgeInsets.all(16),
                child: LinearProgressIndicator(value: _progress),
              ),
            ElevatedButton(
              onPressed: _running ? null : _run,
              child: const Text('Build Snapshots'),
            ),
          ],
        ),
      ),
    );
  }
}
