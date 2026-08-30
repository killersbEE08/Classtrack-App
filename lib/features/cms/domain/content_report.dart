import 'package:cloud_firestore/cloud_firestore.dart';

/// Why a student flagged a resource (PRD §9 / moderation).
enum ReportReason {
  deadlinePassed('deadline_passed', 'Deadline has passed'),
  brokenLink('broken_link', "Link doesn't work"),
  incorrectInfo('incorrect_info', 'Information is incorrect'),
  discontinued('discontinued', 'Opportunity discontinued'),
  notForStudents('not_for_students', 'Not actually for students'),
  other('other', 'Other');

  const ReportReason(this.key, this.label);
  final String key;
  final String label;

  static ReportReason fromKey(String? k) =>
      values.firstWhere((r) => r.key == k, orElse: () => ReportReason.other);
}

/// Moderation lifecycle of a report.
enum ReportStatus {
  open('open', 'Open'),
  underReview('under_review', 'Under review'),
  resolved('resolved', 'Resolved'),
  dismissed('dismissed', 'Dismissed');

  const ReportStatus(this.key, this.label);
  final String key;
  final String label;

  /// Still needs attention (shown in the default moderation queue).
  bool get isActive => this == open || this == underReview;

  static ReportStatus fromKey(String? k) =>
      values.firstWhere((s) => s.key == k, orElse: () => ReportStatus.open);
}

/// A user-submitted report against a [Resource], stored in `reports/{id}`.
///
/// The reporting user's uid is stored for de-duplication/audit but the CMS UI
/// avoids surfacing it prominently (privacy). `resourceTitle` is denormalised
/// so the moderation queue needs no extra reads.
class ContentReport {
  final String id;
  final String resourceId;
  final String resourceTitle;
  final String reporterUid;
  final ReportReason reason;
  final String? message;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? resolution;
  final DateTime? createdAt;

  const ContentReport({
    required this.id,
    required this.resourceId,
    required this.resourceTitle,
    required this.reporterUid,
    required this.reason,
    this.message,
    this.status = ReportStatus.open,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
    this.createdAt,
  });

  factory ContentReport.fromMap(String id, Map<String, dynamic> m) {
    DateTime? ts(dynamic v) => (v as Timestamp?)?.toDate();
    return ContentReport(
      id: id,
      resourceId: (m['resourceId'] as String?) ?? '',
      resourceTitle: (m['resourceTitle'] as String?) ?? '',
      reporterUid: (m['reporterUid'] as String?) ?? '',
      reason: ReportReason.fromKey(m['reason'] as String?),
      message: (m['message'] as String?),
      status: ReportStatus.fromKey(m['status'] as String?),
      reviewedBy: m['reviewedBy'] as String?,
      reviewedAt: ts(m['reviewedAt']),
      resolution: m['resolution'] as String?,
      createdAt: ts(m['createdAt']),
    );
  }

  /// Payload a student writes when filing a report. `status` is forced to open
  /// and `reporterUid` must match the caller (enforced by security rules).
  Map<String, dynamic> toCreateMap() => {
        'resourceId': resourceId,
        'resourceTitle': resourceTitle,
        'reporterUid': reporterUid,
        'reason': reason.key,
        if (message != null && message!.trim().isNotEmpty)
          'message': message!.trim(),
        'status': ReportStatus.open.key,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Open/under-review report count per resource id (for the moderation queue and
/// per-resource badges). Pure — unit-testable without Firestore.
Map<String, int> activeReportCountsByResource(List<ContentReport> reports) {
  final out = <String, int>{};
  for (final r in reports) {
    if (!r.status.isActive) continue;
    out[r.resourceId] = (out[r.resourceId] ?? 0) + 1;
  }
  return out;
}
