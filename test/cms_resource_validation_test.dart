import 'package:classtrack/features/cms/data/cms_resource_repository.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CmsResourceRepository.validateForPublish', () {
    Resource base({
      String title = 'Title',
      String org = 'Acme',
      String? appUrl = 'https://a.example',
      String? affUrl,
    }) =>
        Resource(
          id: 'r',
          type: ResourceType.internship,
          title: title,
          organization: org,
          status: ResourceStatus.active,
          applicationUrl: appUrl,
          affiliateUrl: affUrl,
        );

    test('valid resource passes', () {
      expect(CmsResourceRepository.validateForPublish(base()).ok, isTrue);
    });

    test('missing title fails', () {
      final v = CmsResourceRepository.validateForPublish(base(title: '  '));
      expect(v.ok, isFalse);
      expect(v.errors.any((e) => e.toLowerCase().contains('title')), isTrue);
    });

    test('missing organization fails', () {
      final v = CmsResourceRepository.validateForPublish(base(org: ''));
      expect(v.ok, isFalse);
      expect(v.errors.any((e) => e.toLowerCase().contains('organization')),
          isTrue);
    });

    test('missing both links fails', () {
      final v = CmsResourceRepository.validateForPublish(
          base(appUrl: null, affUrl: null));
      expect(v.ok, isFalse);
      expect(v.errors.any((e) => e.toLowerCase().contains('link')), isTrue);
    });

    test('affiliate-only link (discount) passes', () {
      final v = CmsResourceRepository.validateForPublish(
          base(appUrl: null, affUrl: 'https://deal.example'));
      expect(v.ok, isTrue);
    });
  });

  group('Resource.copyDraft', () {
    test('resets id/slug/status and appends suffix', () {
      const original = Resource(
        id: 'orig',
        type: ResourceType.scholarship,
        title: 'Grant',
        organization: 'Gov',
        status: ResourceStatus.active,
        slug: 'grant',
        sponsored: true,
        priority: 9,
      );
      final copy = original.copyDraft(titleSuffix: ' (copy)');
      expect(copy.id, isEmpty);
      expect(copy.slug, isNull);
      expect(copy.status, ResourceStatus.draft);
      expect(copy.title, 'Grant (copy)');
      // Non-identity fields are preserved.
      expect(copy.organization, 'Gov');
      expect(copy.sponsored, isTrue);
      expect(copy.priority, 9);
    });
  });
}
