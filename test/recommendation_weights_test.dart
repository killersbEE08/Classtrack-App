import 'package:classtrack/features/opportunities/domain/recommendation_weights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match PRD starting weights and sum correctly', () {
    const w = RecommendationWeights.defaults;
    expect(w.countryMatch, 30);
    expect(w.interestMatch, 15);
    expect(w.freshness, 5);
    // 30+20+15+10+15+10+10+5 = 115
    expect(w.maxScore, 115);
  });

  test('fromMap(null) returns defaults', () {
    expect(RecommendationWeights.fromMap(null).maxScore, 115);
  });

  test('fromMap reads overrides and toMap round-trips', () {
    final w = RecommendationWeights.fromMap({
      'countryMatch': 40,
      'freshness': 0,
    });
    expect(w.countryMatch, 40);
    expect(w.freshness, 0);
    // Unspecified fields fall back to defaults.
    expect(w.degreeMatch, 20);

    final map = w.toMap();
    expect(map['countryMatch'], 40);
    expect(map['freshness'], 0);
    final w2 = RecommendationWeights.fromMap(map);
    expect(w2.maxScore, w.maxScore);
  });
}
