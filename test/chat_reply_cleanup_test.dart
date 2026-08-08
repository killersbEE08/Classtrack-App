import 'package:classtrack/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the client-side cleanup that keeps raw action/JSON blocks out of
/// the chat bubble while still letting the app parse and run the actions.
///
/// Regression: asking the assistant to "delete all tasks" ran the deletes but
/// also dumped a big ```json copy of the action list into the reply. Only the
/// ```actions``` fence was stripped, so the JSON showed as raw text in the
/// (dark) chat bubble.
void main() {
  group('extractActionsFromReply still works', () {
    test('parses the actions fence so deletes run', () {
      const reply = 'Deleting those now.\n'
          '```actions\n'
          '{"actions":[{"type":"delete","entity":"task","match":"A"},'
          '{"type":"delete","entity":"task","match":"B"}]}\n'
          '```';
      final actions = GeminiService.extractActionsFromReply(reply);
      expect(actions.length, 2);
      expect(actions.first['type'], 'delete');
    });
  });

  group('display cleanup', () {
    String clean(String reply) {
      var c = GeminiService.stripScheduleBlock(reply);
      c = GeminiService.stripActionsBlock(c);
      c = GeminiService.stripAllCodeFences(c);
      c = GeminiService.stripBareActionsJson(c);
      return c;
    }

    test('removes an actions fence', () {
      const reply = 'All done. ✅\n```actions\n{"actions":[]}\n```';
      expect(clean(reply), 'All done. ✅');
    });

    test('removes a duplicate ```json block the model echoed', () {
      const reply = 'Deleted all your tasks.\n'
          '```json\n'
          '{"actions":[{"type":"delete","entity":"task","match":"A"}]}\n'
          '```';
      expect(clean(reply), 'Deleted all your tasks.');
    });

    test('removes an actions fence AND a following json duplicate', () {
      const reply = 'Cleared them for you.\n'
          '```actions\n{"actions":[{"type":"delete","entity":"task","match":"A"}]}\n```\n'
          '```json\n{"actions":[{"type":"delete","entity":"task","match":"A"}]}\n```';
      expect(clean(reply), 'Cleared them for you.');
    });

    test('removes a bare (unfenced) actions JSON object', () {
      const reply =
          'Okay, removing everything. {"actions": [{"type":"delete","entity":"task","match":"A"}]}';
      expect(clean(reply), 'Okay, removing everything.');
    });

    test('removes a trailing unclosed/truncated code fence', () {
      const reply = 'Working on it.\n```json\n{"actions":[{"type":"delete"';
      expect(clean(reply), 'Working on it.');
    });

    test('leaves ordinary prose untouched', () {
      const reply = 'You have 3 classes today and 2 tasks due. Good luck!';
      expect(clean(reply), reply);
    });
  });
}
