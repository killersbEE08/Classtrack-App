import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/resource.dart';
import '../../domain/resource_status.dart';
import '../providers/opportunities_providers.dart';

/// A thumbnail that shows the resource's image/logo, falling back to a tinted
/// type icon when there's no image or it fails to load.
class ResourceThumb extends StatelessWidget {
  final Resource resource;
  final double size;
  const ResourceThumb({super.key, required this.resource, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final color = resource.type.color;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(resource.type.icon, color: color, size: size * 0.42),
    );
    final img = resource.displayImage;
    if (img == null || img.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        img,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

/// A small status/deadline chip.
class ResourcePill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const ResourcePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 8 : 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Feed card for a single [Resource] (opportunity or discount). Includes an
/// inline save (bookmark) toggle.
class ResourceCard extends ConsumerWidget {
  final Resource resource;
  final VoidCallback onTap;
  const ResourceCard({super.key, required this.resource, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved = ref.watch(savedResourceIdsProvider).valueOrNull ?? const {};
    final isSaved = saved.contains(resource.id);
    final status = resource.effectiveStatus;
    final days = resource.daysUntilDeadline;
    final match = ref.watch(resourceScoreProvider(resource));

    String? deadlineLabel;
    Color deadlineColor = theme.hintColor;
    if (resource.type.isDiscount) {
      deadlineLabel =
          (resource.discountText != null && resource.discountText!.isNotEmpty)
              ? resource.discountText
              : null;
      deadlineColor = AppColors.success;
    } else if (days != null) {
      if (days > 1) {
        deadlineLabel = 'Closes in $days days';
        deadlineColor = days <= 7 ? AppColors.warning : theme.hintColor;
      } else if (days == 1) {
        deadlineLabel = 'Closes tomorrow';
        deadlineColor = AppColors.warning;
      } else if (days == 0) {
        deadlineLabel = 'Closes today';
        deadlineColor = AppColors.danger;
      } else {
        deadlineLabel = 'Closed';
        deadlineColor = AppColors.danger;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: softCard(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResourceThumb(resource: resource),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ResourcePill(
                        label: resource.type.label,
                        color: resource.type.color,
                        icon: resource.type.icon,
                      ),
                      if (status != ResourceStatus.active)
                        ResourcePill(label: status.label, color: status.color),
                      if (resource.sponsored)
                        const ResourcePill(
                            label: 'Sponsored', color: AppColors.accent),
                      if (!resource.type.isDiscount &&
                          match.personalized &&
                          match.score >= 60)
                        ResourcePill(
                          label: '${match.score}% match',
                          color: AppColors.success,
                          icon: Icons.auto_awesome_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(resource.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor)),
                  if (deadlineLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                            resource.type.isDiscount
                                ? Icons.local_offer_rounded
                                : Icons.schedule_rounded,
                            size: 13,
                            color: deadlineColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(deadlineLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: deadlineColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _SaveButton(resource: resource, isSaved: isSaved),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  final Resource resource;
  final bool isSaved;
  const _SaveButton({required this.resource, required this.isSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isSaved ? AppColors.primary : Theme.of(context).hintColor,
      ),
      tooltip: isSaved ? 'Saved' : 'Save',
      onPressed: () {
        final ctrl = ref.read(savedResourceControllerProvider);
        if (!ctrl.isReady) return;
        final saved = ref.read(savedResourceIdsProvider).valueOrNull ?? const {};
        ctrl.toggle(resource, saved);
      },
    );
  }
}
