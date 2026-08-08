import 'package:classtrack/features/import/data/import_repository.dart';
import 'package:classtrack/features/import/domain/google_tasks_mapper.dart';
import 'package:classtrack/features/tasks/domain/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure Google Tasks -> task-item mapper and its re-import
/// de-duplication.
Map<String, dynamic> gtask({
  String? id,
  String? title,
  String? notes,
  String? due,
  String? status,
  bool? deleted,
  List<Map<String, dynamic>>? links,
}) =>
    <String, dynamic>{
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (due != null) 'due': due,
      if (status != null) 'status': status,
      if (deleted != null) 'deleted': deleted,
      if (links != null) 'links': links,
    };

void main() {
  group('googleTasksToItems', () {
    test('empty input -> no items', () {
      expect(googleTasksToItems(const []), isEmpty);
    });

    test('maps title, notes, done flag, due date, id and link', () {
      final items = googleTasksToItems([
        gtask(
          id: 't1',
          title: 'Submit report',
          notes: 'Chapter 3',
          due: '2026-08-06T00:00:00.000Z',
          status: 'needsAction',
          links: [
            {'link': 'https://example.com/doc', 'type': 'email'}
          ],
        ),
      ]);
      expect(items.length, 1);
      final t = items.single;
      expect(t.title, 'Submit report');
      expect(t.note, 'Chapter 3');
      expect(t.done, isFalse);
      expect(t.due, DateTime(2026, 8, 6)); // date-only, no tz shift
      expect(t.sourceId, 't1');
      expect(t.link, 'https://example.com/doc');
    });

    test('completed status maps to done', () {
      final items = googleTasksToItems([
        gtask(id: 't2', title: 'Done thing', status: 'completed'),
      ]);
      expect(items.single.done, isTrue);
    });

    test('deleted tasks are skipped', () {
      final items = googleTasksToItems([
        gtask(id: 't3', title: 'Gone', deleted: true),
      ]);
      expect(items, isEmpty);
    });

    test('missing title -> Untitled task; missing due -> null', () {
      final items = googleTasksToItems([gtask(id: 't4')]);
      expect(items.single.title, 'Untitled task');
      expect(items.single.due, isNull);
    });

    test('duplicate ids within one response collapse to one', () {
      final items = googleTasksToItems([
        gtask(id: 'dup', title: 'A'),
        gtask(id: 'dup', title: 'A'),
      ]);
      expect(items.length, 1);
    });
  });

  group('ImportRepository.filterNewGoogleTasks (re-import de-dup)', () {
    GoogleTaskItem item({required String title, String? sourceId, DateTime? due}) =>
        GoogleTaskItem(title: title, sourceId: sourceId, due: due);

    TaskItem existingTask({required String title, String? sourceId, DateTime? due}) =>
        TaskItem(id: 'x', title: title, sourceId: sourceId, dueDate: due);

    test('first import: everything is new', () {
      final fresh = ImportRepository.filterNewGoogleTasks(
        [item(title: 'A', sourceId: 'a'), item(title: 'B', sourceId: 'b')],
        const [],
      );
      expect(fresh.length, 2);
    });

    test('second import of the same tasks adds nothing (id match)', () {
      final fresh = ImportRepository.filterNewGoogleTasks(
        [item(title: 'A', sourceId: 'a', due: DateTime(2026, 8, 6))],
        [existingTask(title: 'A', sourceId: 'a', due: DateTime(2026, 8, 6))],
      );
      expect(fresh, isEmpty);
    });

    test('matches a source-less existing task by title + date', () {
      final fresh = ImportRepository.filterNewGoogleTasks(
        [item(title: 'Read', sourceId: 'r1', due: DateTime(2026, 8, 6))],
        [existingTask(title: 'Read', due: DateTime(2026, 8, 6))],
      );
      expect(fresh, isEmpty);
    });

    test('a brand-new task is added on a later import', () {
      final fresh = ImportRepository.filterNewGoogleTasks(
        [item(title: 'A', sourceId: 'a'), item(title: 'C', sourceId: 'c')],
        [existingTask(title: 'A', sourceId: 'a')],
      );
      expect(fresh.map((e) => e.title), ['C']);
    });
  });
}
