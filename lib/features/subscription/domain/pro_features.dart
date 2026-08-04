import 'package:flutter/material.dart';

/// A single ClassTrack Pro benefit, shown on the paywall and in Settings.
class ProFeature {
  final IconData icon;
  final String title;
  final String subtitle;
  const ProFeature(this.icon, this.title, this.subtitle);
}

/// The canonical list of everything included in ClassTrack Pro. Keep this as
/// the single source of truth so the paywall and the Settings "What's in Pro"
/// list never drift apart.
class ProFeatures {
  ProFeatures._();

  static const List<ProFeature> all = [
    ProFeature(
      Icons.auto_awesome_rounded,
      'Unlimited AI assistant',
      'Chat as much as you want — no monthly cap on questions, planning or tips.',
    ),
    ProFeature(
      Icons.sticky_note_2_rounded,
      'Smart lecture notes',
      'Rich formatting (/headings, lists, quotes), image & PDF attachments and flashcards you can study.',
    ),
    ProFeature(
      Icons.document_scanner_rounded,
      'AI timetable & photo import',
      'Snap a photo or upload a PDF and let AI build your schedule instantly.',
    ),
    ProFeature(
      Icons.insights_rounded,
      'Insights & predictions',
      'Attendance forecasts, safe-skip counts, spending projections and grade trends.',
    ),
    ProFeature(
      Icons.shield_moon_rounded,
      'Attendance risk alerts',
      'Get warned the evening before a class if skipping it would drop you below your target — with the exact classes needed to recover.',
    ),
    ProFeature(
      Icons.today_rounded,
      'Daily agenda summary',
      'A morning notification with today’s classes, deadlines and exams.',
    ),
    ProFeature(
      Icons.bedtime_rounded,
      'Quiet hours',
      'Silence reminders overnight or during class — set your own do-not-disturb window.',
    ),
    ProFeature(
      Icons.ios_share_rounded,
      'Data export',
      'Export attendance & schedule to PDF, CSV and calendar (.ics).',
    ),
    ProFeature(
      Icons.palette_rounded,
      'Custom accent colors',
      'Personalise the app with your own accent color.',
    ),
    ProFeature(
      Icons.tune_rounded,
      'Smart reminder controls',
      'Fine-tune reminders per category and choose exactly when they fire.',
    ),
    ProFeature(
      Icons.workspace_premium_rounded,
      'Everything, unlocked',
      'All current Pro features — plus everything new we add, at no extra cost.',
    ),
  ];
}
