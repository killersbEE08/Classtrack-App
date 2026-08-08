import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/discoverable_feature.dart';
import '../providers/tips_providers.dart';

/// "✨ Tips & Tricks" — a friendly progress checklist that turns feature
/// discovery into a game. Shows how much of ClassTrack the student is using and
/// which features they haven't tried yet. Opened manually from Settings, or
/// auto-shown once after 7 days of use.
class TipsScreen extends ConsumerWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final features = ref.watch(discoveredFeaturesProvider);
    final progress = ref.watch(featureProgressProvider);
    final pct = progress.percent.round();
    final remaining = features.where((f) => !f.done).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Tips & Tricks'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          _ProgressHeader(pct: pct, progress: progress)
              .animate()
              .fadeIn(duration: 320.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              remaining.isEmpty
                  ? 'You’ve tried everything 🎉'
                  : 'Features to explore',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          if (remaining.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Tick these off to get the most out of ClassTrack.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
          const SizedBox(height: 10),
          for (var i = 0; i < features.length; i++)
            _FeatureRow(feature: features[i])
                .animate()
                .fadeIn(duration: 300.ms, delay: (40 * i).ms)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int pct;
  final FeatureProgress progress;
  const _ProgressHeader({required this.pct, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = progress.done >= progress.total && progress.total > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete
                      ? 'You’re using all of ClassTrack 🎉'
                      : 'You’re only using $pct% of ClassTrack',
                  style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  complete
                      ? 'Every feature tried — nice work!'
                      : 'You’ve tried ${progress.done} of ${progress.total} features. '
                          'A few taps unlock the rest.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ProgressRing(
            percent: progress.percent,
            size: 96,
            strokeWidth: 10,
            color: Colors.white,
            centerLabel: '$pct%',
            subLabel: 'used',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final DiscoverableFeature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = feature.done;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: softCard(context, radius: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? theme.hintColor : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(feature.subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ✅ tried / ⬜ not tried
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? AppColors.success : theme.dividerColor,
            size: 26,
          ),
        ],
      ),
    );
  }
}
