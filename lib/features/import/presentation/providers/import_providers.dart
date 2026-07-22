import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/gemini_provider.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../data/import_repository.dart';

final importRepositoryProvider = Provider<ImportRepository?>((ref) {
  final subjectRepo = ref.watch(subjectRepositoryProvider);
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  if (subjectRepo == null || sessionRepo == null) return null;
  return ImportRepository(
    gemini: ref.watch(geminiServiceProvider),
    subjectRepo: subjectRepo,
    sessionRepo: sessionRepo,
  );
});
