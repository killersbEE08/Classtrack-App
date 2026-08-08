import 'package:classtrack/services/push_messaging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushMessagingService.countryTopicFor', () {
    test('maps countries to country_<slug>, matching the server', () {
      expect(PushMessagingService.countryTopicFor('India'), 'country_india');
      expect(PushMessagingService.countryTopicFor('United States'),
          'country_united_states');
      expect(PushMessagingService.countryTopicFor('United Kingdom'),
          'country_united_kingdom');
    });

    test('global / empty / null → null (broadcast only)', () {
      expect(PushMessagingService.countryTopicFor('Global'), isNull);
      expect(PushMessagingService.countryTopicFor(''), isNull);
      expect(PushMessagingService.countryTopicFor('  '), isNull);
      expect(PushMessagingService.countryTopicFor(null), isNull);
    });
  });
}
