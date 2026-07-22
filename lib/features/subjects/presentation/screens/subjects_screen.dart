import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classtrack/core/theme/app_icons.dart';
import 'package:classtrack/core/theme/subject_icons.dart';

import '../../../../shared/widgets/states.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../domain/subject.dart';
import '../providers/subject_providers.dart';
import 'edit_subject_screen.dart';
import 'subject_detail_screen.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  void _openEditor(BuildContext context, {Subject? subject}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditSubjectScreen(subject: subject)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Subject'),
      ),
      body: subjectsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(subjectsStreamProvider),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return EmptyState(
              icon: PhosphorIcons.books(),
              title: 'No subjects yet',
              message:
                  'Add your first subject to start tracking attendance and classes.',
              actionLabel: 'Add subject',
              onAction: () => _openEditor(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final subject = subjects[i];
              return _SubjectCard(subject: subject)
                  .animate()
                  .fadeIn(delay: (i * 40).ms)
                  .slideY(begin: 0.08, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(subjectStatsProvider(subject.id));
    final color = Color(subject.colorHex);
    final pct = stats.held == 0 ? null : stats.percent;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubjectDetailScreen(subjectId: subject.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(SubjectIcons.resolve(subject.iconKey),
                    color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      subject.professor?.isNotEmpty == true
                          ? subject.professor!
                          : 'Tap to view details',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MiniPercent(percent: pct),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPercent extends StatelessWidget {
  final double? percent;
  const _MiniPercent({this.percent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (percent == null) {
      return Text('—',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.textTheme.bodySmall?.color));
    }
    final color = percent! >= 75
        ? const Color(0xFF16A34A)
        : percent! >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${percent!.toStringAsFixed(0)}%',
            style: theme.textTheme.titleLarge?.copyWith(color: color)),
        Text('attendance', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
