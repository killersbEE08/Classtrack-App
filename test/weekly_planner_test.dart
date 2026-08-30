import 'package:classtrack/features/planner/domain/planner_prompt.dart';
import 'package:classtrack/features/planner/domain/weekly_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure AI Weekly Planner logic (Pro): the ```plan JSON parser
/// and the prompt builder. No network or Gemini involved.
void main() {
  group('parseWeeklyPlan', () {
    test('parses a fenced plan block into ordered blocks grouped by day', () {
      const reply = '''
Here's your week! 🎯

```plan
{
  "summary": "Focus on DBMS before Friday's exam.",
  "blocks": [
    {"day": "2026-09-02", "start": "18:00", "end": "19:30", "title": "Revise indexing", "type": "revision", "subject": "DBMS", "reason": "Exam in 3 days"},
    {"day": "2026-09-01", "start": "20:00", "end": "20:30", "title": "Break", "type": "break"},
    {"day": "2026-09-01", "start": "17:00", "end": "18:00", "title": "Start assignment", "type": "task", "subject": "OS"}
  ]
}
```
''';
      final plan = parseWeeklyPlan(reply);
      expect(plan, isNotNull);
      expect(plan!.summary, "Focus on DBMS before Friday's exam.");
      expect(plan.blocks.length, 3);

      final byDay = plan.byDay;
      // Days sorted ascending.
      expect(byDay.keys.toList(), ['2026-09-01', '2026-09-02']);
      // Within 2026-09-01, sorted by start time (17:00 before 20:00).
      final firstDay = byDay['2026-09-01']!;
      expect(firstDay.first.title, 'Start assignment');
      expect(firstDay.first.kind, PlanBlockKind.task);
      expect(firstDay.last.kind, PlanBlockKind.breakTime);
    });

    test('returns null when there is no plan block', () {
      expect(parseWeeklyPlan('No plan here, sorry.'), isNull);
    });

    test('skips malformed blocks (missing title/day) but keeps valid ones', () {
      const reply = '''
```plan
{"blocks": [
  {"start": "10:00", "end": "11:00", "type": "study"},
  {"day": "2026-09-05", "start": "10:00", "end": "11:00", "title": "Mock test", "type": "review"}
]}
```
''';
      final plan = parseWeeklyPlan(reply)!;
      expect(plan.blocks.length, 1);
      expect(plan.blocks.single.title, 'Mock test');
      expect(plan.blocks.single.kind, PlanBlockKind.review);
    });

    test('block.date parses the yyyy-MM-dd day', () {
      const b = PlanBlock(
          day: '2026-09-05', start: '10:00', end: '11:00', title: 'x');
      expect(b.date, DateTime(2026, 9, 5));
    });
  });

  group('buildPlannerPrompt', () {
    final now = DateTime(2026, 8, 30, 12, 0);

    test('includes exams, tasks, timetable, free windows and the plan schema', () {
      final prompt = buildPlannerPrompt(
        now: now,
        exams: [
          PlannerExamInfo(
            title: 'DBMS Final',
            date: DateTime(2026, 9, 2),
            daysUntil: 3,
            readinessPercent: 40,
            topicsRemaining: 5,
          ),
        ],
        tasks: [
          PlannerTaskInfo(
            title: 'OS assignment',
            due: DateTime(2026, 9, 1),
            priority: 'High',
            overdue: false,
            subject: 'OS',
          ),
        ],
        timetableLines: const ['Monday: DBMS 09:00–10:00'],
        freeGapsByDay: const {'2026-08-31': '17:00–22:00'},
      );

      expect(prompt, contains('DBMS Final'));
      expect(prompt, contains('40% revised'));
      expect(prompt, contains('5 topics left'));
      expect(prompt, contains('OS assignment'));
      expect(prompt, contains('High priority'));
      expect(prompt, contains('Monday: DBMS 09:00–10:00'));
      expect(prompt, contains('2026-08-31: 17:00–22:00'));
      // Strict output contract.
      expect(prompt, contains('```plan'));
      expect(prompt, contains('"blocks"'));
    });

    test('handles empty data gracefully', () {
      final prompt = buildPlannerPrompt(
        now: now,
        exams: const [],
        tasks: const [],
        timetableLines: const [],
        freeGapsByDay: const {},
      );
      expect(prompt, contains('Upcoming exams: none'));
      expect(prompt, contains('Pending tasks/deadlines: none'));
      expect(prompt, contains('```plan'));
    });
  });
}
