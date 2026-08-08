import 'package:classtrack/features/auth/domain/app_user.dart';
import 'package:classtrack/features/opportunities/domain/recommendation.dart';
import 'package:classtrack/features/opportunities/domain/recommendation_weights.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 15);
  final rec = Recommender(RecommendationWeights.defaults, now: now);

  Resource res({
    List<String> countries = const [],
    List<String> degrees = const [],
    List<String> departments = const [],
    List<int> years = const [],
    List<String> interests = const [],
    List<String> careerGoals = const [],
    DateTime? deadline,
    DateTime? publishedAt,
    bool featured = false,
    int priority = 0,
  }) =>
      Resource(
        id: 'r${countries.hashCode}$priority',
        type: ResourceType.internship,
        title: 'Role',
        organization: 'Org',
        status: ResourceStatus.active,
        countries: countries,
        targetDegrees: degrees,
        targetDepartments: departments,
        targetAcademicYears: years,
        targetInterests: interests,
        targetCareerGoals: careerGoals,
        deadline: deadline,
        publishedAt: publishedAt,
        featured: featured,
        priority: priority,
      );

  const student = AppUser(
    uid: 'u',
    country: 'India',
    degree: 'MBA',
    department: 'Finance',
    academicYear: 2,
    interests: ['AI', 'Finance'],
    careerGoal: 'Internship',
  );

  test('full profile match scores highly & is personalized', () {
    final r = res(
      countries: ['India'],
      degrees: ['MBA'],
      departments: ['Finance'],
      years: [2],
      interests: ['AI'],
      careerGoals: ['Internship'],
      deadline: now.add(const Duration(days: 2)),
      publishedAt: now.subtract(const Duration(days: 1)),
    );
    final s = rec.score(r, student);
    expect(s.personalized, isTrue);
    expect(s.score, greaterThanOrEqualTo(80));
    expect(s.tier, MatchTier.highlyRecommended);
  });

  test('targeted but non-matching profile scores low', () {
    final r = res(
      countries: ['United States'],
      degrees: ['Law'],
      departments: ['Arts'],
      years: [4],
      interests: ['Design'],
      careerGoals: ['Research'],
      deadline: now.subtract(const Duration(days: 5)), // closed → 0 deadline
      publishedAt: now.subtract(const Duration(days: 90)), // stale → 0 fresh
    );
    final s = rec.score(r, student);
    expect(s.personalized, isTrue);
    expect(s.score, lessThan(35));
    expect(s.tier, MatchTier.explore);
  });

  test('untargeted global resource is not personalized', () {
    final r = res(
      countries: ['Global'],
      deadline: now.add(const Duration(days: 2)),
      publishedAt: now.subtract(const Duration(days: 1)),
    );
    final s = rec.score(r, student);
    expect(s.personalized, isFalse,
        reason: 'no profile signal applies to a global, untargeted resource');
  });

  test('no user profile → not personalized', () {
    final r = res(
      countries: ['India'],
      degrees: ['MBA'],
      deadline: now.add(const Duration(days: 2)),
    );
    final s = rec.score(r, null);
    expect(s.personalized, isFalse);
  });

  test('rank orders stronger matches first', () {
    final strong = res(
      countries: ['India'],
      degrees: ['MBA'],
      interests: ['AI'],
      careerGoals: ['Internship'],
      deadline: now.add(const Duration(days: 2)),
      publishedAt: now.subtract(const Duration(days: 1)),
      priority: 0,
    );
    final weak = res(
      countries: ['United States'],
      degrees: ['Law'],
      deadline: now.subtract(const Duration(days: 10)),
      publishedAt: now.subtract(const Duration(days: 120)),
      priority: 99,
    );
    final ranked = rec.rank([weak, strong], student);
    expect(ranked.first, same(strong));
  });

  test('featured breaks ties when scores are equal', () {
    // Two identical untargeted resources → equal score; featured wins.
    final plain = res(priority: 5);
    final feat = res(featured: true, priority: 0);
    final ranked = rec.rank([plain, feat], student);
    expect(ranked.first, same(feat));
  });
}
