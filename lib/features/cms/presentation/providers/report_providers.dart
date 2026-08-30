import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/report_repository.dart';
import '../../domain/content_report.dart';

/// Report repository bound to the signed-in user (null when signed out).
/// Shared by the student "Report" action (create) and the CMS moderation queue
/// (read/update); Firestore rules gate what each role may actually do.
final reportRepositoryProvider = Provider<ReportRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ReportRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// The moderation queue — all reports, newest first (empty when signed out or
/// lacking read permission).
final cmsReportsProvider = StreamProvider<List<ContentReport>>((ref) {
  final repo = ref.watch(reportRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll();
});
