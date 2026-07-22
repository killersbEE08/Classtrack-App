import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:classtrack/core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../domain/parsed_schedule.dart';
import '../providers/import_providers.dart';
import 'review_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _loading = false;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _fail(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<ParsedSchedule> Function() task) async {
    final repo = ref.read(importRepositoryProvider);
    if (repo == null) {
      _fail('Please sign in first.');
      return;
    }
    if (!repo.isConfigured) {
      _fail('The AI assistant isn’t available right now. Please try again later.');
      return;
    }
    // AI photo/PDF/text import is a Pro feature. Free users can still build a
    // timetable manually or via the chat assistant's monthly free messages.
    if (!ref.read(isProProvider)) {
      final becamePro = await showPaywall(context);
      if (!becamePro || !mounted) return;
    }
    setState(() => _loading = true);
    try {
      final result = await task();
      if (!mounted) return;
      if (result.isEmpty) {
        _fail('Couldn’t find any classes. Try a clearer image or paste text.');
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReviewScreen(schedule: result)),
      );
    } catch (e) {
      _fail('Import failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _run(() => ref.read(importRepositoryProvider)!.parseImage(bytes));
  }

  Future<void> _parseText() async {
    if (_text.text.trim().length < 6) {
      _fail('Paste a bit more of your timetable first.');
      return;
    }
    await _run(() => ref.read(importRepositoryProvider)!.parseText(_text.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI schedule import')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                      color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload a timetable photo or paste text. You’ll review everything before it’s saved.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _option(
              icon: PhosphorIcons.camera(),
              title: 'Take a photo',
              subtitle: 'Snap your printed timetable',
              onTap: () => _pickImage(ImageSource.camera),
            ),
            _option(
              icon: PhosphorIcons.image(),
              title: 'Choose from gallery',
              subtitle: 'A screenshot or saved image',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 24),
            Text('Or paste text', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText:
                    'Mon 9-10 DBMS Room 204\nMon 10-11 OS Lab 3\nWed 9-10 DBMS Room 204 ...',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _parseText,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Parse text'),
            ),
            if (_loading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Center(
                child: Text('Reading your schedule with AI…',
                    style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
