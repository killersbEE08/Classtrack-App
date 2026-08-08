import 'package:classtrack/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser progressive profiling', () {
    test('defaults: empty profile has no details and safe defaults', () {
      const u = AppUser(uid: 'u1');
      expect(u.hasAnyProfileDetails, isFalse);
      expect(u.interests, isEmpty);
      expect(u.country, isNull);
      expect(u.academicYear, isNull);
    });

    test('fromMap reads all optional profile fields', () {
      final u = AppUser.fromMap('u1', {
        'displayName': 'Prince',
        'country': 'India',
        'stateRegion': 'Maharashtra',
        'city': 'Pune',
        'university': 'ABC University',
        'college': 'XYZ College',
        'degree': 'MBA',
        'department': 'Finance',
        'academicYear': 2,
        'semester': 3,
        'graduationYear': 2027,
        'careerGoal': 'Internship',
        'interests': ['AI', 'Finance'],
      });
      expect(u.country, 'India');
      expect(u.stateRegion, 'Maharashtra');
      expect(u.city, 'Pune');
      expect(u.university, 'ABC University');
      expect(u.college, 'XYZ College');
      expect(u.degree, 'MBA');
      expect(u.department, 'Finance');
      expect(u.academicYear, 2);
      expect(u.semester, 3);
      expect(u.graduationYear, 2027);
      expect(u.careerGoal, 'Internship');
      expect(u.interests, ['AI', 'Finance']);
      expect(u.hasAnyProfileDetails, isTrue);
    });

    test('fromMap tolerates missing/blank interests', () {
      final u = AppUser.fromMap('u1', {
        'displayName': 'Prince',
        'interests': ['AI', '', 'Design'],
      });
      // Blank entries are dropped.
      expect(u.interests, ['AI', 'Design']);
    });

    test('fromMap with only base fields keeps profile empty', () {
      final u = AppUser.fromMap('u1', {
        'displayName': 'Prince',
        'email': 'p@example.com',
      });
      expect(u.hasAnyProfileDetails, isFalse);
      expect(u.interests, isEmpty);
    });

    test('hasAnyProfileDetails true when a single field is set', () {
      const u = AppUser(uid: 'u1', country: 'India');
      expect(u.hasAnyProfileDetails, isTrue);
    });

    test('copyWith preserves profile fields', () {
      const u = AppUser(
        uid: 'u1',
        country: 'India',
        degree: 'MBA',
        interests: ['AI'],
      );
      final u2 = u.copyWith(displayName: 'Prince');
      expect(u2.country, 'India');
      expect(u2.degree, 'MBA');
      expect(u2.interests, ['AI']);
      expect(u2.displayName, 'Prince');
    });
  });
}
