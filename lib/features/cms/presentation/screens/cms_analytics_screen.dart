import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../opportunities/presentation/providers/opportunities_providers.dart';
import '../../domain/cms_role.dart';
import '../providers/cms_marketing_providers.dart';

/// Content-operational analytics (PRD §20): inventory metrics derived from the
/// content DB. Product-event analytics (opportunity_viewed, etc.) live in
/// Firebase Analytics. Uses the visible-resources feed so it's readable by
/// every CMS role; marketing roles also see live banner/campaign counts.
class CmsAnalyticsScreen extends ConsumerWidget {
  final CmsRole role;
  const CmsAnalyticsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(visibleResourcesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Failed to load analytics.\n$e')),
      data: (all) {
        final opportunities = all.where((r) => !r.type.isDiscount).length;
        final discounts = all.where((r) => r.type.isDiscount).length;
        final sponsored = all.where((r) => r.sponsored).length;
        final active = all.where((r) => r.isInActiveFeed).length;

        // Count by effective status and by type.
        final byStatus = <String, int>{};
        final byType = <String, int>{};
        for (final r in all) {
          byStatus.update(r.effectiveStatus.label, (v) => v + 1,
              ifAbsent: () => 1);
          byType.update(r.type.label, (v) => v + 1, ifAbsent: () => 1);
        }

        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text('Analytics', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Live content inventory. Engagement events are tracked in Firebase '
              'Analytics.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Metric('Visible resources', '${all.length}',
                    Icons.inventory_2_rounded, AppColors.primary),
                _Metric('Opportunities', '$opportunities',
                    Icons.explore_rounded, AppColors.info),
                _Metric('Discounts', '$discounts', Icons.local_offer_rounded,
                    AppColors.success),
                _Metric('Active in feed', '$active', Icons.bolt_rounded,
                    AppColors.accent),
                _Metric('Sponsored', '$sponsored', Icons.star_rounded,
                    AppColors.coral),
                if (role.canManageMarketing) const _MarketingMetrics(),
              ],
            ),
            const SizedBox(height: 24),
            _Breakdown(title: 'By status', data: byStatus),
            const SizedBox(height: 16),
            _Breakdown(title: 'By type', data: byType),
          ],
        );
      },
    );
  }
}

/// Live banner/campaign counts — only rendered for marketing roles (they can
/// read unpublished marketing docs).
class _MarketingMetrics extends ConsumerWidget {
  const _MarketingMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(cmsBannersProvider).valueOrNull ?? const [];
    final campaigns = ref.watch(cmsCampaignsProvider).valueOrNull ?? const [];
    final liveBanners = banners.where((b) => b.isLive()).length;
    final liveCampaigns = campaigns.where((c) => c.isLive()).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Metric('Live banners', '$liveBanners', Icons.view_carousel_rounded,
            AppColors.primary),
        const SizedBox(width: 16),
        _Metric('Live campaigns', '$liveCampaigns', Icons.campaign_rounded,
            AppColors.info),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  const _Breakdown({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text('No data yet',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 160, child: Text(e.key)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: e.value / max,
                          minHeight: 8,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.10),
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${e.value}',
                        style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
