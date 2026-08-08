import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/app_user.dart';
import '../../domain/profile_options.dart';
import '../providers/auth_providers.dart';

/// Settings → Edit profile.
///
/// Progressive profiling: every field is OPTIONAL. Students can fill in as much
/// or as little as they like; the data personalises Opportunities & Discounts
/// but the app works perfectly with an empty profile. Nothing here is forced at
/// sign-up.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _state;
  late final TextEditingController _city;
  late final TextEditingController _university;
  late final TextEditingController _college;
  late final TextEditingController _degree;
  late final TextEditingController _department;
  late final TextEditingController _academicYear;
  late final TextEditingController _semester;
  late final TextEditingController _graduationYear;

  String? _country;
  String? _careerGoal;
  final Set<String> _interests = {};

  bool _saving = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _state = TextEditingController();
    _city = TextEditingController();
    _university = TextEditingController();
    _college = TextEditingController();
    _degree = TextEditingController();
    _department = TextEditingController();
    _academicYear = TextEditingController();
    _semester = TextEditingController();
    _graduationYear = TextEditingController();
  }

  /// Seeds the form once from the loaded profile. Guarded by [_initialised] so
  /// later stream rebuilds never clobber the student's in-progress edits.
  void _seed(AppUser user) {
    if (_initialised) return;
    _initialised = true;
    _name.text = user.displayName ?? '';
    _state.text = user.stateRegion ?? '';
    _city.text = user.city ?? '';
    _university.text = user.university ?? '';
    _college.text = user.college ?? '';
    _degree.text = user.degree ?? '';
    _department.text = user.department ?? '';
    _academicYear.text = user.academicYear?.toString() ?? '';
    _semester.text = user.semester?.toString() ?? '';
    _graduationYear.text = user.graduationYear?.toString() ?? '';
    _country = user.country;
    _careerGoal = user.careerGoal;
    _interests
      ..clear()
      ..addAll(user.interests);
  }

  @override
  void dispose() {
    _name.dispose();
    _state.dispose();
    _city.dispose();
    _university.dispose();
    _college.dispose();
    _degree.dispose();
    _department.dispose();
    _academicYear.dispose();
    _semester.dispose();
    _graduationYear.dispose();
    super.dispose();
  }

  /// A text value → sanitized string, or [FieldValue.delete] when cleared, so a
  /// single merge-write both sets and removes fields.
  Object _text(String raw) {
    final clean = Validators.sanitizeText(raw, maxLength: 80);
    return clean.isEmpty ? FieldValue.delete() : clean;
  }

  /// An int text value → parsed int (clamped to [min]..[max]) or
  /// [FieldValue.delete] when empty/invalid.
  Object _int(String raw, {int min = 1, int max = 9999}) {
    final v = int.tryParse(raw.trim());
    if (v == null) return FieldValue.delete();
    return v.clamp(min, max);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _saving = true);

    final repo = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Display name also lives on the Firebase Auth user, so it goes through
      // its dedicated path (which updates both Auth + Firestore).
      final newName = Validators.sanitizeName(_name.text);
      if (newName.isNotEmpty) {
        await repo.updateDisplayName(uid, newName);
      }

      await repo.updateProfileDetails(uid, {
        'country':
            (_country == null || _country!.isEmpty) ? FieldValue.delete() : _country,
        'stateRegion': _text(_state.text),
        'city': _text(_city.text),
        'university': _text(_university.text),
        'college': _text(_college.text),
        'degree': _text(_degree.text),
        'department': _text(_department.text),
        'academicYear': _int(_academicYear.text, max: 12),
        'semester': _int(_semester.text, max: 20),
        'graduationYear': _int(_graduationYear.text, min: 1970, max: 2100),
        'careerGoal': (_careerGoal == null || _careerGoal!.isEmpty)
            ? FieldValue.delete()
            : _careerGoal,
        'interests': _interests.toList(),
      });

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile saved ✓')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save your profile. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile != null) _seed(profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _intro(theme),
            const SizedBox(height: 16),
            _section(theme, 'Account'),
            _card(
              theme,
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: InputBorder.none,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? null : Validators.name(v),
              ),
            ),
            const SizedBox(height: 16),
            _section(theme, 'Location'),
            _card(
              theme,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Country ⭐',
                      border: InputBorder.none,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Not set'),
                      ),
                      ...ProfileOptions.countries.map(
                        (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _country = v),
                  ),
                  const Divider(height: 1),
                  _field(_state, 'State / region'),
                  const Divider(height: 1),
                  _field(_city, 'City'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(theme, 'Education'),
            _card(
              theme,
              child: Column(
                children: [
                  _field(_university, 'University'),
                  const Divider(height: 1),
                  _field(_college, 'College'),
                  const Divider(height: 1),
                  _field(_degree, 'Degree (e.g. MBA, B.Tech)'),
                  const Divider(height: 1),
                  _field(_department, 'Department / branch'),
                  const Divider(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: _field(_academicYear, 'Year', number: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(_semester, 'Semester', number: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            _field(_graduationYear, 'Grad. year', number: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(theme, 'Career goal'),
            _card(
              theme,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final g in ProfileOptions.careerGoals)
                    ChoiceChip(
                      label: Text(g),
                      selected: _careerGoal == g,
                      onSelected: (sel) =>
                          setState(() => _careerGoal = sel ? g : null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(theme, 'Interests'),
            _card(
              theme,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final i in ProfileOptions.interests)
                    FilterChip(
                      label: Text(i),
                      selected: _interests.contains(i),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _interests.add(i);
                        } else {
                          _interests.remove(i);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(ThemeData theme) => Container(
        padding: const EdgeInsets.all(16),
        decoration: softCard(context),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'All optional. The more you share, the better we can match '
                'scholarships, internships and student deals to you.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label, {bool number = false}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters:
          number ? [FilteringTextInputFormatter.digitsOnly] : null,
      textCapitalization:
          number ? TextCapitalization.none : TextCapitalization.words,
      decoration: InputDecoration(labelText: label, border: InputBorder.none),
    );
  }

  Widget _section(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelMedium
              ?.copyWith(letterSpacing: 1.0, color: theme.hintColor),
        ),
      );

  Widget _card(ThemeData theme, {required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: softCard(context),
        child: child,
      );
}
