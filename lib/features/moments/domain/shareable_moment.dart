import 'package:flutter/material.dart';

/// A single celebratory milestone the student can share as a beautiful card.
/// Built from the user's real stats (see moment_providers.dart) so every card
/// is authentic and personal.
class ShareableMoment {
  /// Stable id, used as the RepaintBoundary key seed.
  final String id;

  /// Big emoji shown on the card.
  final String emoji;

  /// Short, punchy title (e.g. "On fire!").
  final String headline;

  /// The hero number/stat (e.g. "92%", "12", "3.8").
  final String value;

  /// What the value means (e.g. "attendance", "day streak").
  final String valueLabel;

  /// A supporting one-liner shown under the headline.
  final String caption;

  /// The social caption suggested when the card is shared.
  final String shareText;

  /// Two-stop background gradient for the card.
  final List<Color> gradient;

  const ShareableMoment({
    required this.id,
    required this.emoji,
    required this.headline,
    required this.value,
    required this.valueLabel,
    required this.caption,
    required this.shareText,
    required this.gradient,
  });
}
