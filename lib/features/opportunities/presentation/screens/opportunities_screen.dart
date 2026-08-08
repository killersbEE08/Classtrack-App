import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// The Opportunities destination (bottom nav, replacing the old Tasks tab).
///
/// Phase 1 ships this as a polished placeholder so the new navigation is fully
/// wired and shippable. Phase 3 replaces the body with the live feed backed by
/// the unified Resource model (search, filters, detail, save/share, status &
/// related opportunities).
class OpportunitiesScreen extends ConsumerWidget {
  const OpportunitiesScreen({super.key});

  static const _categories = <(String, IconData, Color)>[
    ('Scholarships', Icons.school_rounded, AppColors.primary),
    ('Internships', Icons.work_outline_rounded, AppColors.info),
    ('Student discounts', Icons.local_offer_rounded, AppColors.success),
    ('Hackathons', Icons.code_rounded, AppColors.coral),
    ('Competitions', Icons.emoji_events_rounded, AppColors.accent),
    ('Ambassador programs', Icons.campaign_rounded, AppColors.primaryLight),
    ('Certifications', Icons.verified_rounded, AppColors.info),
    ('Free courses', Icons.menu_book_rounded, AppColors.success),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Text('Opportunities', style: theme.textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(
              'Scholarships, internships, competitions and student deals — '
              'matched to you.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 22),
            Text('Explore categories', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                for (final (label, icon, color) in _categories)
                  _CategoryTile(label: label, icon: icon, color: color),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: softCard(context),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.rocket_launch_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                  Text('New opportunities are on the way',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'We’re curating scholarships, internships and exclusive '
                    'student deals. Add your details in Settings → Edit profile '
                    'so we can match the best ones to you.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: softCard(context),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
