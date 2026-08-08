import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/schedule/domain/class_session.dart';
import 'package:classtrack/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:classtrack/features/subjects/domain/subject.dart';
import 'package:classtrack/features/subjects/presentation/providers/subject_providers.dart';

/// Mirrors the user's scenario exactly:
///   "Supply Chain" added on 31 Jul 2026, classes on Monday AND Friday,
///   running until 30 Aug 2026.
///
/// The Home screen's "Today's classes" reads [classesForDayProvider], so this
/// verifies the class is visible on Mondays/Fridays inside the term window and
/// invisible on other weekdays / outside the window.
void main() {
  const subjectId = 'supply-chain';
  const monday = 0; // Weekdays are 0=Mon .. 6=Sun in this app.
  const friday = 4;

  final subject = Subject(
    id: subjectId,
    name: 'Supply Chain',
    colorHex: 0xFF6366F1,
    startDate: DateTime(2026, 7, 31), // added on 31 Jul (a Friday)
    endDate: DateTime(2026, 8, 30), // runs "till 30 Aug"
  );

  const mondaySession = ClassSession(
    id: 'mon',
    subjectId: subjectId,
    recurring: true,
    dayOfWeek: monday,
    startTime: '09:00',
    endTime: '10:00',
  );
  const fridaySession = ClassSession(
    id: 'fri',
    subjectId: subjectId,
    recurring: true,
    dayOfWeek: friday,
    startTime: '09:00',
    endTime: '10:00',
  );

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(overrides: [
      subjectsStreamProvider.overrideWith((ref) => Stream.value([subject])),
      sessionsForSubjectProvider.overrideWith(
          (ref, id) => Stream.value([mondaySession, fridaySession])),
    ]);
    await container.read(subjectsStreamProvider.future);
    await container.read(sessionsForSubjectProvider(subjectId).future);
    return container;
  }

  test('visible on a Friday inside the term (31 Jul, the day it was added)',
      () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final classes =
        container.read(classesForDayProvider(DateTime(2026, 7, 31)));
    expect(classes.length, 1);
    expect(classes.single.subject.name, 'Supply Chain');
  });

  test('visible on a Monday inside the term (3 Aug)', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final classes =
        container.read(classesForDayProvider(DateTime(2026, 8, 3)));
    expect(classes.length, 1);
  });

  test('NOT visible on a Tuesday inside the term (4 Aug)', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final classes =
        container.read(classesForDayProvider(DateTime(2026, 8, 4)));
    expect(classes, isEmpty);
  });

  test('NOT visible on a Monday before the term starts (27 Jul)', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final classes =
        container.read(classesForDayProvider(DateTime(2026, 7, 27)));
    expect(classes, isEmpty);
  });

  test('NOT visible on a Monday after the term ends (7 Sep)', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final classes =
        container.read(classesForDayProvider(DateTime(2026, 9, 7)));
    expect(classes, isEmpty);
  });
}
