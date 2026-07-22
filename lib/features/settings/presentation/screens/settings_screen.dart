import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classtrack/core/theme/app_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/notification_prefs_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../insights/presentation/screens/insights_screen.dart';
import '../../../moments/presentation/screens/moments_screen.dart';
import '../../../referral/presentation/screens/referral_screen.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../../services/notification_service.dart';
import '../../../subscription/domain/pro_constants.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final target =
        profile?.targetAttendancePercent ?? AppConstants.defaultTargetAttendance;
    final lead = ref.watch(reminderLeadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileHeader(theme, profile?.displayName, profile?.email),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'ClassTrack Pro'),
          _proCard(context, ref, theme),
          const SizedBox(height: 8),
          _card(
            theme,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.insights_rounded, color: AppColors.primary),
              title: const Text('Insights & predictions'),
              subtitle: const Text(
                  'Attendance forecasts, spending & grade trends'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                if (ref.read(isProProvider)) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const InsightsScreen()));
                } else {
                  await showPaywall(context);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Grow ClassTrack'),
          _card(
            theme,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.card_giftcard_rounded,
                      color: AppColors.primary),
                  title: const Text('Invite friends & earn Pro'),
                  subtitle: Text(
                      'You both get ${AppConstants.referralRewardDays} days of Pro free'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReferralScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome_motion_rounded,
                      color: AppColors.coral),
                  title: const Text('Shareable moments'),
                  subtitle: const Text('Turn your wins into share-worthy cards'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MomentsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Attendance'),
          _card(
            theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Target attendance'),
                    const Spacer(),
                    Text('${target.toStringAsFixed(0)}%',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary)),
                  ],
                ),
                Slider(
                  value: target.clamp(50, 100),
                  min: 50,
                  max: 100,
                  divisions: 50,
                  label: '${target.toStringAsFixed(0)}%',
                  onChanged: (v) {
                    final uid = ref.read(currentUidProvider);
                    if (uid != null) {
                      ref
                          .read(authRepositoryProvider)
                          .updateTargetAttendance(uid, v);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Grades'),
          _card(
            theme,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('GPA scale'),
                      Text(
                        ref.watch(gpaScaleProvider) == GpaScaleType.ten
                            ? '10-point (CGPA)'
                            : '4.0 scale',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ...[
                  (GpaScaleType.four, '4.0'),
                  (GpaScaleType.ten, '10'),
                ].map((e) {
                  final selected = ref.watch(gpaScaleProvider) == e.$1;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: selected,
                      onSelected: (_) =>
                          ref.read(gpaScaleProvider.notifier).set(e.$1),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Appearance'),
          _card(
            theme,
            child: Column(
              children: ThemeMode.values.map((mode) {
                return RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (mode) {
                    ThemeMode.system => 'System default',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  }),
                  value: mode,
                  groupValue: themeMode,
                  onChanged: (m) =>
                      ref.read(themeModeProvider.notifier).set(m!),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          _accentCard(context, ref, theme),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Notifications'),
          _card(
            theme,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(PhosphorIcons.bell(), color: AppColors.primary),
                  title: const Text('Enable reminders'),
                  subtitle: const Text(
                      'For classes, tasks, exams, courses & videos'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _enableNotifications(context, ref),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Remind me before',
                            style: theme.textTheme.bodyMedium),
                      ),
                      ...[10, 30].map((m) {
                        final selected = lead == m;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text('$m min'),
                            selected: selected,
                            onSelected: (_) async {
                              await ref
                                  .read(reminderLeadProvider.notifier)
                                  .set(m);
                              await _enableNotifications(context, ref,
                                  silent: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Reminders set to $m minutes before.')),
                                );
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _notificationPrefsCard(context, ref, theme),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Support & feedback'),
          _supportCard(context, ref, theme),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'About & legal'),
          _card(
            theme,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(PhosphorIcons.shieldCheck(),
                      color: AppColors.primary),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(PhosphorIcons.info(), color: AppColors.primary),
                  title: const Text('Version'),
                  trailing: const Text('1.0.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Account'),
          _card(
            theme,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(PhosphorIcons.signOut()),
                  title: const Text('Sign out'),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: AppColors.danger),
                  title: const Text('Delete account',
                      style: TextStyle(color: AppColors.danger)),
                  subtitle: const Text('Permanently remove your data'),
                  onTap: () => _deleteAccount(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enableNotifications(BuildContext context, WidgetRef ref,
      {bool silent = false}) async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notification permission denied.')));
      return;
    }
    final lead = ref.read(reminderLeadProvider);
    // Reschedule reminders for every subject's sessions.
    final subjects = ref.read(subjectsStreamProvider).valueOrNull ?? const [];
    await service.cancelAll();
    for (final s in subjects) {
      final sessions =
          ref.read(sessionsForSubjectProvider(s.id)).valueOrNull ?? const [];
      await service.scheduleForSubject(s, sessions, minutesBefore: lead);
    }
    // Reminders for tasks / courses / videos with a due date.
    final tasks = ref.read(tasksStreamProvider).valueOrNull ?? const [];
    await service.scheduleForTasks(tasks, minutesBefore: lead);
    // Exam reminders (evening-before + before the exam).
    final exams = ref.read(examsStreamProvider).valueOrNull ?? const [];
    await service.scheduleForExams(exams, minutesBefore: 30);
    // Remember that reminders are on so they auto-refresh as data changes.
    await ref.read(remindersEnabledProvider.notifier).set(true);
    if (context.mounted && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Reminders scheduled — classes & tasks $lead min before, exams too.')));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your profile, subjects, schedule and attendance history. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(authControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Please sign out and sign in again, then retry deleting your account.'),
      ));
    }
  }

  Widget _profileHeader(ThemeData theme, String? name, String? email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name ?? 'Student',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: Colors.white)),
                if (email != null)
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _proCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final isPro = ref.watch(isProProvider);
    if (isPro) {
      return _card(
        theme,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.workspace_premium_rounded,
              color: AppColors.primary),
          title: const Text('Pro active'),
          subtitle: const Text('Thanks for supporting ClassTrack 💜'),
          trailing: TextButton(
            onPressed: () async {
              await ref.read(subscriptionServiceProvider).restore();
            },
            child: const Text('Restore'),
          ),
        ),
      );
    }
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.primary),
            title: const Text('Upgrade to Pro'),
            subtitle: Text(
              ProConstants.enabled
                  ? 'Unlimited AI, photo import, exports and more.'
                  : 'Unlimited AI, photo import, exports and more (coming soon).',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showPaywall(context),
          ),
        ],
      ),
    );
  }

  // ── Accent color (Pro) ──────────────────────────────────────────────────
  Widget _accentCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final selected = ref.watch(accentColorProvider);
    final isPro = ref.watch(isProProvider);
    const palette = <Color>[
      AppColors.primary, // default purple
      Color(0xFF0EA5E9), // sky
      Color(0xFF22C55E), // emerald
      Color(0xFFF59E0B), // amber
      Color(0xFFEF4444), // red
      Color(0xFFEC4899), // pink
      Color(0xFF14B8A6), // teal
      Color(0xFFF97316), // orange
      Color(0xFF6366F1), // indigo
    ];
    Future<void> pick(Color? c) async {
      if (!isPro) {
        await showPaywall(context);
        return;
      }
      // Tapping the default purple clears the custom accent.
      await ref
          .read(accentColorProvider.notifier)
          .set(c == AppColors.primary ? null : c);
    }

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text('Accent color'),
                const SizedBox(width: 8),
                _proChip(theme),
                const Spacer(),
                Text(selected == null ? 'Default' : 'Custom',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () => pick(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (selected == null && c == AppColors.primary) ||
                                selected?.toARGB32() == c.toARGB32()
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: ((selected == null && c == AppColors.primary) ||
                            selected?.toARGB32() == c.toARGB32())
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Notification preferences ────────────────────────────────────────────
  Widget _notificationPrefsCard(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    final prefs = ref.watch(notificationPrefsProvider);
    final ctrl = ref.read(notificationPrefsProvider.notifier);
    final isPro = ref.watch(isProProvider);
    return _card(
      theme,
      child: Column(
        children: [
          _switchTile(theme, 'Class reminders', prefs.classes,
              (v) => ctrl.setCategory(classes: v)),
          const Divider(height: 1),
          _switchTile(theme, 'Task & deadline reminders', prefs.tasks,
              (v) => ctrl.setCategory(tasks: v)),
          const Divider(height: 1),
          _switchTile(theme, 'Exam reminders', prefs.exams,
              (v) => ctrl.setCategory(exams: v)),
          const Divider(height: 1),
          _switchTile(theme, 'Habit reminders', prefs.habits,
              (v) => ctrl.setCategory(habits: v)),
          const Divider(height: 1),
          _proSwitchTile(
            context,
            theme,
            title: 'Daily agenda summary',
            subtitle: (prefs.dailySummary && isPro)
                ? 'Every day at ${prefs.summaryTime.format(context)} · tap to change'
                : 'A morning digest of your classes, tasks & exams',
            value: prefs.dailySummary && isPro,
            isPro: isPro,
            onChanged: (v) => ctrl.setDailySummary(v),
            onTap: (prefs.dailySummary && isPro)
                ? () async {
                    final t = await showTimePicker(
                        context: context, initialTime: prefs.summaryTime);
                    if (t != null) ctrl.setDailySummary(true, at: t);
                  }
                : null,
          ),
          const Divider(height: 1),
          _proSwitchTile(
            context,
            theme,
            title: 'Quiet hours',
            subtitle: (prefs.quietHours && isPro)
                ? '${prefs.quietStartHour}:00 – ${prefs.quietEndHour}:00 · tap to change'
                : 'Silence reminders during a set window',
            value: prefs.quietHours && isPro,
            isPro: isPro,
            onChanged: (v) => ctrl.setQuietHours(v),
            onTap: (prefs.quietHours && isPro)
                ? () => _editQuietHours(context, ref)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
      ThemeData theme, String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _proSwitchTile(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required bool isPro,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(child: Text(title)),
          const SizedBox(width: 8),
          _proChip(theme),
        ],
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Switch(
        value: value,
        onChanged: (v) async {
          if (!isPro) {
            await showPaywall(context);
            return;
          }
          onChanged(v);
        },
      ),
      onTap: onTap,
    );
  }

  Widget _proChip(ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text('PRO',
            style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
      );

  Future<void> _editQuietHours(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(notificationPrefsProvider);
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.quietStartHour, minute: 0),
      helpText: 'Quiet hours START',
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.quietEndHour, minute: 0),
      helpText: 'Quiet hours END',
    );
    if (end == null) return;
    await ref
        .read(notificationPrefsProvider.notifier)
        .setQuietHours(true, startHour: start.hour, endHour: end.hour);
  }

  // ── Support & feedback ──────────────────────────────────────────────────
  Widget _supportCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    return _card(
      theme,
      child: Column(
        children: [
          _actionTile(theme, Icons.star_rounded, 'Rate ClassTrack',
              () => _rate(context)),
          const Divider(height: 1),
          _actionTile(theme, Icons.ios_share_rounded, 'Share with friends',
              () => _shareApp()),
          const Divider(height: 1),
          _actionTile(theme, Icons.feedback_rounded, 'Send feedback',
              () => _sendFeedback()),
          const Divider(height: 1),
          _actionTile(theme, Icons.card_membership_rounded,
              'Manage subscription', () => _manageSubscription()),
          const Divider(height: 1),
          _actionTile(theme, Icons.restore_rounded, 'Restore purchases',
              () => _restorePurchases(context, ref)),
        ],
      ),
    );
  }

  Widget _actionTile(
      ThemeData theme, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Future<void> _rate(BuildContext context) async {
    final market = Uri.parse(AppConstants.playStoreMarketUrl);
    if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse(AppConstants.playStoreUrl),
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out ClassTrack — track your attendance, timetable, tasks, '
      'grades and expenses, with an AI study assistant:\n'
      '${AppConstants.playStoreUrl}',
      subject: 'ClassTrack',
    );
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=${Uri.encodeComponent('ClassTrack feedback')}',
    );
    await launchUrl(uri);
  }

  Future<void> _manageSubscription() async {
    await launchUrl(Uri.parse(AppConstants.manageSubscriptionsUrl),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(subscriptionServiceProvider).restore();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Purchases restored ✅'
          : 'No previous purchases found for this account.'),
    ));
  }

  Widget _sectionLabel(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
        child: Text(text.toUpperCase(),
            style: theme.textTheme.labelMedium
                ?.copyWith(letterSpacing: 1.0, color: theme.hintColor)),
      );

  Widget _card(ThemeData theme, {required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: theme.brightness == Brightness.light
              ? AppColors.softShadow(opacity: 0.05, blur: 18)
              : null,
        ),
        child: child,
      );
}
