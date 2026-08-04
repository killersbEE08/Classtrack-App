import 'package:classtrack/features/subjects/domain/subject.dart';
import 'package:flutter_test/flutter_test.dart';

/// The per-subject attendance target: a subject uses its own [targetPercent]
/// when set, otherwise the caller-supplied global fallback. Also verifies the
/// value survives a Firestore map round-trip (null => follow global).
void main() {
  Subject subject({double? target}) => Subject(
        id: 's1',
        name: 'DBMS Lab',
        colorHex: 0xFF6C5CE7,
        targetPercent: target,
        createdAt: DateTime(2026, 1, 1),
      );

  group('Subject.effectiveTarget', () {
    test('falls back to the global target when no override is set', () {
      final s = subject();
      expect(s.hasCustomTarget, isFalse);
      expect(s.effectiveTarget(75), 75);
    });

    test('uses the per-subject override when set (labs need more)', () {
      final s = subject(target: 80);
      expect(s.hasCustomTarget, isTrue);
      expect(s.effectiveTarget(75), 80);
    });

    test('a lower custom target overrides a higher global one', () {
      expect(subject(target: 60).effectiveTarget(75), 60);
    });
  });

  group('Subject target serialization', () {
    test('round-trips a custom target through toMap/fromMap', () {
      final restored =
          Subject.fromMap('s1', subject(target: 82).toMap());
      expect(restored.targetPercent, 82);
      expect(restored.effectiveTarget(75), 82);
    });

    test('absent targetPercent parses to null (follow global)', () {
      // Simulate a legacy doc with no targetPercent field.
      final restored = Subject.fromMap('s1', {
        'name': 'History',
        'colorHex': 0xFF6C5CE7,
        'attended': 8,
        'absent': 2,
      });
      expect(restored.targetPercent, isNull);
      expect(restored.effectiveTarget(75), 75);
    });

    test('copyWith clearTarget resets to following the global target', () {
      final custom = subject(target: 90);
      final cleared = custom.copyWith(clearTarget: true);
      expect(cleared.targetPercent, isNull);
      expect(cleared.effectiveTarget(75), 75);
    });
  });
}
