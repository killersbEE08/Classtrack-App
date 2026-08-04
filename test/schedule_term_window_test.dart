import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/schedule/domain/class_session.dart';
import 'package:classtrack/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:classtrack/features/subjects/domain/subject.dart';
import 'package:classtrack/features/subjects/presentation/providers/subject_providers.dart';

/// Regression test for the bug where the Week view showed a recurring class
/// even when the subject's course had not started yet (or had already ended).
///
/// The Week view now renders real calendar dates via [classesForDayProvider],
/// which must respect each subject's start/end term window. These three probe
/// dates all fall on the same weekday as the recurring session, so only the
/// term window can distinguish them.
void main() {
  const subjectId = 's1';

  // 2026-07-28, 2026-08-11 and 2026-09-08 are all the same weekday
  // (14 and 42 days apart — both multiples of 7).
  final probe = DateTime(2026, 7, 28); // "today" in the user's report
  final weekday0 = probe.weekday - 1; // 0 = Monday

  final subject = Subject(
    id: subjectId,
    name: 'Thermodynamics',
    colorHex: 0xFF6366F1,
    startDate: DateTime(2026, 8, 7), // term starts AFTER "today"
    endDate: DateTime(2026, 8, 31),
  );

  final session = ClassSession(
    id: 'sess1',
    subjectId: subjectId,
    recurring: true,
    dayOfWeek: weekday0,
    startTime: '09:00',
    endTime: '10:00',
  );

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(overrides: [
      subjectsStreamProvider.overrideWith((ref) => Stream.value([subject])),
      sessionsForSubjectProvider
          .overrideWith((ref, id) => Stream.value([session])),
    ]);
    // Let the overridden streams emit before reading the derived sync providers.
    await container.read(subjectsStreamProvider.future);
    await container.read(sessionsForSubjectProvider(subjectId).future);
    return container;
  }

  test('recurring class is hidden before the subject term starts', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    // 2026-07-28 is before the 2026-08-07 start date.
    final classes = container.read(classesForDayProvider(DateTime(2026, 7, 28)));
    expect(classes, isEmpty);
  });

  test('recurring class shows within the subject term', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    // 2026-08-11 is within [2026-08-07, 2026-08-31].
    final classes = container.read(classesForDayProvider(DateTime(2026, 8, 11)));
    expect(classes.length, 1);
    expect(classes.single.subject.id, subjectId);
  });

  test('recurring class is hidden after the subject term ends', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);

    // 2026-09-08 is after the 2026-08-31 end date.
    final classes = container.read(classesForDayProvider(DateTime(2026, 9, 8)));
    expect(classes, isEmpty);
  });
}
