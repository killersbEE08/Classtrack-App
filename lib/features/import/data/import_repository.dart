import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/gemini_service.dart';
import '../../../services/google_calendar_service.dart';
import '../../schedule/data/session_repository.dart';
import '../../schedule/domain/class_session.dart';
import '../../subjects/data/subject_repository.dart';
import '../../subjects/domain/subject.dart';
import '../domain/google_calendar_mapper.dart';
import '../domain/parsed_schedule.dart';

/// Parses timetables via client-side Gemini and commits confirmed results.
class ImportRepository {
  final GeminiService _gemini;
  final GoogleCalendarService _calendar;
  final SubjectRepository _subjectRepo;
  final SessionRepository _sessionRepo;

  ImportRepository({
    required GeminiService gemini,
    required GoogleCalendarService calendar,
    required SubjectRepository subjectRepo,
    required SessionRepository sessionRepo,
  })  : _gemini = gemini,
        _calendar = calendar,
        _subjectRepo = subjectRepo,
        _sessionRepo = sessionRepo;

  bool get isConfigured => _gemini.isConfigured;

  Future<ParsedSchedule> parseText(String text) =>
      _gemini.parseSchedule(text: text);

  Future<ParsedSchedule> parseImage(Uint8List bytes) =>
      _gemini.parseSchedule(imageBytes: bytes);

  /// Signs the user into Google (read-only calendar scope) and turns their
  /// upcoming events into a reviewable weekly schedule. No AI/Gemini needed.
  Future<ParsedSchedule> parseGoogleCalendar() async {
    final events = await _calendar.fetchUpcomingEvents();
    return googleCalendarToSchedule(events);
  }

  /// Commit the reviewed schedule: create subjects + their sessions.
  /// Returns the number of subjects created.
  Future<int> commit(ParsedSchedule schedule) async {
    var created = 0;
    var colorIndex = 0;
    for (final ps in schedule.subjects) {
      if (!ps.include) continue;
      final color =
          AppColors.subjectPalette[colorIndex % AppColors.subjectPalette.length];
      colorIndex++;

      final subjectId = _subjectRepo.newId();
      await _subjectRepo.setWithId(
        subjectId,
        Subject(
          id: subjectId,
          name: ps.name.trim().isEmpty ? 'Untitled' : ps.name.trim(),
          colorHex: color.value,
          professor: ps.professor?.trim().isEmpty == true ? null : ps.professor,
          classLink:
              ps.classLink?.trim().isEmpty == true ? null : ps.classLink?.trim(),
          startDate: ps.startDate,
          endDate: ps.endDate,
        ),
      );

      for (final sess in ps.sessions) {
        final dayIdx = sess.dayIndex ?? 0;
        final id = const Uuid().v4();
        await _sessionRepo.setWithId(
          subjectId,
          id,
          ClassSession(
            id: id,
            subjectId: subjectId,
            recurring: true,
            dayOfWeek: dayIdx,
            startTime: sess.start,
            endTime: sess.end,
            room: sess.room,
          ),
        );
      }
      created++;
    }
    return created;
  }
}
