import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../domain/parsed_schedule.dart';
import '../providers/import_providers.dart';

/// Editable review of the Gemini-parsed schedule. Nothing is written to
/// Firestore until the user taps "Add to ClassTrack".
class ReviewScreen extends ConsumerStatefulWidget {
  final ParsedSchedule schedule;
  const ReviewScreen({super.key, required this.schedule});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late ParsedSchedule _schedule;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
  }

  Color _confidenceColor() => switch (_schedule.confidence) {
        'high' => AppColors.success,
        'medium' => AppColors.warning,
        _ => AppColors.danger,
      };

  Future<void> _commit() async {
    final repo = ref.read(importRepositoryProvider);
    if (repo == null) return;
    setState(() => _saving = true);
    try {
      final count = await repo.commit(_schedule);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $count subject(s) to ClassTrack.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSession(ParsedSubject subject, ParsedSession session) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SessionEditor(
        session: session,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _pickStart(ParsedSubject subject) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: subject.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2031),
    );
    if (picked != null) {
      setState(() {
        subject.startDate = picked;
        if (subject.endDate != null && subject.endDate!.isBefore(picked)) {
          subject.endDate = null;
        }
      });
    }
  }

  Future<void> _pickEnd(ParsedSubject subject) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: subject.endDate ??
          (subject.startDate ?? DateTime.now()).add(const Duration(days: 120)),
      firstDate: subject.startDate ?? DateTime(2020),
      lastDate: DateTime(2032),
    );
    if (picked != null) setState(() => subject.endDate = picked);
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.event_rounded),
        ),
        child: Text(date == null ? 'Not set' : DateUtilsX.prettyDate(date)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Review & confirm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _confidenceColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, color: _confidenceColor()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI confidence: ${_schedule.confidence.toUpperCase()}. '
                    'Please double-check times and rooms before saving.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._schedule.subjects.asMap().entries.map((entry) {
            final subject = entry.value;
            return _subjectCard(theme, subject, entry.key);
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LoadingButton(
            label: 'Add to ClassTrack',
            loading: _saving,
            icon: Icons.check_rounded,
            onPressed: _commit,
          ),
        ),
      ),
    );
  }

  Widget _subjectCard(ThemeData theme, ParsedSubject subject, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: subject.include,
                  onChanged: (v) =>
                      setState(() => subject.include = v ?? true),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: subject.name,
                    style: theme.textTheme.titleMedium,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Subject name',
                    ),
                    onChanged: (v) => subject.name = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  onPressed: () =>
                      setState(() => _schedule.subjects.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: subject.professor ?? '',
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Professor (optional)',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              onChanged: (v) => subject.professor = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: subject.classLink ?? '',
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Class link (Zoom / Meet / Teams)',
                prefixIcon: Icon(Icons.videocam_outlined),
              ),
              onChanged: (v) => subject.classLink = v,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _dateTile(
                    'Term start',
                    subject.startDate,
                    () => _pickStart(subject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateTile(
                    'Term end',
                    subject.endDate,
                    () => _pickEnd(subject),
                  ),
                ),
              ],
            ),
            if (subject.startDate != null || subject.endDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    subject.startDate = null;
                    subject.endDate = null;
                  }),
                  child: const Text('Clear dates'),
                ),
              ),
            const SizedBox(height: 10),
            ...subject.sessions.asMap().entries.map((e) {
              final session = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.schedule_rounded, size: 20),
                title: Text(
                    '${session.day}  ·  ${session.start}–${session.end}'),
                subtitle: session.room != null && session.room!.isNotEmpty
                    ? Text('Room ${session.room}')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editSession(subject, session),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () =>
                          setState(() => subject.sessions.removeAt(e.key)),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => subject.sessions.add(
                    ParsedSession(day: 'Monday', start: '09:00', end: '10:00'),
                  )),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add session'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionEditor extends StatefulWidget {
  final ParsedSession session;
  final VoidCallback onChanged;
  const _SessionEditor({required this.session, required this.onChanged});

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _room;
  late String _day;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.session.start);
    _end = TextEditingController(text: widget.session.end);
    _room = TextEditingController(text: widget.session.room ?? '');
    _day = widget.session.day;
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit session', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: Weekdays.full.contains(_day) ? _day : 'Monday',
            decoration: const InputDecoration(labelText: 'Day'),
            items: Weekdays.full
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _day = v ?? 'Monday'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  decoration: const InputDecoration(
                      labelText: 'Start (HH:MM)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _end,
                  decoration:
                      const InputDecoration(labelText: 'End (HH:MM)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _room,
            decoration: const InputDecoration(labelText: 'Room (optional)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              widget.session
                ..day = _day
                ..start = _start.text.trim()
                ..end = _end.text.trim()
                ..room = _room.text.trim().isEmpty ? null : _room.text.trim();
              widget.onChanged();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
