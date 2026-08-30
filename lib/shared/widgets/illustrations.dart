import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';

/// Gentle looping vertical float used by the decorative illustration pieces.
/// Kept small and few in number so it stays perfectly smooth.
Widget _float(Widget child,
    {double dy = 6, int ms = 2600, int delayMs = 0}) {
  return child
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .moveY(
        begin: -dy,
        end: dy,
        duration: ms.ms,
        curve: Curves.easeInOut,
        delay: delayMs.ms,
      );
}

Widget _chip({
  required IconData icon,
  required Color color,
  double size = 44,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// A friendly, on-brand illustrated header for the auth screens — a central
/// brand tile surrounded by softly floating "student life" chips (calendar,
/// grade, streak, tasks) over a soft lavender backdrop. Pure widgets, so it's
/// crisp at any size and needs no image assets.
class AuthIllustration extends StatelessWidget {
  final double height;
  const AuthIllustration({super.key, this.height = 190});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Soft backdrop blobs.
          Container(
            width: 168,
            height: 168,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.lavender, AppColors.lavenderTint],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: 44,
            top: 8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: 10,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Central brand tile.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.42),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(Icons.calendar_month_rounded,
                size: 46, color: Colors.white),
          )
              .animate()
              .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  duration: 450.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(duration: 320.ms),
          // Floating chips (kept to two for a light, smooth first frame).
          Positioned(
            left: 26,
            top: 30,
            child: _float(
                _chip(icon: Icons.check_circle_rounded, color: AppColors.success),
                dy: 6, ms: 2600),
          ),
          Positioned(
            right: 30,
            bottom: 24,
            child: _float(
                _chip(icon: Icons.school_rounded, color: AppColors.accent, size: 40),
                dy: 5, ms: 2800, delayMs: 400),
          ),
        ],
      ),
    ),
    );
  }
}

/// A friendly, animated illustration for empty states: the given [icon] in a
/// gradient medallion over soft halos, with a couple of gently floating accent
/// dots. Used by the shared `EmptyState` so every empty screen feels alive.
///
/// Only two tiny elements float, so it stays perfectly smooth on any screen.
class EmptyIllustration extends StatelessWidget {
  final IconData icon;
  final Color color;
  const EmptyIllustration({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    Widget dot(double size, double opacity) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        );

    return SizedBox(
      height: 138,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.07),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.82), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 38),
          )
              .animate()
              .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  duration: 460.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(duration: 320.ms),
          Positioned(
            left: 44,
            top: 20,
            child: _float(dot(11, 0.35), dy: 5, ms: 2600),
          ),
          Positioned(
            right: 46,
            bottom: 22,
            child: _float(dot(8, 0.28), dy: 6, ms: 3000, delayMs: 300),
          ),
        ],
      ),
    );
  }
}

/// ringed by softly floating sparkles. Designed for a dark gradient backdrop.
class PremiumIllustration extends StatelessWidget {
  final double height;
  const PremiumIllustration({super.key, this.height = 150});

  @override
  Widget build(BuildContext context) {
    Widget sparkle(double size, double opacity) => Icon(
          Icons.auto_awesome_rounded,
          size: size,
          color: Colors.white.withValues(alpha: opacity),
        );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.accent, size: 38),
          )
              .animate()
              .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 460.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(),
          Positioned(
              left: 44, top: 20, child: _float(sparkle(20, 0.9), dy: 5, ms: 2400)),
          Positioned(
              right: 46,
              top: 34,
              child: _float(sparkle(14, 0.7), dy: 6, ms: 2800, delayMs: 200)),
          Positioned(
              right: 62,
              bottom: 20,
              child: _float(sparkle(22, 0.85), dy: 5, ms: 2600, delayMs: 400)),
          Positioned(
              left: 58,
              bottom: 24,
              child: _float(sparkle(12, 0.6), dy: 7, ms: 3000, delayMs: 100)),
        ],
      ),
    );
  }
}
