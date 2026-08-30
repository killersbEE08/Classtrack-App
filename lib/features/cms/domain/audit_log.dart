import 'package:cloud_firestore/cloud_firestore.dart';

/// A single privileged-action audit record from the `auditLogs` collection.
/// Written only by the backend (Admin SDK) — see functions/index.js.
class AuditLogEntry {
  final String id;
  final String actorUid;
  final String actorRole;
  final String? actorEmail;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> details;
  final DateTime? at;

  const AuditLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorRole,
    this.actorEmail,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.details = const {},
    this.at,
  });

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> m) {
    return AuditLogEntry(
      id: id,
      actorUid: (m['actorUid'] as String?) ?? 'unknown',
      actorRole: (m['actorRole'] as String?) ?? 'none',
      actorEmail: m['actorEmail'] as String?,
      action: (m['action'] as String?) ?? 'unknown',
      targetType: (m['targetType'] as String?) ?? '',
      targetId: (m['targetId'] as String?) ?? '',
      details: (m['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      at: (m['at'] as Timestamp?)?.toDate(),
    );
  }
}
