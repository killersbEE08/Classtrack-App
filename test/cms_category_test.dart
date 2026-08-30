import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/cms_category.dart';

void main() {
  group('CmsCategory', () {
    test('fromMap derives slug from name when missing, defaults enabled', () {
      final c = CmsCategory.fromMap('c1', {
        'name': 'Data Science',
        'kind': 'opportunity',
      });
      expect(c.slug, 'data-science');
      expect(c.enabled, isTrue);
      expect(c.kind, CategoryKind.opportunity);
    });

    test('kind fromKey falls back to opportunity', () {
      expect(CategoryKind.fromKey('discount'), CategoryKind.discount);
      expect(CategoryKind.fromKey('bogus'), CategoryKind.opportunity);
    });

    test('copyWith re-slugs on rename', () {
      const c = CmsCategory(
          id: 'x', name: 'Old', slug: 'old', kind: CategoryKind.discount);
      final r = c.copyWith(name: 'New Name');
      expect(r.slug, 'new-name');
      expect(r.kind, CategoryKind.discount);
    });

    test('toMap round-trips core fields', () {
      const c = CmsCategory(
          id: 'x',
          name: 'Food',
          slug: 'food',
          kind: CategoryKind.discount,
          enabled: false,
          sort: 3);
      final m = c.toMap();
      expect(m['kind'], 'discount');
      expect(m['enabled'], false);
      expect(m['sort'], 3);
    });
  });

  group('sortedCategories', () {
    test('orders by sort then name', () {
      final list = [
        const CmsCategory(id: '1', name: 'Beta', slug: 'beta', kind: CategoryKind.opportunity, sort: 2),
        const CmsCategory(id: '2', name: 'Alpha', slug: 'alpha', kind: CategoryKind.opportunity, sort: 1),
        const CmsCategory(id: '3', name: 'Gamma', slug: 'gamma', kind: CategoryKind.opportunity, sort: 1),
      ];
      final sorted = sortedCategories(list);
      expect(sorted.map((c) => c.id).toList(), ['2', '3', '1']); // sort1: Alpha,Gamma; then Beta
    });
  });
}
