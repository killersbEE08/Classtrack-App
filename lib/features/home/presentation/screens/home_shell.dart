import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/reminder_scheduler.dart';
import '../../../../services/home_widget_service.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../../../schedule/presentation/screens/edit_session_screen.dart';
import '../../../subjects/presentation/screens/edit_subject_screen.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../../../attendance/presentation/screens/progress_screen.dart';
import '../../../exams/presentation/screens/exams_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../grades/presentation/screens/grades_screen.dart';
import '../../../habits/presentation/screens/habits_screen.dart';
import '../../../notes/presentation/screens/notes_screen.dart';
import 'dashboard_screen.dart';

/// Opens the "quick add" menu triggered by the center FAB. Available app-wide.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget option({
        required IconData icon,
        required Color color,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          onTap: onTap,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text('Quick add', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
              option(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.primary,
                title: 'New task',
                subtitle: 'Assignment, deadline or to-do',
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const TaskEditorSheet(),
                  );
                },
              ),
              option(
                icon: Icons.play_circle_fill_rounded,
                color: AppColors.coral,
                title: 'Course / video',
                subtitle: 'Plan a course or video and paste its link',
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        const TaskEditorSheet(initialType: TaskType.course),
                  );
                },
              ),
              option(
                icon: Icons.calendar_today_rounded,
                color: AppColors.info,
                title: 'New class',
                subtitle: 'Add a session to your timetable',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EditSessionScreen()));
                },
              ),
              option(
                icon: Icons.menu_book_rounded,
                color: AppColors.coral,
                title: 'New subject',
                subtitle: 'Track attendance for a course',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EditSubjectScreen()));
                },
              ),
              option(
                icon: Icons.event_note_rounded,
                color: AppColors.danger,
                title: 'New exam',
                subtitle: 'Add a test with a live countdown',
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ExamEditorSheet(),
                  );
                },
              ),
              option(
                icon: Icons.school_rounded,
                color: AppColors.primary,
                title: 'Log grade',
                subtitle: 'Record a mark and update your GPA',
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const GradeEditorSheet(),
                  );
                },
              ),
              option(
                icon: Icons.sticky_note_2_rounded,
                color: AppColors.info,
                title: 'New note',
                subtitle: 'Jot down a lecture note or idea',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NoteEditorScreen()));
                },
              ),
              option(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.coral,
                title: 'New habit',
                subtitle: 'Build a streak you can keep',
                onTap: () {
                  Navigator.pop(ctx);
                  // Present the editor only after the quick-add sheet has
                  // finished dismissing. Opening a second modal in the same
                  // frame as popping the first can be dropped by the navigator
                  // on some devices, which made "New habit" appear to do
                  // nothing.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const HabitEditorSheet(),
                    );
                  });
                },
              ),
              option(
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.success,
                title: 'Add expense',
                subtitle: 'Log spending and track your budget',
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ExpenseEditorSheet(),
                  );
                },
              ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    ScheduleScreen(),
    TasksScreen(),
    ProgressScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns to the app, re-check the store entitlement with a
    // forced (cache-invalidating) fetch so an expired, cancelled or refunded
    // subscription stops showing Pro promptly instead of lingering.
    if (state == AppLifecycleState.resumed) {
      ref.read(subscriptionServiceProvider).refresh(invalidateCache: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep task + exam reminders in sync with the latest data (no-op unless
    // the user has enabled reminders from Settings).
    ref.watch(reminderSyncProvider);
    // Keep RevenueCat's identity tied to the signed-in Firebase user.
    ref.watch(subscriptionAuthLinkProvider);
    // Keep the home-screen widget's "today" snapshot fresh.
    ref.watch(homeWidgetSyncProvider);
    return PopScope(
      // On non-Home tabs, the mobile back button returns to Home instead of
      // leaving the app. On Home, back exits as usual.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        extendBody: true,
        // IndexedStack keeps every tab mounted and simply shows the selected
        // one. This avoids the InheritedWidget deactivation-order crash that a
        // page-swapping AnimatedSwitcher triggered when the outgoing Scaffold
        // (and its in-page flutter_animate entrance animations) tore down while
        // descendants still depended on its Theme/MediaQuery scopes. It also
        // preserves each tab's scroll position and state between switches.
        body: IndexedStack(
          index: _index,
          children: _screens,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton:
            _CenterFab(onTap: () => showQuickAddSheet(context)),
        bottomNavigationBar: _FloatingNavBar(
          index: _index,
          onSelect: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _CenterFab extends StatefulWidget {
  final VoidCallback onTap;
  const _CenterFab({required this.onTap});

  @override
  State<_CenterFab> createState() => _CenterFabState();
}

class _CenterFabState extends State<_CenterFab>
    with SingleTickerProviderStateMixin {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.88),
        onTapUp: (_) {
          setState(() => _scale = 1);
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _scale = 1),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          )
              // Gentle continuous "breathing" so the primary action stays
              // subtly alive without being distracting.
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1,
                end: 1.06,
                duration: 2200.ms,
                curve: Curves.easeInOut,
              )
              // Springy entrance the first time the shell mounts.
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 420.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 280.ms),
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _FloatingNavBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              selected: index == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Schedule',
              selected: index == 1,
              onTap: () => onSelect(1),
            ),
            const SizedBox(width: 58), // gap for the center FAB
            _NavItem(
              icon: Icons.check_circle_outline_rounded,
              activeIcon: Icons.check_circle_rounded,
              label: 'Tasks',
              selected: index == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              icon: Icons.insert_chart_outlined_rounded,
              activeIcon: Icons.insert_chart_rounded,
              label: 'Progress',
              selected: index == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon; // outlined (unselected)
  final IconData activeIcon; // filled (selected)
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final unselectedColor = theme.textTheme.bodySmall?.color;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            if (!selected) HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.86 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Moving indicator bar that grows in under the active tab.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: selected ? 22 : 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Icon: outlined→filled with a soft pop + colour + size shift.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? widget.activeIcon : widget.icon,
                    key: ValueKey(selected),
                    size: selected ? 26 : 23,
                    color: selected ? AppColors.primary : unselectedColor,
                  ),
                ),
                // Label reveal: only the active tab shows its name, and the
                // row animates its height so the swap feels alive.
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              height: 1,
                            ),
                          ),
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
