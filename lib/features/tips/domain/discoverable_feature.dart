import 'package:flutter/material.dart';

/// Stable ids for the features surfaced on the "✨ Tips & Tricks" page.
///
/// Some features are detected automatically from the user's own data (e.g. a
/// note with flashcards, a logged focus session). The three AI features leave
/// no persistent trace, so they're recorded as one-off "used" flags instead —
/// their ids are the [flagTracked] set below.
class FeatureId {
  FeatureId._();

  static const attendance = 'attendance';
  static const googleCalendar = 'google_calendar';
  static const dailySummary = 'daily_summary';
  static const aiAssistant = 'ai_assistant';
  static const shareVideo = 'share_video';
  static const flashcards = 'flashcards';
  static const focusTimer = 'focus_timer';
  static const photoImport = 'photo_import';
  static const grades = 'grades';
  static const expenses = 'expenses';

  /// Features whose usage can't be inferred from stored data, so they're
  /// tracked via one-off flags written when the user first uses them.
  static const flagTracked = {aiAssistant, dailySummary, photoImport};
}

/// One entry in the Tips & Tricks progress checklist: a ClassTrack feature the
/// user has either tried ([done] == true) or not yet discovered.
class DiscoverableFeature {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Whether the user has already used this feature.
  final bool done;

  const DiscoverableFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.done,
  });

  DiscoverableFeature copyWith({bool? done}) => DiscoverableFeature(
        id: id,
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        done: done ?? this.done,
      );
}
