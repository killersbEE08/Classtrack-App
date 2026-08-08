import 'package:classtrack/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.password (sign-up policy: 8+ chars, alphanumeric)', () {
    test('rejects null / empty', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
    });

    test('rejects shorter than 8 characters', () {
      expect(Validators.password('Ab1'), isNotNull);
      expect(Validators.password('Abc123'), isNotNull); // 6 chars
      expect(Validators.password('Abcde12'), isNotNull); // 7 chars
    });

    test('rejects 8+ chars with no digit', () {
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('Password'), isNotNull);
    });

    test('rejects 8+ chars with no letter', () {
      expect(Validators.password('12345678'), isNotNull);
    });

    test('accepts 8+ chars containing both letters and numbers', () {
      expect(Validators.password('abcd1234'), isNull);
      expect(Validators.password('Passw0rd'), isNull);
      expect(Validators.password('a1b2c3d4e5'), isNull);
      expect(Validators.password('P@ssw0rd!'), isNull); // symbols allowed too
    });

    test('exposes an 8-character minimum', () {
      expect(Validators.minPasswordLength, 8);
    });
  });

  group('Validators.email', () {
    test('rejects empty and malformed', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('missing@domain'), isNotNull);
      expect(Validators.email('a b@c.com'), isNotNull);
    });

    test('accepts a normal address (trimmed)', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('  user@example.com  '), isNull);
    });
  });

  group('Validators.name', () {
    test('requires non-blank', () {
      expect(Validators.name(null), isNotNull);
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('Prince'), isNull);
    });

    test('rejects names containing HTML / angle brackets', () {
      expect(Validators.name('<b style="color:red;">Alert</b>'), isNotNull);
      expect(Validators.name('<script>x</script>'), isNotNull);
      expect(Validators.name('a<b'), isNotNull);
    });
  });

  group('Validators.sanitizeName', () {
    test('strips HTML tags and angle brackets', () {
      expect(Validators.sanitizeName('<b style="color:red;">Alert</b>'),
          'Alert');
      expect(Validators.sanitizeName('<script>evil()</script>'), 'evil()');
      expect(Validators.sanitizeName('John <Doe>'), 'John'); // <Doe> stripped as a tag
      expect(Validators.sanitizeName('Jane > Doe'), 'Jane Doe'); // stray > removed
    });

    test('collapses whitespace and trims', () {
      expect(Validators.sanitizeName('  John   Doe  '), 'John Doe');
    });

    test('removes control characters', () {
      expect(Validators.sanitizeName('Jo\u0000hn'), 'John');
    });

    test('caps length at 60 characters', () {
      final long = 'a' * 100;
      expect(Validators.sanitizeName(long).length, 60);
    });

    test('null / empty is safe', () {
      expect(Validators.sanitizeName(null), '');
      expect(Validators.sanitizeName('   '), '');
    });
  });

  group('Validators.sanitizeText (content fields)', () {
    test('strips complete HTML tags but keeps inner text', () {
      expect(Validators.sanitizeText('<b>Assignment</b>'), 'Assignment');
      expect(Validators.sanitizeText('<img src=x onerror=alert(1)>Chem'),
          'Chem');
    });

    test('preserves a lone comparison symbol (math is not markup)', () {
      expect(Validators.sanitizeText('Prove x < 0'), 'Prove x < 0');
      expect(Validators.sanitizeText('a > b test'), 'a > b test');
    });

    test('single-line collapses whitespace', () {
      expect(Validators.sanitizeText('  Lab   report  '), 'Lab report');
    });

    test('multiline preserves newlines and does not truncate', () {
      const body = 'Line one\n\nLine two with x < 5\nLine three';
      expect(Validators.sanitizeText(body, multiline: true), body);
      final long = 'word ' * 1000; // ~5000 chars, no maxLength passed
      expect(Validators.sanitizeText(long, multiline: true).length,
          greaterThan(3000));
    });

    test('caps length only when maxLength is given', () {
      expect(Validators.sanitizeText('a' * 300, maxLength: 200).length, 200);
    });
  });
}
