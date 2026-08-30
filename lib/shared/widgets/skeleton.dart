import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'ui_kit.dart';

/// Placeholder "skeleton" loaders that mirror the shape of real content while
/// it streams in from Firestore. Showing a content-shaped placeholder (instead
/// of a bare spinner) makes the app feel dramatically faster because the eye
/// anticipates the layout that's about to appear.
///
/// A single [Shimmer] ancestor drives a shared sweep animation for every
/// [SkeletonBox] beneath it. The sweep is automatically disabled when the OS
/// "remove animations" accessibility setting is on (MediaQuery.disableAnimations)
/// — in that case the blocks render as a calm static fill, so the loader is
/// still informative without motion.

/// Base tint for a skeleton block, resolved from the current theme so the
/// placeholders sit correctly on both light and dark surfaces.
Color _baseColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.light
      ? AppColors.lightSurfaceAlt
      : AppColors.darkSurfaceAlt;
}

Color _highlightColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.light
      ? Colors.white
      : AppColors.darkSurface;
}

/// Public handle exposed by [Shimmer.of] so descendant [SkeletonBox]es can read
/// the shared sweep without depending on the private State type.
abstract class ShimmerController implements Listenable {
  /// Current sweep position, 0..1.
  double get value;

  /// False when the OS "remove animations" setting is on.
  bool get motionEnabled;
}

/// Drives a looping shimmer sweep for all [SkeletonBox]es in its subtree.
/// Honours reduced-motion: when animations are disabled the sweep is frozen
/// and children fall back to a flat base tint.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  static ShimmerController? of(BuildContext context) =>
      context.findAncestorStateOfType<_ShimmerState>();

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin
    implements ShimmerController {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _motionEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "remove animations" setting for vestibular safety.
    _motionEnabled = !MediaQuery.of(context).disableAnimations;
    if (_motionEnabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  double get value => _controller.value;

  @override
  bool get motionEnabled => _motionEnabled;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A single rounded placeholder block. Must have a [Shimmer] ancestor for the
/// animated sweep; without motion it renders as a flat tinted block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final base = _baseColor(context);
    final shimmer = Shimmer.of(context);

    Widget block(Color color) => Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    if (shimmer == null || !shimmer.motionEnabled) {
      return block(base);
    }

    final highlight = _highlightColor(context);
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        // Map the 0..1 controller value to a gradient sweep across the block.
        final t = shimmer.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t), 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: block(base),
        );
      },
    );
  }
}

/// A card-shaped skeleton that mirrors the app's [softCard] surfaces: a leading
/// avatar/icon block, two text lines and an optional trailing block.
class SkeletonCard extends StatelessWidget {
  final double height;
  final bool showLeading;
  final bool showTrailing;

  const SkeletonCard({
    super.key,
    this.height = 84,
    this.showLeading = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: softCard(context),
      child: Row(
        children: [
          if (showLeading) ...[
            const SkeletonBox(width: 44, height: 44, radius: 14),
            const SizedBox(width: 14),
          ],
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 13),
                SizedBox(height: 10),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const SkeletonBox(width: 48, height: 26, radius: 13),
          ],
        ],
      ),
    );
  }
}

/// A ready-to-drop-in list of [SkeletonCard]s for stream `loading:` branches.
/// Wraps itself in a [Shimmer] so callers can use it directly:
/// `loading: () => const SkeletonList()`.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final bool showTrailing;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.itemHeight = 84,
    this.showTrailing = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading',
      child: ExcludeSemantics(
        child: Shimmer(
          child: ListView.separated(
            padding: padding,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => SkeletonCard(
              height: itemHeight,
              showTrailing: showTrailing,
            ),
          ),
        ),
      ),
    );
  }
}
