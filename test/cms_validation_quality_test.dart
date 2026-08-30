import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/cms_validation.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

void main() {
  Resource base({
    String title = 'Google Summer of Code 2026 internship program',
    String org = 'Google',
    String desc =
        'A global program that offers stipends to students contributing to open source over the summer.',
    String? appUrl = 'https://summerofcode.withgoogle.com',
    List<String> countries = const ['Global'],
    String? eligibility = 'Enrolled students 18+',
    String? logoUrl = 'https://example.com/logo.png',
    String? benefits = 'Paid stipend, mentorship, and a completion certificate.',
    String? howToApply = 'Apply on the official site during the application window.',
    DateTime? start,
    DateTime? deadline,
    ResourceType type = ResourceType.internship,
  }) =>
      Resource(
        id: '1',
        type: type,
        title: title,
        organization: org,
        description: desc,
        applicationUrl: appUrl,
        countries: countries,
        eligibility: eligibility,
        logoUrl: logoUrl,
        benefits: benefits,
        howToApply: howToApply,
        startDate: start,
        deadline: deadline,
      );

  group('evaluateResource — errors block publish', () {
    test('a complete resource has no errors and a high score', () {
      final rep = evaluateResource(base());
      expect(rep.errors, isEmpty);
      expect(rep.canPublish, isTrue);
      expect(rep.score, greaterThanOrEqualTo(90));
    });

    test('missing title/org/description/link each produce an error', () {
      final rep = evaluateResource(base(
        title: '  ',
        org: '',
        desc: '',
        appUrl: null,
      ));
      final fields = rep.errors.map((e) => e.field).toSet();
      expect(fields, containsAll(<String>{
        'title',
        'organization',
        'description',
        'applicationUrl',
      }));
      expect(rep.canPublish, isFalse);
    });

    test('opportunities require benefits and how-to-apply', () {
      final rep = evaluateResource(base(benefits: null, howToApply: null));
      final fields = rep.errors.map((e) => e.field).toSet();
      expect(fields, containsAll(<String>{'benefits', 'howToApply'}));
      expect(rep.canPublish, isFalse);
    });

    test('discounts do NOT require benefits / how-to-apply', () {
      final rep = evaluateResource(base(
        type: ResourceType.discount,
        benefits: null,
        howToApply: null,
      ));
      final fields = rep.errors.map((e) => e.field).toSet();
      expect(fields, isNot(contains('benefits')));
      expect(fields, isNot(contains('howToApply')));
      expect(rep.canPublish, isTrue);
    });

    test('deadline before start date is an error', () {
      final rep = evaluateResource(base(
        start: DateTime(2026, 6, 1),
        deadline: DateTime(2026, 5, 1),
      ));
      expect(rep.errors.any((e) => e.field == 'deadline'), isTrue);
    });

    test('scheduled unpublish before publish is an error', () {
      final r = Resource(
        id: '1',
        type: ResourceType.internship,
        title: 'A valid internship title here',
        organization: 'Org',
        description:
            'A sufficiently long description of the opportunity for students.',
        applicationUrl: 'https://example.com',
        scheduledPublishAt: DateTime(2026, 6, 10),
        scheduledUnpublishAt: DateTime(2026, 6, 5),
      );
      final rep = evaluateResource(r);
      expect(rep.errors.any((e) => e.field == 'scheduledUnpublishAt'), isTrue);
    });
  });

  group('evaluateResource — warnings are advisory', () {
    test('short description, no eligibility, no logo produce warnings not errors',
        () {
      final rep = evaluateResource(base(
        desc: 'Too short',
        eligibility: null,
        logoUrl: null,
      ));
      expect(rep.canPublish, isTrue); // warnings don't block
      final fields = rep.warnings.map((w) => w.field).toSet();
      expect(fields, contains('description'));
      expect(fields, contains('eligibility'));
      expect(fields, contains('logoUrl'));
    });

    test('invalid URL is a warning', () {
      final rep = evaluateResource(base(appUrl: 'not a url'));
      // still has a link value, so no missing-link error, but a URL warning:
      expect(rep.warnings.any((w) => w.field == 'applicationUrl'), isTrue);
    });

    test('empty countries warns about global visibility', () {
      final rep = evaluateResource(base(countries: const []));
      expect(rep.warnings.any((w) => w.field == 'countries'), isTrue);
    });
  });

  group('canPublishAt', () {
    test('drafts are always allowed even when incomplete', () {
      final incomplete = base(title: '', org: '', desc: '', appUrl: null);
      expect(canPublishAt(incomplete, ResourceStatus.draft), isTrue);
      expect(canPublishAt(incomplete, ResourceStatus.hidden), isTrue);
    });

    test('student-visible statuses require a clean report', () {
      final incomplete = base(appUrl: null, org: '');
      expect(canPublishAt(incomplete, ResourceStatus.active), isFalse);
      expect(canPublishAt(base(), ResourceStatus.active), isTrue);
    });
  });
}
