import '../../../core/constants/app_constants.dart';

/// One parsed session inside a parsed subject (editable in the review screen).
class ParsedSession {
  String day; // "Monday".."Sunday"
  String start; // "HH:MM"
  String end; // "HH:MM"
  String? room;

  ParsedSession({
    required this.day,
    required this.start,
    required this.end,
    this.room,
  });

  int? get dayIndex => Weekdays.parse(day);

  factory ParsedSession.fromJson(Map<String, dynamic> json) => ParsedSession(
        day: (json['day'] as String?) ?? 'Monday',
        start: (json['start'] as String?) ?? '09:00',
        end: (json['end'] as String?) ?? '10:00',
        room: json['room'] as String?,
      );
}

/// One parsed subject with its sessions.
class ParsedSubject {
  String name;
  String? professor;
  String? classLink; // Zoom/Meet/Teams link (optional)
  DateTime? startDate; // optional term start
  DateTime? endDate; // optional term end
  List<ParsedSession> sessions;
  bool include; // user toggle in review screen

  ParsedSubject({
    required this.name,
    this.professor,
    this.classLink,
    this.startDate,
    this.endDate,
    required this.sessions,
    this.include = true,
  });

  factory ParsedSubject.fromJson(Map<String, dynamic> json) => ParsedSubject(
        name: (json['name'] as String?) ?? 'Untitled',
        professor: json['professor'] as String?,
        classLink: json['classLink'] as String? ?? json['link'] as String?,
        startDate: _parseDate(json['startDate']),
        endDate: _parseDate(json['endDate']),
        sessions: ((json['sessions'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ParsedSession.fromJson)
            .toList(),
      );

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}

/// Full result returned by the parseSchedule Cloud Function.
class ParsedSchedule {
  final List<ParsedSubject> subjects;
  final String confidence; // high | medium | low

  ParsedSchedule({required this.subjects, required this.confidence});

  factory ParsedSchedule.fromJson(Map<String, dynamic> json) => ParsedSchedule(
        subjects: ((json['subjects'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ParsedSubject.fromJson)
            .toList(),
        confidence: (json['confidence'] as String?) ?? 'low',
      );

  bool get isEmpty => subjects.isEmpty;
}
