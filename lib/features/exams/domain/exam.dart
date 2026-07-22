import 'package:cloud_firestore/cloud_firestore.dart';

/// A scheduled exam / test. Stored at users/{uid}/exams/{id}.
class Exam {
  final String id;
  final String title;
  final String? subjectId;
  final DateTime date; // date + time of the exam
  final String? room;
  final String? note; // syllabus / topics
  final DateTime? createdAt;

  const Exam({
    required this.id,
    required this.title,
    this.subjectId,
    required this.date,
    this.room,
    this.note,
    this.createdAt,
  });

  /// Whole days from today (date-only) until the exam. Negative if past.
  int get daysUntil {
    final now = DateTime.now();
    final examDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return examDay.difference(today).inDays;
  }

  bool get isPast => date.isBefore(DateTime.now());

  String get countdownLabel {
    final d = daysUntil;
    if (d < 0) return 'Done';
    if (d == 0) return 'Today';
    if (d == 1) return 'Tomorrow';
    return 'in $d days';
  }

  Exam copyWith({
    String? title,
    String? subjectId,
    DateTime? date,
    String? room,
    String? note,
    bool clearSubject = false,
    bool clearRoom = false,
    bool clearNote = false,
  }) {
    return Exam(
      id: id,
      title: title ?? this.title,
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      date: date ?? this.date,
      room: clearRoom ? null : (room ?? this.room),
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'subjectId': subjectId,
        'date': Timestamp.fromDate(date),
        'room': room,
        'note': note,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Exam.fromMap(String id, Map<String, dynamic> map) {
    return Exam(
      id: id,
      title: (map['title'] as String?) ?? 'Exam',
      subjectId: map['subjectId'] as String?,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      room: map['room'] as String?,
      note: map['note'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
