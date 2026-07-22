import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classtrack/core/utils/date_utils.dart';
import 'package:classtrack/features/insights/domain/insight_math.dart';
import 'package:classtrack/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:classtrack/services/gemini_service.dart';

void main() {
  group('normalizeEndTime24 (noon AM/PM fix)', () {
    test('morning start ending at midnight is treated as noon', () {
      expect(DateUtilsX.normalizeEndTime24('11:00', '00:00'), '12:00');
      expect(DateUtilsX.normalizeEndTime24('09:00', '00:00'), '12:00');
    });

    test('genuine late-evening class ending at midnight is untouched', () {
      expect(DateUtilsX.normalizeEndTime24('23:00', '00:00'), '00:00');
    });

    test('normal ranges are left alone', () {
      expect(DateUtilsX.normalizeEndTime24('09:00', '10:00'), '10:00');
      expect(DateUtilsX.normalizeEndTime24('14:00', '15:30'), '15:30');
    });
  });

  group('AI action parsing (invisible function calling)', () {
    test('extracts actions from a fenced block', () {
      const reply = 'Done — logged it.\n'
          '```actions\n'
          '{ "actions": [ {"type":"expense","title":"Food","amount":20,"category":"food"} ] }\n'
          '```';
      final actions = GeminiService.extractActionsFromReply(reply);
      expect(actions.length, 1);
      expect(actions.first['type'], 'expense');
      expect(actions.first['amount'], 20);
    });

    test('returns empty list when no actions block is present', () {
      expect(GeminiService.extractActionsFromReply('just chatting'), isEmpty);
    });

    test('strips the actions block from the visible prose', () {
      const reply = 'Added your exam.\n```actions\n{"actions":[]}\n```';
      expect(GeminiService.stripActionsBlock(reply), 'Added your exam.');
    });

    test('malformed JSON does not throw and yields no actions', () {
      const reply = '```actions\n{not valid json}\n```';
      expect(GeminiService.extractActionsFromReply(reply), isEmpty);
    });
  });

  group('entitlementIsActive (Pro flag + proUntil gifts)', () {
    test('null or empty data is not Pro', () {
      expect(entitlementIsActive(null), isFalse);
      expect(entitlementIsActive(<String, dynamic>{}), isFalse);
    });

    test('permanent pro:true flag is Pro', () {
      expect(entitlementIsActive({'pro': true}), isTrue);
    });

    test('pro:false without a valid proUntil is not Pro', () {
      expect(entitlementIsActive({'pro': false}), isFalse);
    });

    test('future proUntil (Timestamp) is Pro even when pro:false', () {
      final future = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)));
      expect(entitlementIsActive({'pro': false, 'proUntil': future}), isTrue);
    });

    test('future proUntil (millis number) is Pro', () {
      final future =
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
      expect(entitlementIsActive({'proUntil': future}), isTrue);
    });

    test('past proUntil is not Pro', () {
      final past = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)));
      expect(entitlementIsActive({'pro': false, 'proUntil': past}), isFalse);
    });
  });

  group('attendanceAdvice (predictions)', () {
    test('no data is trivially on track', () {
      final a = attendanceAdvice(attended: 0, held: 0, target: 75);
      expect(a.onTrack, isTrue);
      expect(a.canSkip, 0);
    });

    test('above target reports safe skips', () {
      // 18/20 = 90%; at 75% target you can miss up to 4 (18/24 = 75%).
      final a = attendanceAdvice(attended: 18, held: 20, target: 75);
      expect(a.onTrack, isTrue);
      expect(a.percent, closeTo(90, 0.01));
      expect(a.canSkip, 4);
      expect(a.mustAttend, 0);
    });

    test('below target reports classes to attend', () {
      // 6/10 = 60%; to reach 75%: need n where (6+n)/(10+n) >= .75 → n>=6.
      final a = attendanceAdvice(attended: 6, held: 10, target: 75);
      expect(a.onTrack, isFalse);
      expect(a.mustAttend, 6);
    });

    test('100% target with a miss is unreachable', () {
      final a = attendanceAdvice(attended: 9, held: 10, target: 100);
      expect(a.unreachable, isTrue);
      expect(a.onTrack, isFalse);
    });
  });

  group('projectedMonthlySpend', () {
    test('extrapolates the daily rate across the month', () {
      // Day 10 of a 30-day month, spent 100 → projected 300.
      final p = projectedMonthlySpend(
          spentSoFar: 100, now: DateTime(2026, 6, 10));
      expect(p, closeTo(300, 0.01));
    });

    test('zero spend projects zero', () {
      final p =
          projectedMonthlySpend(spentSoFar: 0, now: DateTime(2026, 6, 15));
      expect(p, 0);
    });
  });
}
