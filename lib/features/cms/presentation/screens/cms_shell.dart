import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/cms_role.dart';
import '../providers/cms_auth_providers.dart';
import 'cms_audit_logs_screen.dart';
import 'cms_banners_screen.dart';
import 'cms_campaigns_screen.dart';
import 'cms_dashboard_screen.dart';
import 'cms_login_screen.dart';
import 'cms_notifications_screen.dart';
import 'cms_resources_screen.dart';
import 'cms_users_screen.dart';

/// A CMS navigation section, gated by the current role's permissions.
class CmsSection {
  final String label;
  final IconData icon;
  final bool Function(CmsRole) visibleTo;
  final WidgetBuilder build;
  const CmsSection({
    required this.label,
    required this.icon,
    required this.visibleTo,
    required this.build,
  });
}

/// All CMS sections in nav order. Modules are filled in incrementally; the ones
/// not yet built render a placeholder so navigation is fully functional.
final cmsSections = <CmsSection>[
  CmsSection(
    label: 'Dashboard',
    icon: Icons.space_dashboard_rounded,
    visibleTo: (_) => true,
    build: (_) => const CmsDashboardScreen(),
  ),
  CmsSection(
    label: 'Resources',
    icon: Icons.inventory_2_rounded,
    visibleTo: (r) => r.canViewContent,
    build: (_) => const CmsResourcesScreen(),
  ),
  CmsSection(
    label: 'Banners',
    icon: Icons.view_carousel_rounded,
    visibleTo: (r) => r.canManageMarketing,
    build: (_) => const CmsBannersScreen(),
  ),
  CmsSection(
    label: 'Campaigns',
    icon: Icons.campaign_rounded,
    visibleTo: (r) => r.canManageMarketing,
    build: (_) => const CmsCampaignsScreen(),
  ),
  CmsSection(
    label: 'Notifications',
    icon: Icons.notifications_active_rounded,
    visibleTo: (r) => r.canManageMarketing,
    build: (_) => const CmsNotificationsScreen(),
  ),
  CmsSection(
    label: 'Analytics',
    icon: Icons.insights_rounded,
    visibleTo: (r) => r.canViewAnalytics,
    build: (_) => const _Placeholder('Analytics'),
  ),
  CmsSection(
    label: 'Users',
    icon: Icons.group_rounded,
    visibleTo: (r) => r.canManageUsers,
    build: (_) => const CmsUsersScreen(),
  ),
  CmsSection(
    label: 'Audit logs',
    icon: Icons.receipt_long_rounded,
    visibleTo: (r) => r.canViewAuditLogs,
    build: (_) => const CmsAuditLogsScreen(),
  ),
  CmsSection(
    label: 'Settings',
    icon: Icons.settings_rounded,
    visibleTo: (r) => r.canEditConfig,
    build: (_) => const _Placeholder('Settings'),
  ),
];

/// Root of the authenticated CMS: gates on auth + role, then shows the
/// navigation shell.
class CmsShell extends ConsumerStatefulWidget {
  const CmsShell({super.key});

  @override
  ConsumerState<CmsShell> createState() => _CmsShellState();
}

class _CmsShellState extends ConsumerState<CmsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const _Loading(),
      error: (_, __) => const CmsLoginScreen(),
      data: (user) {
        if (user == null) return const CmsLoginScreen();
        final roleAsync = ref.watch(cmsRoleProvider);
        return roleAsync.when(
          loading: () => const _Loading(),
          error: (_, __) => const _NoAccess(),
          data: (role) {
            if (role == null) return const _NoAccess();
            return _buildShell(context, role, user.email ?? '');
          },
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, CmsRole role, String email) {
    final theme = Theme.of(context);
    final sections =
        cmsSections.where((s) => s.visibleTo(role)).toList(growable: false);
    if (_index >= sections.length) _index = 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 1100,
            minWidth: 72,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dashboard_customize_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            destinations: [
              for (final s in sections)
                NavigationRailDestination(
                  icon: Icon(s.icon),
                  label: Text(s.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(email: email, role: role),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: sections[_index].build(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String email;
  final CmsRole role;
  const _TopBar({required this.email, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(role.label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Text(email, style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(cmsAuthControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_rounded, size: 48, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('This module is coming next.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Signed in, but the account has no CMS role — deny access with a sign-out.
class _NoAccess extends ConsumerWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded,
                  size: 56, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('No CMS access', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'This account is signed in but has not been granted a CMS role. '
                'Ask a super admin to grant you access.',
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                onPressed: () =>
                    ref.read(cmsAuthControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
