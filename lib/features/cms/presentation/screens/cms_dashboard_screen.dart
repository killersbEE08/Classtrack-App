import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/cms_role.dart';

/// CMS landing page: greeting + a summary of what this role can do, with quick
/// links to the modules they can access. Live content metrics arrive with the
/// Resources module.
class CmsDashboardScreen extends StatelessWidget {
  final CmsRole role;
  const CmsDashboardScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final caps = <(String, IconData, bool)>[
      ('Manage content', Icons.inventory_2_rounded, role.canEditContent),
      ('Moderate reports', Icons.flag_rounded, role.canModerate),
      ('Marketing & banners', Icons.campaign_rounded, role.canManageMarketing),
      ('View analytics', Icons.insights_rounded, role.canViewAnalytics),
      ('Manage users', Icons.group_rounded, role.canManageUsers),
      ('Audit logs', Icons.receipt_long_rounded, role.canViewAuditLogs),
    ];

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text('Dashboard', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Signed in as ${role.label}. Here\'s what you can manage.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 900
                ? 3
                : (constraints.maxWidth > 560 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 3.2,
              children: [
                for (final (label, icon, enabled) in caps)
                  _CapabilityCard(label: label, icon: icon, enabled: enabled),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  const _CapabilityCard({
    required this.label,
    required this.icon,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled ? AppColors.primary : theme.hintColor;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
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
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 18,
              color: enabled ? AppColors.success : theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }
}
