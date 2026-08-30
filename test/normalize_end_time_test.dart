import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/core/utils/date_utils.dart';

/// Guards the 12h→24h "PM slip" repair in [DateUtilsX.normalizeEndTime24],
/// which is applied on every [ClassSession.fromMap] read. This is the exact
/// bug that broke the "in progress" glow/progress bar: an AI import wrote a
/// 1:20 PM end time as "01:20", landing the end before the start.
void main() {
  group('normalizeEndTime24', () {
    test('repairs the reported case: 11:20–01:20 → 11:20–13:20', () {
      expect(DateUtilsX.normalizeEndTime24('11:20', '01:20'), '13:20');
    });

    test('repairs an early-afternoon PM slip: 13:00 written as 01:00', () {
      expect(DateUtilsX.normalizeEndTime24('12:30', '01:00'), '13:00');
    });

    test('still fixes the legacy noon-as-midnight case (00:00 → 12:00)', () {
      expect(DateUtilsX.normalizeEndTime24('09:00', '00:00'), '12:00');
      expect(DateUtilsX.normalizeEndTime24('11:20', '00:00'), '12:00');
    });

    test('leaves a valid session untouched', () {
      expect(DateUtilsX.normalizeEndTime24('09:00', '10:00'), '10:00');
      expect(DateUtilsX.normalizeEndTime24('11:20', '13:20'), '13:20');
    });

    test('leaves a genuine evening session ending near midnight untouched', () {
      // 20:00 → 00:00 (midnight): bumping to 12:00 would be wrong, so keep it.
      expect(DateUtilsX.normalizeEndTime24('20:00', '00:00'), '00:00');
    });

    test('leaves malformed input untouched', () {
      expect(DateUtilsX.normalizeEndTime24('bad', '01:20'), '01:20');
      expect(DateUtilsX.normalizeEndTime24('11:20', 'nope'), 'nope');
    });
  });
}
