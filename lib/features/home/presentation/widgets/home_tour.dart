import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One step of the home walkthrough.
class TourStep {
  final String title;
  final String body;
  final IconData icon;
  const TourStep({required this.title, required this.body, required this.icon});
}

/// Shows the first-run home walkthrough as a **safe, always-dismissible** bottom
/// sheet (swipe-down or tap the scrim to close, or use Skip/Done).
///
/// This intentionally replaces the previous full-screen spotlight overlay,
/// which on some renderers could leave a dark scrim that blocked all input.
/// [onFinish] runs once the sheet closes by any means, so the tour is always
/// marked as seen and the app is never left in a stuck state.
Future<void> showHomeTour(
  BuildContext context, {
  required List<TourStep> steps,
  required VoidCallback onFinish,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _HomeTourSheet(steps: steps),
  );
  onFinish();
}

class _HomeTourSheet extends StatefulWidget {
  final List<TourStep> steps;
  const _HomeTourSheet({required this.steps});

  @override
  State<_HomeTourSheet> createState() => _HomeTourSheetState();
}

class _HomeTourSheetState extends State<_HomeTourSheet> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= widget.steps.length - 1;

  void _next() {
    if (_isLast) {
      Navigator.of(context).maybePop();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 232,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.steps.length,
                itemBuilder: (_, i) => _StepView(step: widget.steps[i]),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: _next,
                    child: Text(_isLast ? 'Done' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final TourStep step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: AppColors.softShadow(opacity: 0.28, blur: 22),
          ),
          child: Icon(step.icon, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(step.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(step.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor, height: 1.4)),
        ),
      ],
    );
  }
}
