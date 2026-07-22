import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Soft, shadowed card decoration used across the redesigned screens.
BoxDecoration softCard(
  BuildContext context, {
  Color? color,
  double radius = 26,
  bool shadow = true,
}) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: color ?? theme.cardColor,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadow && theme.brightness == Brightness.light
        ? AppColors.softShadow(opacity: 0.06, blur: 22)
        : null,
  );
}

/// Circular icon button used in headers (settings, notifications, back).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? background;
  final Color? iconColor;
  final double size;

  const RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.background,
    this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: background ?? theme.cardColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              size: 21,
              color: iconColor ?? theme.textTheme.titleLarge?.color),
        ),
      ),
    );
  }
}

/// A small dark/tinted pill label (e.g. "Today", "1h 30m").
class PillTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const PillTag({
    super.key,
    required this.label,
    this.background = AppColors.ink,
    this.foreground = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon != null ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section header row: a bold title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
