import 'package:cloud_firestore/cloud_firestore.dart';

/// A completed focus/study session. Stored at users/{uid}/studySessions/{id}.
class StudySession {
  final String id;
  final String? subjectId;
  final DateTime startedAt;
  final int minutes;
  final DateTime? createdAt;

  const StudySession({
    required this.id,
    this.subjectId,
    required this.startedAt,
    required this.minutes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'subjectId': subjectId,
        'startedAt': Timestamp.fromDate(startedAt),
        'minutes': minutes,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory StudySession.fromMap(String id, Map<String, dynamic> map) {
    return StudySession(
      id: id,
      subjectId: map['subjectId'] as String?,
      startedAt:
          (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      minutes: (map['minutes'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
