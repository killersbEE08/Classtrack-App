import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_settings_provider.dart';
import '../../core/theme/app_colors.dart';

/// A lightweight, one-time "💡 Tip" banner used for feature discovery.
///
/// Renders a soft, dismissible card the first time a screen is opened, then
/// never again — its "seen" state is persisted per [prefsKey] via
/// [featureTipProvider]. Once dismissed (or already seen) it collapses to an
/// empty box, so it's safe to place unconditionally at the top of a screen.
///
/// Example:
/// ```dart
/// FeatureTipBanner(
///   prefsKey: AppConstants.prefsTipNotes,
///   message: 'You can create flashcards from your notes.',
/// )
/// ```
class FeatureTipBanner extends ConsumerWidget {
  /// SharedPreferences key that records whether this tip was seen
  /// (e.g. `AppConstants.prefsTipNotes`).
  final String prefsKey;

  /// The tip body shown after the "💡 Tip" label.
  final String message;

  /// Leading icon; defaults to a lightbulb.
  final IconData icon;

  /// Accent colour for the icon + border tint.
  final Color color;

  /// Outer padding around the banner.
  final EdgeInsetsGeometry padding;

  const FeatureTipBanner({
    super.key,
    required this.prefsKey,
    required this.message,
    this.icon = Icons.lightbulb_rounded,
    this.color = AppColors.accent,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(featureTipProvider(prefsKey));
    if (seen) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tip',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: color, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(message,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Got it',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: theme.hintColor),
              onPressed: () =>
                  ref.read(featureTipProvider(prefsKey).notifier).dismiss(),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.15, end: 0, curve: Curves.easeOut),
    );
  }
}
