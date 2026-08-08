import 'package:classtrack/features/opportunities/data/resource_repository.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveResourceStatus (automatic lifecycle)', () {
    final now = DateTime(2026, 6, 15, 12);

    test('before start date → opening soon', () {
      final s = resolveResourceStatus(
        stored: ResourceStatus.active,
        startDate: now.add(const Duration(days: 3)),
        deadline: now.add(const Duration(days: 30)),
        now: now,
      );
      expect(s, ResourceStatus.openingSoon);
    });

    test('between start and deadline → active', () {
      final s = resolveResourceStatus(
        stored: ResourceStatus.openingSoon,
        startDate: now.subtract(const Duration(days: 1)),
        deadline: now.add(const Duration(days: 10)),
        now: now,
      );
      expect(s, ResourceStatus.active);
    });

    test('after deadline → applications closed', () {
      final s = resolveResourceStatus(
        stored: ResourceStatus.active,
        startDate: now.subtract(const Duration(days: 30)),
        deadline: now.subtract(const Duration(days: 1)),
        now: now,
      );
      expect(s, ResourceStatus.applicationsClosed);
    });

    test('no dates → stored status is trusted', () {
      final s = resolveResourceStatus(stored: ResourceStatus.active, now: now);
      expect(s, ResourceStatus.active);
    });

    test('manual states are never overridden by dates', () {
      for (final manual in [
        ResourceStatus.draft,
        ResourceStatus.hidden,
        ResourceStatus.discontinued,
        ResourceStatus.archived,
      ]) {
        final s = resolveResourceStatus(
          stored: manual,
          startDate: now.subtract(const Duration(days: 5)),
          deadline: now.add(const Duration(days: 5)),
          now: now,
        );
        expect(s, manual, reason: '$manual must be preserved');
      }
    });
  });

  group('ResourceStatus / ResourceType keys', () {
    test('status visibility flags', () {
      expect(ResourceStatus.draft.isVisibleToStudents, isFalse);
      expect(ResourceStatus.hidden.isVisibleToStudents, isFalse);
      expect(ResourceStatus.active.isVisibleToStudents, isTrue);
      expect(ResourceStatus.expired.isVisibleToStudents, isTrue);
      expect(ResourceStatus.active.isInActiveFeed, isTrue);
      expect(ResourceStatus.openingSoon.isInActiveFeed, isTrue);
      expect(ResourceStatus.applicationsClosed.isInActiveFeed, isFalse);
      expect(ResourceStatus.active.isOpen, isTrue);
      expect(ResourceStatus.applicationsClosed.isOpen, isFalse);
    });

    test('unknown status key defaults to draft (never leaks)', () {
      expect(ResourceStatus.fromKey('bogus'), ResourceStatus.draft);
      expect(ResourceStatus.fromKey(null), ResourceStatus.draft);
    });

    test('type keys round-trip and unknown defaults to scholarship', () {
      for (final t in ResourceType.values) {
        expect(ResourceType.fromKey(t.key), t);
      }
      expect(ResourceType.fromKey('nope'), ResourceType.scholarship);
      expect(ResourceType.discount.isDiscount, isTrue);
      expect(ResourceType.internship.isDiscount, isFalse);
    });
  });

  group('Resource.fromMap', () {
    test('parses core + targeting fields and computes effective status', () {
      final future = DateTime.now().add(const Duration(days: 20));
      final start = DateTime.now().subtract(const Duration(days: 1));
      final r = Resource.fromMap('r1', {
        'type': 'internship',
        'title': 'Summer Internship',
        'organization': 'Acme',
        'description': 'Great role',
        'countries': ['India', 'Global'],
        'startDate': Timestamp.fromDate(start),
        'deadline': Timestamp.fromDate(future),
        'status': 'opening_soon',
        'priority': 42,
        'sponsored': true,
        'tags': ['ai', 'finance'],
        'targetInterests': ['AI'],
        'targetAcademicYears': [2, 3],
      });
      expect(r.type, ResourceType.internship);
      expect(r.title, 'Summer Internship');
      expect(r.priority, 42);
      expect(r.sponsored, isTrue);
      expect(r.targetInterests, ['AI']);
      expect(r.targetAcademicYears, [2, 3]);
      // start passed, deadline ahead → effective status is active.
      expect(r.effectiveStatus, ResourceStatus.active);
      expect(r.isInActiveFeed, isTrue);
      expect(r.daysUntilDeadline, greaterThanOrEqualTo(19));
    });

    test('targetsCountry honours Global and explicit targeting', () {
      const global = Resource(
        id: 'g',
        type: ResourceType.scholarship,
        title: 't',
        organization: 'o',
        countries: ['Global'],
      );
      expect(global.targetsCountry('India'), isTrue);
      expect(global.targetsCountry(null), isTrue);

      const india = Resource(
        id: 'i',
        type: ResourceType.scholarship,
        title: 't',
        organization: 'o',
        countries: ['India'],
      );
      expect(india.targetsCountry('India'), isTrue);
      expect(india.targetsCountry('USA'), isFalse);
      expect(india.targetsCountry(null), isFalse);

      const untargeted = Resource(
        id: 'u',
        type: ResourceType.scholarship,
        title: 't',
        organization: 'o',
      );
      expect(untargeted.targetsCountry('anywhere'), isTrue);
    });

    test('discount brand + image fallbacks', () {
      const d = Resource(
        id: 'd',
        type: ResourceType.discount,
        title: 'Student deal',
        organization: 'Org',
        company: 'Adobe',
        logoUrl: 'logo.png',
      );
      expect(d.brandName, 'Adobe');
      expect(d.displayImage, 'logo.png');
    });
  });

  group('ResourceQueries', () {
    final all = [
      const Resource(
          id: '1',
          type: ResourceType.internship,
          title: 'AI Internship',
          organization: 'OpenLab',
          status: ResourceStatus.active,
          tags: ['ai']),
      const Resource(
          id: '2',
          type: ResourceType.discount,
          title: 'Laptop discount',
          organization: 'Dell',
          company: 'Dell',
          status: ResourceStatus.active),
      const Resource(
          id: '3',
          type: ResourceType.scholarship,
          title: 'Merit Scholarship',
          organization: 'Gov',
          status: ResourceStatus.applicationsClosed),
    ];

    test('opportunities excludes discounts; discounts only discounts', () {
      expect(ResourceQueries.opportunities(all).map((e) => e.id), ['1', '3']);
      expect(ResourceQueries.discounts(all).map((e) => e.id), ['2']);
    });

    test('search matches title/tags/company case-insensitively', () {
      expect(ResourceQueries.search(all, 'ai').map((e) => e.id), ['1']);
      expect(ResourceQueries.search(all, 'dell').map((e) => e.id), ['2']);
      expect(ResourceQueries.search(all, '').length, 3);
    });

    test('feed keeps only active-feed items and filters by type', () {
      // id 3 is applicationsClosed → excluded from the active feed.
      final feed = ResourceQueries.feed(all);
      expect(feed.map((e) => e.id), ['1', '2']);
      final onlyInternships =
          ResourceQueries.feed(all, type: ResourceType.internship);
      expect(onlyInternships.map((e) => e.id), ['1']);
    });
  });
}
