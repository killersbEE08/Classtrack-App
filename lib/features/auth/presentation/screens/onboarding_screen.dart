import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';

class _Page {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _Page(this.icon, this.title, this.body, this.color);
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  late final List<_Page> _pages = [
    const _Page(
      Icons.waving_hand_rounded,
      'Welcome to ClassTrack',
      'Manage your academic life in one place — classes, attendance, tasks, exams and more.',
      AppColors.primary,
    ),
    const _Page(
      Icons.auto_awesome_rounded,
      'AI Assistant',
      'Ask things like “When am I free tomorrow?” and get instant, personalised answers.',
      AppColors.info,
    ),
    const _Page(
      Icons.smart_display_rounded,
      'Save Videos Instantly',
      'Share any YouTube video directly to ClassTrack to create a study task in seconds.',
      AppColors.coral,
    ),
    const _Page(
      Icons.event_available_rounded,
      'Google Calendar',
      'Import your existing schedule in one tap and keep everything in sync.',
      AppColors.success,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingDoneProvider.notifier).complete();
    // Router redirect will move the user forward automatically.
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _index == _pages.length - 1;
    final accent = _pages[_index].color;

    return Scaffold(
      // Soft accent wash that animates as you swipe between pages.
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: 0.14),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  // Back appears from page 2 onwards.
                  AnimatedOpacity(
                    opacity: _index == 0 ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      onPressed: _index == 0 ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated concentric glow + icon.
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  color: page.color.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.05, 1.05),
                                      duration: 2200.ms,
                                      curve: Curves.easeInOut),
                              Container(
                                padding: const EdgeInsets.all(34),
                                decoration: BoxDecoration(
                                  color: page.color.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          page.color.withValues(alpha: 0.25),
                                      blurRadius: 30,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Icon(page.icon,
                                    size: 84, color: page.color),
                              )
                                  .animate(key: ValueKey(i))
                                  .scale(
                                      begin: const Offset(0.5, 0.5),
                                      end: const Offset(1, 1),
                                      duration: 500.ms,
                                      curve: Curves.easeOutBack)
                                  .fadeIn(duration: 350.ms),
                            ],
                          ),
                          const SizedBox(height: 44),
                          Text(page.title,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center)
                              .animate(key: ValueKey('t$i'))
                              .fadeIn(delay: 120.ms, duration: 400.ms)
                              .slideY(begin: 0.25, curve: Curves.easeOut),
                          const SizedBox(height: 14),
                          Text(page.body,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.textTheme.bodySmall?.color,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center)
                              .animate(key: ValueKey('b$i'))
                              .fadeIn(delay: 220.ms, duration: 400.ms)
                              .slideY(begin: 0.2, curve: Curves.easeOut),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: i == _index ? 26 : 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? accent
                          : theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Row(
                        key: ValueKey(isLast),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLast ? 'Let’s Go' : 'Next',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(width: 8),
                          Icon(isLast
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
