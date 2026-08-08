/// Remotely-configurable weights for the recommendation engine (PRD §12).
///
/// Stored at `config/recommendation` (admins write via the CMS; the app reads).
/// Shared by the CMS Settings editor and the Phase 6 scoring so there's a single
/// source of truth. Defaults match the PRD's starting weights.
class RecommendationWeights {
  final int countryMatch;
  final int degreeMatch;
  final int departmentMatch;
  final int academicYear;
  final int interestMatch;
  final int careerGoal;
  final int deadlineRelevance;
  final int freshness;

  const RecommendationWeights({
    this.countryMatch = 30,
    this.degreeMatch = 20,
    this.departmentMatch = 15,
    this.academicYear = 10,
    this.interestMatch = 15,
    this.careerGoal = 10,
    this.deadlineRelevance = 10,
    this.freshness = 5,
  });

  static const defaults = RecommendationWeights();

  /// The maximum achievable raw score (sum of all weights), used to normalize.
  int get maxScore =>
      countryMatch +
      degreeMatch +
      departmentMatch +
      academicYear +
      interestMatch +
      careerGoal +
      deadlineRelevance +
      freshness;

  RecommendationWeights copyWith({
    int? countryMatch,
    int? degreeMatch,
    int? departmentMatch,
    int? academicYear,
    int? interestMatch,
    int? careerGoal,
    int? deadlineRelevance,
    int? freshness,
  }) {
    return RecommendationWeights(
      countryMatch: countryMatch ?? this.countryMatch,
      degreeMatch: degreeMatch ?? this.degreeMatch,
      departmentMatch: departmentMatch ?? this.departmentMatch,
      academicYear: academicYear ?? this.academicYear,
      interestMatch: interestMatch ?? this.interestMatch,
      careerGoal: careerGoal ?? this.careerGoal,
      deadlineRelevance: deadlineRelevance ?? this.deadlineRelevance,
      freshness: freshness ?? this.freshness,
    );
  }

  factory RecommendationWeights.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    int v(String k, int d) => (m[k] as num?)?.toInt() ?? d;
    return RecommendationWeights(
      countryMatch: v('countryMatch', 30),
      degreeMatch: v('degreeMatch', 20),
      departmentMatch: v('departmentMatch', 15),
      academicYear: v('academicYear', 10),
      interestMatch: v('interestMatch', 15),
      careerGoal: v('careerGoal', 10),
      deadlineRelevance: v('deadlineRelevance', 10),
      freshness: v('freshness', 5),
    );
  }

  Map<String, dynamic> toMap() => {
        'countryMatch': countryMatch,
        'degreeMatch': degreeMatch,
        'departmentMatch': departmentMatch,
        'academicYear': academicYear,
        'interestMatch': interestMatch,
        'careerGoal': careerGoal,
        'deadlineRelevance': deadlineRelevance,
        'freshness': freshness,
      };
}
