import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/gemini_provider.dart';
import '../../../../services/google_calendar_service.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../data/import_repository.dart';

/// Google Calendar OAuth + fetch service. Long-lived; disposes its HTTP client.
final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  final service = GoogleCalendarService();
  ref.onDispose(service.dispose);
  return service;
});

final importRepositoryProvider = Provider<ImportRepository?>((ref) {
  final subjectRepo = ref.watch(subjectRepositoryProvider);
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final taskRepo = ref.watch(taskRepositoryProvider);
  if (subjectRepo == null || sessionRepo == null || taskRepo == null) {
    return null;
  }
  return ImportRepository(
    gemini: ref.watch(geminiServiceProvider),
    calendar: ref.watch(googleCalendarServiceProvider),
    subjectRepo: subjectRepo,
    sessionRepo: sessionRepo,
    taskRepo: taskRepo,
  );
});
