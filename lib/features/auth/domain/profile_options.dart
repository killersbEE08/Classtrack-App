/// Curated option lists for the optional student profile (Settings → Edit
/// profile). Centralised so the edit form, personalisation scoring (Phase 6)
/// and any future CMS targeting all draw from the same vocabulary.
///
/// None of these are enforced — the profile is progressive and free-form where
/// it makes sense — but offering a consistent set keeps matching reliable.
class ProfileOptions {
  ProfileOptions._();

  /// Countries offered in the picker. "Global" is intentionally omitted here
  /// (it's a targeting value for promotions, not a place a student lives).
  /// Ordered with the most common ClassTracks markets first.
  static const List<String> countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Singapore',
    'United Arab Emirates',
    'Nigeria',
    'Pakistan',
    'Bangladesh',
    'Nepal',
    'Sri Lanka',
    'South Africa',
    'Other',
  ];

  /// Primary career goals a student can pick (single selection).
  static const List<String> careerGoals = [
    'Internship',
    'Job',
    'Higher studies',
    'Research',
    'Freelancing',
    'Startup',
    'Government exams',
  ];

  /// Interests used for opportunity matching (multiple selection allowed).
  static const List<String> interests = [
    'AI',
    'Programming',
    'Data Science',
    'Finance',
    'Marketing',
    'Design',
    'Cybersecurity',
    'Cloud',
    'Entrepreneurship',
    'Research',
    'Product',
    'Consulting',
  ];
}
