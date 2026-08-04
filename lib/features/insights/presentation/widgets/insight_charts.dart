import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A small, dependency-free chart toolkit for the Insights screen.
///
/// Everything here is custom-painted / composed from primitives so the app
/// gains no new packages. Widgets animate in on first build for a polished feel
/// and adapt to light/dark themes via the ambient [ThemeData].

// ─────────────────────────────────────────────────────────────────────────
// Progress ring (attendance, GPA fill, etc.)
// ─────────────────────────────────────────────────────────────────────────

/// An animated circular progress ring with an optional target tick and a
/// free-form widget in its centre.
class RingChart extends StatelessWidget {
  final double value; // 0..1
  final double? target; // 0..1, draws a subtle tick
  final Color color;
  final Color? trackColor;
  final double size;
  final double stroke;
  final Widget? center;

  const RingChart({
    super.key,
    required this.value,
    this.target,
    required this.color,
    this.trackColor,
    this.size = 148,
    this.stroke = 14,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = trackColor ??
        (theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.12));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            target: target,
            color: color,
            track: track,
            stroke: stroke,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double? target;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter({
    required this.value,
    required this.target,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    const start = -math.pi / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (value > 0) {
      final sweep = 2 * math.pi * value;
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + 2 * math.pi,
          colors: [color.withValues(alpha: 0.65), color],
          transform: const GradientRotation(start),
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        progressPaint,
      );
    }

    // Target tick.
    final t = target;
    if (t != null && t > 0 && t <= 1) {
      final angle = start + 2 * math.pi * t;
      final inner = radius - stroke / 2 - 2;
      final outer = radius + stroke / 2 + 2;
      final p1 = center + Offset(math.cos(angle) * inner, math.sin(angle) * inner);
      final p2 = center + Offset(math.cos(angle) * outer, math.sin(angle) * outer);
      final tickPaint = Paint()
        ..color = AppColors.ink.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.target != target ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

// ─────────────────────────────────────────────────────────────────────────
// Donut (category breakdown)
// ─────────────────────────────────────────────────────────────────────────

class DonutSlice {
  final double value;
  final Color color;
  final String label;
  const DonutSlice(this.label, this.value, this.color);
}

/// A donut/ring chart built from weighted [slices], with an optional centre.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double size;
  final double stroke;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.slices,
    this.size = 150,
    this.stroke = 20,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    final track = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.primary.withValues(alpha: 0.08);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            slices: slices,
            total: total,
            progress: t,
            stroke: stroke,
            track: track,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double total;
  final double progress;
  final double stroke;
  final Color track;

  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.stroke,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0) return;
    const gap = 0.04; // radians between slices
    var angle = -math.pi / 2;
    for (final s in slices) {
      final full = 2 * math.pi * (s.value / total);
      final sweep = math.max(0.0, full - gap) * progress;
      if (sweep <= 0) {
        angle += full;
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color;
      canvas.drawArc(ringRect, angle + gap / 2, sweep, false, paint);
      angle += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.total != total ||
      old.slices != slices;
}

// ─────────────────────────────────────────────────────────────────────────
// Vertical bars (weekly study, etc.)
// ─────────────────────────────────────────────────────────────────────────

class BarDatum {
  final String label;
  final double value;
  final bool highlight;
  const BarDatum(this.label, this.value, {this.highlight = false});
}

/// A compact animated vertical bar chart with labels beneath each bar.
class MiniBarChart extends StatelessWidget {
  final List<BarDatum> data;
  final Color color;
  final double height;
  final String Function(double)? valueLabel;

  const MiniBarChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 120,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = data.fold<double>(0, (m, d) => math.max(m, d.value));
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (valueLabel != null && d.value > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          valueLabel!(d.value),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final full = c.maxHeight;
                          final target = full * (d.value / safeMax);
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: target),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, h, _) => Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: h.clamp(0, full),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: d.highlight
                                        ? [color, color.withValues(alpha: 0.75)]
                                        : [
                                            color.withValues(alpha: 0.55),
                                            color.withValues(alpha: 0.30),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: d.highlight ? color : theme.hintColor,
                        fontWeight:
                            d.highlight ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Horizontal bar row (per-subject attendance, per-subject grades)
// ─────────────────────────────────────────────────────────────────────────

/// A labelled horizontal progress bar with a trailing value chip.
class BarRow extends StatelessWidget {
  final String label;
  final double fraction; // 0..1
  final Color color;
  final String trailing;
  final Color? trailingColor;

  const BarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.color,
    required this.trailing,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: trailingColor ?? color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: track),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutCubic,
                  builder: (context, f, _) => FractionallySizedBox(
                    widthFactor: f,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────
// Linear meter with markers (budget: spent → projected vs budget)
// ─────────────────────────────────────────────────────────────────────────

/// A horizontal meter that fills to [spentFraction] with an optional
/// translucent [projectedFraction] overlay and a budget marker line at 1.0.
class BudgetMeter extends StatelessWidget {
  final double spentFraction; // 0..1+
  final double projectedFraction; // 0..1+
  final Color color;
  final bool over;

  const BudgetMeter({
    super.key,
    required this.spentFraction,
    required this.projectedFraction,
    required this.color,
    required this.over,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.12);
    final barColor = over ? AppColors.danger : color;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        double clamp01(double v) => v.clamp(0.0, 1.0);
        return SizedBox(
          height: 16,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Projected (faint).
              Container(
                height: 12,
                width: w * clamp01(projectedFraction),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Spent (solid, animated).
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamp01(spentFraction)),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, f, _) => Container(
                  height: 12,
                  width: w * f,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [barColor.withValues(alpha: 0.75), barColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Budget marker at full width.
              Positioned(
                left: w - 2,
                child: Container(
                  width: 2,
                  height: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Semicircular gauge (GPA)
// ─────────────────────────────────────────────────────────────────────────

/// A 180° gauge that fills to [value] (0..1) with a centred [center] widget.
class GaugeChart extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double size;
  final double stroke;
  final Widget? center;

  const GaugeChart({
    super.key,
    required this.value,
    required this.color,
    this.size = 160,
    this.stroke = 16,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.12);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size / 2 + stroke,
        child: CustomPaint(
          painter: _GaugePainter(value: v, color: color, track: track, stroke: stroke),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: size * 0.04),
              child: center,
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    if (value > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.65), color],
        ).createShader(rect);
      canvas.drawArc(rect, math.pi, math.pi * value, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color || old.track != track;
}

// ─────────────────────────────────────────────────────────────────────────
// Small KPI chip
// ─────────────────────────────────────────────────────────────────────────

/// A compact stat pill: an icon, a big value, and a caption. Used in KPI rows.
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;
  final Color color;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

/// A tiny colour-dot + label legend entry, used beside donut charts.
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String? value;
  const LegendDot({super.key, required this.color, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
        if (value != null) ...[
          const SizedBox(width: 4),
          Text(value!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: theme.hintColor)),
        ],
      ],
    );
  }
}
