import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Circular attendance ring with a percentage label.
class ProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final double size;
  final double strokeWidth;
  final String? centerLabel;
  final String? subLabel;
  final Color? color;

  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 120,
    this.strokeWidth = 9,
    this.centerLabel,
    this.subLabel,
    this.color,
  });

  Color _ringColor(BuildContext context) {
    if (color != null) return color!;
    if (percent >= 75) return AppColors.success;
    if (percent >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = _ringColor(context);
    final theme = Theme.of(context);
    // Scale the inner text to the ring diameter so labels never spill out of
    // small rings (e.g. the 72–96px cards on the Progress screen).
    final double pctFont = (size * 0.24).clamp(13.0, 34.0);
    final double subFont = (size * 0.115).clamp(8.0, 13.0);
    final double innerWidth = (size - strokeWidth * 2 - 8).clamp(24.0, size);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent.clamp(0, 100) / 100,
          color: ringColor,
          // A faint tint of the ring colour reads as a soft pastel track,
          // matching the app's minimalist vibe far better than a heavy grey.
          track: ringColor.withValues(alpha: 0.15),
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: SizedBox(
            width: innerWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerLabel ?? '${percent.toStringAsFixed(0)}%',
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: ringColor,
                      fontWeight: FontWeight.w700,
                      fontSize: pctFont,
                      height: 1.0,
                    ),
                  ),
                ),
                if (subLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        subLabel!,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: subFont,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color track;
  final double strokeWidth;

  _RingPainter({
    required this.percent,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.color != color;
}

/// A [ProgressRing] that animates (count-up) from 0 to [percent] whenever the
/// value changes. Used across attendance cards for a lively, premium feel.
class AnimatedProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final double size;
  final double strokeWidth;
  final String? subLabel;
  final String? centerLabel;
  final Color? color;
  final Duration duration;

  const AnimatedProgressRing({
    super.key,
    required this.percent,
    this.size = 120,
    this.strokeWidth = 12,
    this.subLabel,
    this.centerLabel,
    this.color,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent.clamp(0, 100)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ProgressRing(
        percent: value,
        size: size,
        strokeWidth: strokeWidth,
        subLabel: subLabel,
        centerLabel: centerLabel,
        color: color,
      ),
    );
  }
}
