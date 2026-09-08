import 'package:flutter_test/flutter_test.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

Resource _spotify({List<RegionalOffer> variants = const []}) => Resource(
      id: 'spotify',
      type: ResourceType.discount,
      title: 'Spotify Premium Student',
      organization: 'Spotify',
      company: 'Spotify',
      discountText: '50% off Premium',
      applicationUrl: 'https://www.spotify.com/student/',
      regionalVariants: variants,
    );

void main() {
  group('Resource.effectiveOffer', () {
    test('falls back to resource defaults when there are no variants', () {
      final r = _spotify();
      final o = r.effectiveOffer('India');
      expect(o.discountText, '50% off Premium');
      expect(o.url, 'https://www.spotify.com/student/');
    });

    test('returns the matching country variant price + link', () {
      final r = _spotify(variants: const [
        RegionalOffer(
            countries: ['United States'],
            discountText: r'$5.99/mo',
            url: 'https://www.spotify.com/us/student/'),
        RegionalOffer(
            countries: ['India'],
            discountText: '₹59/mo',
            url: 'https://www.spotify.com/in-en/student/'),
      ]);

      final us = r.effectiveOffer('United States');
      expect(us.discountText, r'$5.99/mo');
      expect(us.url, 'https://www.spotify.com/us/student/');

      final india = r.effectiveOffer('India');
      expect(india.discountText, '₹59/mo');
      expect(india.url, 'https://www.spotify.com/in-en/student/');
    });

    test('matches country case-insensitively', () {
      final r = _spotify(variants: const [
        RegionalOffer(
            countries: ['India'], discountText: '₹59/mo', url: 'https://in'),
      ]);
      expect(r.effectiveOffer('india').discountText, '₹59/mo');
      expect(r.effectiveOffer('INDIA').url, 'https://in');
    });

    test('unmatched country falls back to the resource defaults', () {
      final r = _spotify(variants: const [
        RegionalOffer(
            countries: ['United States'], discountText: r'$5.99/mo'),
      ]);
      final o = r.effectiveOffer('Germany');
      expect(o.discountText, '50% off Premium');
      expect(o.url, 'https://www.spotify.com/student/');
    });

    test('a variant may override only the price, keeping the default link', () {
      final r = _spotify(variants: const [
        RegionalOffer(countries: ['India'], discountText: '₹59/mo'),
      ]);
      final o = r.effectiveOffer('India');
      expect(o.discountText, '₹59/mo');
      expect(o.url, 'https://www.spotify.com/student/'); // fell back
    });

    test('null user country uses the defaults', () {
      final r = _spotify(variants: const [
        RegionalOffer(countries: ['India'], discountText: '₹59/mo'),
      ]);
      expect(r.effectiveOffer(null).discountText, '50% off Premium');
    });
  });

  group('RegionalOffer + Resource serialization', () {
    test('RegionalOffer survives toMap → fromMap', () {
      const v = RegionalOffer(
          countries: ['United States'],
          discountText: r'$5.99/mo',
          url: 'https://us',
          discountCode: 'STUDENT');
      final restored = RegionalOffer.fromMap(v.toMap());
      expect(restored.countries, ['United States']);
      expect(restored.discountText, r'$5.99/mo');
      expect(restored.url, 'https://us');
      expect(restored.discountCode, 'STUDENT');
    });

    test('Resource.fromMap parses regionalVariants and resolves them', () {
      final restored = Resource.fromMap('spotify', {
        'type': 'discount',
        'title': 'Spotify Premium Student',
        'organization': 'Spotify',
        'discountText': '50% off Premium',
        'applicationUrl': 'https://www.spotify.com/student/',
        'regionalVariants': [
          {
            'countries': ['United States'],
            'discountText': r'$5.99/mo',
            'url': 'https://us',
            'discountCode': 'STUDENT',
          },
          {
            'countries': ['India'],
            'discountText': '₹59/mo',
            'url': 'https://in',
          },
        ],
      });
      expect(restored.regionalVariants.length, 2);
      final us = restored.effectiveOffer('United States');
      expect(us.discountText, r'$5.99/mo');
      expect(us.url, 'https://us');
      expect(us.discountCode, 'STUDENT');
      expect(restored.effectiveOffer('India').discountText, '₹59/mo');
    });

    test('missing regionalVariants parses to an empty list', () {
      final restored = Resource.fromMap('x', {
        'type': 'discount',
        'title': 'Test',
        'organization': 'Test',
      });
      expect(restored.regionalVariants, isEmpty);
    });
  });
}
