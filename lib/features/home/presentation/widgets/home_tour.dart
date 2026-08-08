import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One step of the [HomeTour]. When [key] is null the step is a centered
/// "welcome" card with no spotlight; otherwise the widget that owns [key] is
/// spotlit and a callout is placed next to it.
class TourStep {
  final GlobalKey? key;
  final String title;
  final String body;
  final IconData icon;

  /// A circular spotlight (for round targets like the FAB) instead of a
  /// rounded rectangle.
  final bool circle;

  const TourStep({
    required this.title,
    required this.body,
    required this.icon,
    this.key,
    this.circle = false,
  });
}

/// A lightweight, dependency-free coach-mark tour. Dims the screen, punches a
/// spotlight hole around each target in turn, and shows a callout with
/// Skip / Next / Done controls. Insert it into the [Overlay] above the shell.
///
/// It reads each target's on-screen rectangle from its [GlobalKey] at paint
/// time, so it works with the app's existing bottom nav and FAB without those
/// widgets needing to know anything about the tour.
class HomeTour extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onFinish;

  const HomeTour({super.key, required this.steps, required this.onFinish});

  @override
  State<HomeTour> createState() => _HomeTourState();
}

class _HomeTourState extends State<HomeTour> {
  int _index = 0;

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinish();
    } else {
      setState(() => _index++);
    }
  }

  Rect? _rectFor(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final size = MediaQuery.of(context).size;
    final rawRect = _rectFor(step.key);
    // Inflate the spotlight a little so the target isn't cropped tight.
    final hole = rawRect?.inflate(8);
    final isLast = _index == widget.steps.length - 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dimmed backdrop with a spotlight cut-out. Tapping it advances.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: CustomPaint(
                painter: _SpotlightPainter(hole: hole, circle: step.circle),
              ),
            ),
          ),
          _callout(context, step, hole, size, isLast),
        ],
      ),
    );
  }

  Widget _callout(
    BuildContext context,
    TourStep step,
    Rect? hole,
    Size size,
    bool isLast,
  ) {
    final theme = Theme.of(context);

    // A definite, bounded card width. Using a fixed width (rather than only a
    // maxWidth) guarantees the button row's Spacer never sees an unbounded
    // width — which previously threw "BoxConstraints forces an infinite width"
    // and left the tour as an un-tappable dark scrim.
    final double cardWidth =
        math.min(size.width - 40.0, 420.0).clamp(0.0, size.width).toDouble();

    final card = _TourCard(
      icon: step.icon,
      title: step.title,
      body: step.body,
      index: _index,
      total: widget.steps.length,
      isLast: isLast,
      onSkip: widget.onFinish,
      onNext: _next,
    );

    // No target -> centered welcome card.
    if (hole == null) {
      return Center(
        child: SizedBox(width: cardWidth, child: card),
      );
    }

    // Place the callout on the side of the target with the most room.
    final spaceAbove = hole.top;
    final spaceBelow = size.height - hole.bottom;
    final below = spaceBelow >= spaceAbove;
    final double left =
        ((size.width - cardWidth) / 2).clamp(0.0, size.width).toDouble();

    return Positioned(
      left: left,
      width: cardWidth,
      top: below ? hole.bottom + 16 : null,
      bottom: below ? null : size.height - hole.top + 16,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!,
        child: card,
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _TourCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.softShadow(opacity: 0.18, blur: 28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.hintColor, height: 1.35)),
          const SizedBox(height: 10),
          Row(
            children: [
              // Progress dots.
              Row(
                children: List.generate(total, (i) {
                  final active = i == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Spacer(),
              if (!isLast)
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onNext,
                child: Text(isLast ? 'Done' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final bool circle;

  _SpotlightPainter({required this.hole, required this.circle});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final full = Offset.zero & size;

    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }

    final Path holePath;
    if (circle) {
      final center = hole!.center;
      final radius = hole!.longestSide / 2 + 4;
      holePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      holePath = Path()
        ..addRRect(
            RRect.fromRectAndRadius(hole!, const Radius.circular(18)));
    }

    final combined = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      holePath,
    );
    canvas.drawPath(combined, scrim);

    // Soft highlight ring around the spotlight.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.65);
    if (circle) {
      canvas.drawCircle(
          hole!.center, hole!.longestSide / 2 + 4, ring);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(hole!, const Radius.circular(18)), ring);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.hole != hole || old.circle != circle;
}
