import 'package:classtrack/core/utils/shared_intake.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for de-duplicating links/text shared INTO the app. The key behaviour:
/// a *cold-start* re-delivery of an already-handled link (Android re-attaching
/// the original ACTION_SEND intent to the task on some launchers) is ignored,
/// while live shares and fresh links are always handled.
void main() {
  group('SharedIntake.signature', () {
    test('trims surrounding whitespace so re-deliveries still match', () {
      expect(SharedIntake.signature('  https://x.com/v  '),
          equals('https://x.com/v'));
    });
  });

  group('SharedIntake.shouldHandle', () {
    test('live shares are always handled (never de-duplicated)', () {
      expect(
        SharedIntake.shouldHandle(
          text: 'https://x.com/v',
          isColdStart: false,
          lastHandled: 'https://x.com/v', // same as before — still handled live
        ),
        isTrue,
      );
    });

    test('a fresh cold-start link (nothing handled yet) is handled', () {
      expect(
        SharedIntake.shouldHandle(
          text: 'https://x.com/v',
          isColdStart: true,
          lastHandled: null,
        ),
        isTrue,
      );
    });

    test('a cold-start link different from the last one is handled', () {
      expect(
        SharedIntake.shouldHandle(
          text: 'https://x.com/NEW',
          isColdStart: true,
          lastHandled: 'https://x.com/OLD',
        ),
        isTrue,
      );
    });

    test('a stale cold-start re-delivery of the last link is skipped', () {
      expect(
        SharedIntake.shouldHandle(
          text: '  https://x.com/v ',
          isColdStart: true,
          lastHandled: 'https://x.com/v',
        ),
        isFalse,
      );
    });

    test('empty / whitespace-only payloads are never handled', () {
      expect(
        SharedIntake.shouldHandle(
            text: '   ', isColdStart: false, lastHandled: null),
        isFalse,
      );
      expect(
        SharedIntake.shouldHandle(
            text: '', isColdStart: true, lastHandled: null),
        isFalse,
      );
    });
  });
}
