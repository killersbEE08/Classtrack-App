import 'package:classtrack/features/planner/domain/planner_engine.dart';
import 'package:classtrack/features/planner/domain/planner_prompt.dart';
import 'package:classtrack/features/planner/domain/weekly_plan.dart';
import 'package:classtrack/features/planner/presentation/providers/planner_providers.dart';
import 'package:flutter_test/flutter_test.dart';

int _min(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

void main() {
  // Monday 2026-08-31, 09:00.
  final now = DateTime(2026, 8, 31, 9, 0);

  group('buildDeterministicPlan', () {
    test('empty when there are no exams and no tasks', () {
      final plan = buildDeterministicPlan(
        now: now,
        exams: const [],
        tasks: const [],
        freeWindowsByDay: const {},
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.summary, isNotNull);
    });

    test('schedules revision for an upcoming exam inside free windows', () {
      final plan = buildDeterministicPlan(
        now: now,
        exams: [
          PlannerExamInfo(
            title: 'DBMS',
            date: DateTime(2026, 9, 2, 10, 0),
            daysUntil: 2,
            readinessPercent: 20,
            topicsRemaining: 4,
          ),
        ],
        tasks: const [],
        freeWindowsByDay: const {
          '2026-08-31': [(17 * 60, 21 * 60)],
          '2026-09-01': [(17 * 60, 21 * 60)],
          '2026-09-02': [(17 * 60, 21 * 60)],
        },
      );
      expect(plan.isEmpty, isFalse);
      final revision =
          plan.blocks.where((b) => b.kind == PlanBlockKind.revision).toList();
      expect(revision, isNotEmpty);
      expect(revision.every((b) => b.title == 'Revise DBMS'), isTrue);
      // Every revision block sits inside the day's 17:00–21:00 window.
      for (final b in revision) {
        expect(_min(b.start), greaterThanOrEqualTo(17 * 60));
        expect(_min(b.end), lessThanOrEqualTo(21 * 60));
      }
    });

    test('schedules an overdue high-priority task on day one', () {
      final plan = buildDeterministicPlan(
        now: now,
        exams: const [],
        tasks: [
          PlannerTaskInfo(
            title: 'Essay',
            due: DateTime(2026, 8, 28),
            priority: 'High',
            overdue: true,
            subject: 'English',
          ),
        ],
        freeWindowsByDay: const {
          '2026-08-31': [(17 * 60, 19 * 60)],
        },
      );
      final tasks =
          plan.blocks.where((b) => b.kind == PlanBlockKind.task).toList();
      expect(tasks, isNotEmpty);
      expect(tasks.first.title, 'Work on Essay');
      expect(tasks.first.day, '2026-08-31');
      expect(tasks.first.subject, 'English');
    });

    test('never exceeds the per-day block cap and stays within windows', () {
      // A single long window with many tasks — capped at maxBlocksPerDay (4).
      final plan = buildDeterministicPlan(
        now: now,
        exams: const [],
        tasks: [
          for (var i = 0; i < 10; i++)
            PlannerTaskInfo(
              title: 'Task $i',
              due: DateTime(2026, 8, 31),
              priority: 'High',
              overdue: true,
            ),
        ],
        freeWindowsByDay: const {
          '2026-08-31': [(8 * 60, 22 * 60)],
        },
        maxBlocksPerDay: 4,
      );
      final study = plan.blocks
          .where((b) => b.kind != PlanBlockKind.breakTime && b.day == '2026-08-31')
          .toList();
      expect(study.length, lessThanOrEqualTo(4));
      for (final b in study) {
        expect(_min(b.start), greaterThanOrEqualTo(8 * 60));
        expect(_min(b.end), lessThanOrEqualTo(22 * 60));
      }
    });

    test('blocks within a day do not overlap', () {
      final plan = buildDeterministicPlan(
        now: now,
        exams: const [],
        tasks: [
          for (var i = 0; i < 4; i++)
            PlannerTaskInfo(
              title: 'T$i',
              due: DateTime(2026, 8, 31),
              priority: 'High',
              overdue: true,
            ),
        ],
        freeWindowsByDay: const {
          '2026-08-31': [(9 * 60, 15 * 60)],
        },
      );
      final dayBlocks = plan.byDay['2026-08-31']!;
      for (var i = 0; i < dayBlocks.length - 1; i++) {
        expect(_min(dayBlocks[i].end),
            lessThanOrEqualTo(_min(dayBlocks[i + 1].start)));
      }
    });
  });

  group('freeWindowsFromBusy', () {
    test('returns gaps around class intervals within the waking day', () {
      final w = freeWindowsFromBusy([(9 * 60, 10 * 60), (11 * 60, 12 * 60)]);
      expect(w, [
        (8 * 60, 9 * 60),
        (10 * 60, 11 * 60),
        (12 * 60, 22 * 60),
      ]);
    });

    test('a fully free day is one big window', () {
      final w = freeWindowsFromBusy(const []);
      expect(w, [(8 * 60, 22 * 60)]);
    });

    test('ignores sub-30-minute gaps', () {
      // A 20-minute gap between 09:40 and 10:00 is too small to keep.
      final w = freeWindowsFromBusy([(8 * 60, 9 * 60 + 40), (10 * 60, 22 * 60)]);
      expect(w.any((e) => e.$1 == 9 * 60 + 40 && e.$2 == 10 * 60), isFalse);
    });
  });
}
