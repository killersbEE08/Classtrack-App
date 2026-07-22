import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_utils.dart';

/// A daily habit the student wants to build. Completions are stored as a list
/// of date ids ("yyyy-MM-dd"). Stored at users/{uid}/habits/{id}.
class Habit {
  final String id;
  final String title;
  final int colorHex;
  final List<String> completedDates;
  final int? reminderMinutes; // minutes since midnight for a daily reminder
  final DateTime? createdAt;

  const Habit({
    required this.id,
    required this.title,
    required this.colorHex,
    this.completedDates = const [],
    this.reminderMinutes,
    this.createdAt,
  });

  bool doneOn(DateTime day) => completedDates.contains(DateUtilsX.dateId(day));
  bool get doneToday => doneOn(DateTime.now());

  bool get hasReminder => reminderMinutes != null;
  int get reminderHour => (reminderMinutes ?? 0) ~/ 60;
  int get reminderMinute => (reminderMinutes ?? 0) % 60;

  int get totalDays => completedDates.toSet().length;

  /// Current consecutive-day streak ending today (or yesterday if today is not
  /// yet marked).
  int get streak {
    final set = completedDates.toSet();
    if (set.isEmpty) return 0;
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!set.contains(DateUtilsX.dateId(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var s = 0;
    while (set.contains(DateUtilsX.dateId(cursor))) {
      s++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return s;
  }

  Habit copyWith({
    String? title,
    int? colorHex,
    List<String>? completedDates,
    int? reminderMinutes,
    bool clearReminder = false,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      colorHex: colorHex ?? this.colorHex,
      completedDates: completedDates ?? this.completedDates,
      reminderMinutes:
          clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'colorHex': colorHex,
        'completedDates': completedDates,
        'reminderMinutes': reminderMinutes,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Habit.fromMap(String id, Map<String, dynamic> map) {
    return Habit(
      id: id,
      title: (map['title'] as String?) ?? 'Habit',
      colorHex: (map['colorHex'] as num?)?.toInt() ?? 0xFF6C5CE7,
      completedDates: ((map['completedDates'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      reminderMinutes: (map['reminderMinutes'] as num?)?.toInt(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
