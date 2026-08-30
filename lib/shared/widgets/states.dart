import 'package:flutter/material.dart';
import 'package:classtrack/core/theme/app_icons.dart';

import '../../core/theme/app_colors.dart';
import 'illustrations.dart';

/// Friendly empty-state placeholder (this is where "playful" lives).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: EmptyIllustration(icon: icon, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.textTheme.bodySmall?.color),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple centered spinner.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message ?? 'Loading',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Maps a raw error object to a short, friendly, human-readable message.
///
/// Students should never see a raw exception or stack trace. Common cases
/// (offline, permission, not-found, timeout) get a tailored line; everything
/// else falls back to a calm generic message. The technical detail is still
/// captured by Crashlytics, so we don't need to show it here.
String friendlyErrorMessage(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('unavailable') ||
      text.contains('network') ||
      text.contains('socket') ||
      text.contains('failed host lookup') ||
      text.contains('connection') ||
      text.contains('offline')) {
    return 'You appear to be offline. Check your connection and try again.';
  }
  if (text.contains('deadline') || text.contains('timeout')) {
    return 'That took too long. Please try again.';
  }
  if (text.contains('permission-denied') || text.contains('permission denied')) {
    return "You don't have access to this. Try signing in again.";
  }
  if (text.contains('not-found') || text.contains('not found')) {
    return "We couldn't find that. It may have been removed.";
  }
  if (text.contains('unauthenticated') || text.contains('sign in')) {
    return 'Please sign in again to continue.';
  }
  return 'Something went wrong on our end. Please try again in a moment.';
}

/// Inline error with a friendly message and a retry action.
///
/// The message is derived from [error] via [friendlyErrorMessage] so users
/// never see a raw exception. A retry button is always shown when [onRetry] is
/// provided; pass a custom [title] to fit the surface.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? title;
  const ErrorView({super.key, required this.error, this.onRetry, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(PhosphorIcons.warningCircle(),
                  size: 40, color: AppColors.danger),
            ),
            const SizedBox(height: 12),
            Text(
              title ?? 'Hmm, that didn\u2019t work',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
