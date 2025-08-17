# Rebuilding Report Snapshots

This project pre-computes project report data in the `report_snapshots/{projectId}`
collection. Each snapshot contains all text, stats and thumbnail paths required to
build a PDF instantly on the client.

## Rebuilding a single project

From the Project Details screen open the menu and choose **إعادة بناء التقرير**. This
invokes the `buildReportSnapshot` Cloud Function and refreshes the snapshot for the
current project.

## Migrating existing projects

Admins can rebuild all snapshots from the **Build Snapshots** button in the admin
settings.

Steps:

1. Open *إعدادات النظام* (Admin Settings).
2. Tap **Build Snapshots** to open the migration screen.
3. Press the **Build Snapshots** button. Progress will be displayed while each
   project is processed in sequence.

## Command line

Snapshots can also be built by calling the Cloud Function directly:

```bash
firebase functions:call buildReportSnapshot '{"projectId":"<id>"}'
```

## Notes

* Thumbnails are stored under `thumbnails/{projectId}/` and generated at most once.
* Clients have read-only access to `report_snapshots`; only Cloud Functions write.
* Snapshots are versioned using the `version` field for future schema changes.
