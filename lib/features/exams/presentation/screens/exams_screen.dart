import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../domain/exam.dart';
import '../providers/exam_providers.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  Color _urgencyColor(int days) {
    if (days <= 1) return AppColors.danger;
    if (days <= 3) return AppColors.warning;
    if (days <= 7) return AppColors.accent;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final upcoming = ref.watch(upcomingExamsProvider);
    final past = ref.watch(pastExamsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _AddButton(onTap: () => _openEditor(context)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Exams',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Countdowns so nothing sneaks up on you',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 18),
            if (upcoming.isEmpty && past.isEmpty)
              _empty(context)
            else ...[
              if (upcoming.isNotEmpty) ...[
                Text('Upcoming', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (var i = 0; i < upcoming.length; i++)
                  _examCard(context, ref, upcoming[i])
                      .animate()
                      .fadeIn(delay: (i * 60).ms, duration: 320.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOutCubic),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Past', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final e in past) _examCard(context, ref, e, past: true),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: softCard(context),
      child: Column(
        children: [
          const Icon(Icons.event_note_rounded,
              size: 42, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('No exams yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Add your tests to see live countdowns and stay prepared.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add exam'),
          ),
        ],
      ),
    );
  }

  Widget _examCard(BuildContext context, WidgetRef ref, Exam e,
      {bool past = false}) {
    final theme = Theme.of(context);
    final byId = ref.watch(subjectsByIdProvider);
    final subject = e.subjectId != null ? byId[e.subjectId] : null;
    final accent = past ? AppColors.cancelled : _urgencyColor(e.daysUntil);
    final timeLabel = TimeOfDay.fromDateTime(e.date).format(context);

    return Opacity(
      opacity: past ? 0.7 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: softCard(context),
        child: InkWell(
          onTap: () => _openEditor(context, exam: e),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      past
                          ? '✓'
                          : (e.daysUntil == 0 ? 'Today' : '${e.daysUntil}'),
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          height: 1),
                    ),
                    if (!past && e.daysUntil > 0)
                      Text(e.daysUntil == 1 ? 'day' : 'days',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: accent, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 12, color: theme.hintColor),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${DateUtilsX.prettyDate(e.date)} · $timeLabel',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (subject != null || (e.room?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (subject != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: Color(subject.colorHex),
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(subject.name,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          if (e.room?.isNotEmpty ?? false) ...[
                            if (subject != null) const SizedBox(width: 8),
                            Icon(Icons.meeting_room_rounded,
                                size: 12, color: theme.hintColor),
                            const SizedBox(width: 4),
                            Text(e.room!, style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {Exam? exam}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExamEditorSheet(initial: exam),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_rounded, size: 20, color: Colors.white),
              SizedBox(width: 6),
              Text('Add exam',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamEditorSheet extends ConsumerStatefulWidget {
  final Exam? initial;
  final DateTime? initialDate;
  const ExamEditorSheet({super.key, this.initial, this.initialDate});

  @override
  ConsumerState<ExamEditorSheet> createState() => _ExamEditorSheetState();
}

class _ExamEditorSheetState extends ConsumerState<ExamEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _room;
  late final TextEditingController _note;
  String? _subjectId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _room = TextEditingController(text: e?.room ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _subjectId = e?.subjectId;
    final initDate = widget.initialDate;
    _date = e?.date ??
        (initDate != null
            ? DateTime(initDate.year, initDate.month, initDate.day, 9, 0)
            : DateTime.now().add(const Duration(days: 1)).copyWith(
                hour: 9, minute: 0, second: 0, millisecond: 0, microsecond: 0));
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day,
          _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          _date.year, _date.month, _date.day, picked.hour, picked.minute));
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the exam a title.')));
      return;
    }
    final ctrl = ref.read(examControllerProvider);
    final room = _room.text.trim();
    final note = _note.text.trim();
    if (widget.initial == null) {
      ctrl.add(Exam(
        id: 'new',
        title: title,
        subjectId: _subjectId,
        date: _date,
        room: room.isEmpty ? null : room,
        note: note.isEmpty ? null : note,
      ));
    } else {
      ctrl.update(widget.initial!.copyWith(
        title: title,
        subjectId: _subjectId,
        clearSubject: _subjectId == null,
        date: _date,
        room: room.isEmpty ? null : room,
        clearRoom: room.isEmpty,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(widget.initial == null ? 'Add exam' : 'Edit exam',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Exam title'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: DateUtilsX.prettyDate(_date),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.schedule_rounded,
                    label: TimeOfDay.fromDateTime(_date).format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No subject')),
                for (final s in subjects)
                  DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text(s.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _room,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Room (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Topics / syllabus (optional)'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.initial != null)
                  IconButton(
                    onPressed: () {
                      ref
                          .read(examControllerProvider)
                          .delete(widget.initial!.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                  ),
                Expanded(
                  child: FilledButton(
                      onPressed: _save, child: const Text('Save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.hintColor),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
