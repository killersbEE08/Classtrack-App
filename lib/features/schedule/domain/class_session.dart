import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_utils.dart';

/// A scheduled class. Stored at users/{uid}/subjects/{subjectId}/sessions/{id}.
///
/// A session is either recurring (weekly on [dayOfWeek]) or a one-off on
/// [specificDate]. Recurring sessions can have exception dates in
/// [cancelledOn] (e.g. a holiday).
class ClassSession {
  final String id;
  final String subjectId;
  final bool recurring;
  final int? dayOfWeek; // 0..6 (Mon..Sun) when recurring
  final DateTime? specificDate; // when one-off
  final String startTime; // "HH:MM"
  final String endTime; // "HH:MM"
  final String? room;
  final List<DateTime> cancelledOn;

  const ClassSession({
    required this.id,
    required this.subjectId,
    required this.recurring,
    this.dayOfWeek,
    this.specificDate,
    required this.startTime,
    required this.endTime,
    this.room,
    this.cancelledOn = const [],
  });

  ClassSession copyWith({
    bool? recurring,
    int? dayOfWeek,
    DateTime? specificDate,
    String? startTime,
    String? endTime,
    String? room,
    List<DateTime>? cancelledOn,
  }) {
    return ClassSession(
      id: id,
      subjectId: subjectId,
      recurring: recurring ?? this.recurring,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      specificDate: specificDate ?? this.specificDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      cancelledOn: cancelledOn ?? this.cancelledOn,
    );
  }

  /// A content fingerprint used to detect identical (duplicate) sessions.
  /// Two sessions with the same signature describe the same class slot, so we
  /// can safely skip re-adding them and avoid showing them twice.
  String get signature {
    final date =
        specificDate == null ? '' : DateUtils0.dateOnly(specificDate!).toIso8601String();
    return '$recurring|$dayOfWeek|$date|$startTime|$endTime|${room ?? ''}';
  }

  /// Does this session occur on [date]?
  bool occursOn(DateTime date) {    final day = DateUtils0.dateOnly(date);
    if (cancelledOn.any((d) => DateUtilsX.isSameDay(d, day))) return false;
    if (recurring) {
      return dayOfWeek != null && (day.weekday - 1) == dayOfWeek;
    }
    return specificDate != null && DateUtilsX.isSameDay(specificDate!, day);
  }

  Map<String, dynamic> toMap() => {
        'recurring': recurring,
        'dayOfWeek': dayOfWeek,
        'specificDate':
            specificDate != null ? Timestamp.fromDate(specificDate!) : null,
        'startTime': startTime,
        'endTime': endTime,
        'room': room,
        'cancelledOn':
            cancelledOn.map((d) => Timestamp.fromDate(d)).toList(),
      };

  factory ClassSession.fromMap(
    String id,
    String subjectId,
    Map<String, dynamic> map,
  ) {
    return ClassSession(
      id: id,
      subjectId: subjectId,
      recurring: (map['recurring'] as bool?) ?? true,
      dayOfWeek: (map['dayOfWeek'] as num?)?.toInt(),
      specificDate: (map['specificDate'] as Timestamp?)?.toDate(),
      startTime: (map['startTime'] as String?) ?? '09:00',
      endTime: DateUtilsX.normalizeEndTime24(
        (map['startTime'] as String?) ?? '09:00',
        (map['endTime'] as String?) ?? '10:00',
      ),
      room: map['room'] as String?,
      cancelledOn: ((map['cancelledOn'] as List<dynamic>?) ?? [])
          .whereType<Timestamp>()
          .map((t) => t.toDate())
          .toList(),
    );
  }
}

/// Small local alias to avoid importing material just for dateOnly.
class DateUtils0 {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
