import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../opportunities/domain/resource.dart';
import '../../../opportunities/domain/resource_status.dart';
import '../../../opportunities/domain/resource_type.dart';
import '../../data/cms_resource_repository.dart';
import '../providers/cms_resource_providers.dart';

/// Create / edit a [Resource]. Reuses the shared model + [ResourceType]/
/// [ResourceStatus]; writes go through [CmsResourceRepository] (which stamps
/// `updatedBy` and enforces publish validation, mirrored by Firestore rules).
class CmsResourceEditorScreen extends ConsumerStatefulWidget {
  final Resource? existing;
  const CmsResourceEditorScreen({super.key, this.existing});

  @override
  ConsumerState<CmsResourceEditorScreen> createState() =>
      _CmsResourceEditorScreenState();
}

class _CmsResourceEditorScreenState
    extends ConsumerState<CmsResourceEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final Map<String, TextEditingController> _c;
  ResourceType _type = ResourceType.scholarship;
  ResourceStatus _status = ResourceStatus.draft;
  DateTime? _startDate;
  DateTime? _deadline;
  bool _featured = false;
  bool _sponsored = false;
  bool _verified = false;
  bool _remote = false;
  bool _paid = false;
  bool _verificationRequired = false;
  bool _saving = false;

  Resource? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final r = existing;
    _c = {
      for (final k in [
        'title',
        'organization',
        'description',
        'countries',
        'eligibility',
        'applicationUrl',
        'affiliateUrl',
        'imageUrl',
        'logoUrl',
        'tags',
        'categories',
        'priority',
        'slug',
        'company',
        'discountText',
        'redemptionInstructions',
        'terms',
        'degrees',
        'departments',
        'interests',
        'careerGoals',
        'years',
      ])
        k: TextEditingController(),
    };
    if (r != null) {
      _type = r.type;
      _status = r.status;
      _startDate = r.startDate;
      _deadline = r.deadline;
      _featured = r.featured;
      _sponsored = r.sponsored;
      _verified = r.verified;
      _remote = r.remote ?? false;
      _paid = r.paid ?? false;
      _verificationRequired = r.verificationRequired;
      _c['title']!.text = r.title;
      _c['organization']!.text = r.organization;
      _c['description']!.text = r.description;
      _c['countries']!.text = r.countries.join(', ');
      _c['eligibility']!.text = r.eligibility ?? '';
      _c['applicationUrl']!.text = r.applicationUrl ?? '';
      _c['affiliateUrl']!.text = r.affiliateUrl ?? '';
      _c['imageUrl']!.text = r.imageUrl ?? '';
      _c['logoUrl']!.text = r.logoUrl ?? '';
      _c['tags']!.text = r.tags.join(', ');
      _c['categories']!.text = r.categories.join(', ');
      _c['priority']!.text = r.priority.toString();
      _c['slug']!.text = r.slug ?? '';
      _c['company']!.text = r.company ?? '';
      _c['discountText']!.text = r.discountText ?? '';
      _c['redemptionInstructions']!.text = r.redemptionInstructions ?? '';
      _c['terms']!.text = r.terms ?? '';
      _c['degrees']!.text = r.targetDegrees.join(', ');
      _c['departments']!.text = r.targetDepartments.join(', ');
      _c['interests']!.text = r.targetInterests.join(', ');
      _c['careerGoals']!.text = r.targetCareerGoals.join(', ');
      _c['years']!.text = r.targetAcademicYears.join(', ');
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _list(String s) => s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<int> _intList(String s) => s
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();

  String? _nullIf(String s) => s.trim().isEmpty ? null : s.trim();

  Resource _build() {
    return Resource(
      id: existing?.id ?? '',
      type: _type,
      title: _c['title']!.text.trim(),
      organization: _c['organization']!.text.trim(),
      description: _c['description']!.text.trim(),
      countries: _list(_c['countries']!.text),
      eligibility: _nullIf(_c['eligibility']!.text),
      startDate: _startDate,
      deadline: _deadline,
      applicationUrl: _nullIf(_c['applicationUrl']!.text),
      affiliateUrl: _nullIf(_c['affiliateUrl']!.text),
      imageUrl: _nullIf(_c['imageUrl']!.text),
      logoUrl: _nullIf(_c['logoUrl']!.text),
      tags: _list(_c['tags']!.text),
      categories: _list(_c['categories']!.text),
      status: _status,
      featured: _featured,
      sponsored: _sponsored,
      verified: _verified,
      remote: _remote,
      paid: _paid,
      verificationRequired: _verificationRequired,
      priority: int.tryParse(_c['priority']!.text.trim()) ?? 0,
      slug: _nullIf(_c['slug']!.text),
      company: _nullIf(_c['company']!.text),
      discountText: _nullIf(_c['discountText']!.text),
      redemptionInstructions: _nullIf(_c['redemptionInstructions']!.text),
      terms: _nullIf(_c['terms']!.text),
      targetDegrees: _list(_c['degrees']!.text),
      targetDepartments: _list(_c['departments']!.text),
      targetInterests: _list(_c['interests']!.text),
      targetCareerGoals: _list(_c['careerGoals']!.text),
      targetAcademicYears: _intList(_c['years']!.text),
      createdAt: existing?.createdAt,
      publishedAt: existing?.publishedAt,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(cmsResourceRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Pre-validate publish so the editor gives friendly, inline feedback.
    final r = _build();
    if (_status.isVisibleToStudents) {
      final v = CmsResourceRepository.validateForPublish(r);
      if (!v.ok) {
        messenger.showSnackBar(SnackBar(
          content: Text('Cannot publish: ${v.errors.join(' ')}'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (existing == null || existing!.id.isEmpty) {
        await repo.create(r);
      } else {
        await repo.update(r);
      }
      messenger.showSnackBar(const SnackBar(content: Text('Saved ✓')));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e is ArgumentError
            ? e.message.toString()
            : 'Could not save: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDiscount = _type.isDiscount;

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New resource' : 'Edit resource'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _sectionTitle(theme, 'Basics'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ResourceType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: [
                          for (final t in ResourceType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (t) =>
                            setState(() => _type = t ?? _type),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<ResourceStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final s in ResourceStatus.values)
                            DropdownMenuItem(value: s, child: Text(s.label)),
                        ],
                        onChanged: (s) =>
                            setState(() => _status = s ?? _status),
                      ),
                    ),
                  ],
                ),
                _field('title', 'Title', required: true),
                _field('organization',
                    isDiscount ? 'Organization' : 'Organization'),
                _field('description', 'Description', maxLines: 4),
                const SizedBox(height: 20),
                _sectionTitle(theme, 'Links & media'),
                _field('applicationUrl', 'Application URL'),
                if (isDiscount) _field('affiliateUrl', 'Affiliate / deal URL'),
                _field('imageUrl', 'Image URL'),
                _field('logoUrl', 'Logo URL'),
                _field('slug', 'SEO slug (optional)'),
                const SizedBox(height: 20),
                _sectionTitle(theme, 'Dates & priority'),
                Row(
                  children: [
                    Expanded(
                        child: _dateField('Start date', _startDate,
                            (d) => setState(() => _startDate = d))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _dateField('Deadline', _deadline,
                            (d) => setState(() => _deadline = d))),
                  ],
                ),
                _field('priority', 'Priority (higher shows first)',
                    number: true),
                const SizedBox(height: 20),
                _sectionTitle(theme, 'Targeting'),
                _field('countries', 'Countries (comma-separated; "Global" = all)'),
                _field('degrees', 'Target degrees (comma-separated)'),
                _field('departments', 'Target departments (comma-separated)'),
                _field('interests', 'Target interests (comma-separated)'),
                _field('careerGoals', 'Target career goals (comma-separated)'),
                _field('years', 'Target academic years (e.g. 1, 2, 3)'),
                _field('tags', 'Tags (comma-separated)'),
                const SizedBox(height: 20),
                _sectionTitle(theme, 'Flags'),
                Wrap(
                  spacing: 16,
                  children: [
                    _switch('Featured', _featured,
                        (v) => setState(() => _featured = v)),
                    _switch('Sponsored', _sponsored,
                        (v) => setState(() => _sponsored = v)),
                    _switch('Verified', _verified,
                        (v) => setState(() => _verified = v)),
                    _switch('Remote', _remote,
                        (v) => setState(() => _remote = v)),
                    _switch('Paid', _paid, (v) => setState(() => _paid = v)),
                  ],
                ),
                if (isDiscount) ...[
                  const SizedBox(height: 20),
                  _sectionTitle(theme, 'Discount details'),
                  _field('company', 'Company / brand'),
                  _field('discountText', 'Discount headline (e.g. "50% off")'),
                  _field('redemptionInstructions', 'How to redeem',
                      maxLines: 3),
                  _field('terms', 'Terms', maxLines: 3),
                  _switch('Verification required (partner-handled)',
                      _verificationRequired,
                      (v) => setState(() => _verificationRequired = v)),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _field(String key, String label,
      {bool required = false, bool number = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[key],
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> set) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) set(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_rounded, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => set(null),
                ),
        ),
        child: Text(value == null
            ? 'Not set'
            : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 260,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
