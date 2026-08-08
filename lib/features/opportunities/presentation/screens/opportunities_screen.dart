import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/edit_profile_screen.dart';
import '../../data/resource_repository.dart';
import '../../domain/resource.dart';
import '../../domain/resource_type.dart';
import '../providers/opportunities_providers.dart';
import '../widgets/resource_card.dart';
import 'discounts_screen.dart';
import 'resource_detail_screen.dart';
import 'saved_opportunities_screen.dart';

/// The Opportunities destination: a live feed of scholarships, internships,
/// competitions, etc. (discounts have their own surface). Search + category
/// chips + a filter sheet sit on top of the unified `resources` collection.
class OpportunitiesScreen extends ConsumerStatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  ConsumerState<OpportunitiesScreen> createState() =>
      _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends ConsumerState<OpportunitiesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ResourceType? _type; // null = All
  bool _remoteOnly = false;
  bool _paidOnly = false;
  bool _verifiedOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _open(Resource r) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResourceDetailScreen(resource: r)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(visibleResourcesProvider);
    final country = ref.watch(userProfileProvider).valueOrNull?.country;
    final hidden = ref.watch(hiddenResourceIdsProvider).valueOrNull ?? const {};

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Opportunities',
                        style: theme.textTheme.displaySmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.local_offer_outlined),
                    tooltip: 'Student discounts',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const DiscountsScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_border_rounded),
                    tooltip: 'Saved',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SavedOpportunitiesScreen())),
                  ),
                  _FilterButton(
                    active: _remoteOnly || _paidOnly || _verifiedOnly,
                    onTap: _openFilters,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search opportunities',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _messageState(
                  theme,
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load opportunities",
                  body: 'Check your connection and try again.',
                ),
                data: (all) {
                  final opportunities = all
                      .where((r) => !r.type.isDiscount)
                      .where((r) => r.isInActiveFeed)
                      .where((r) => r.targetsCountry(country))
                      .where((r) => !hidden.contains(r.id))
                      .toList();

                  if (opportunities.isEmpty) {
                    return _emptyContentState(theme);
                  }

                  final types = <ResourceType>{
                    for (final r in opportunities) r.type
                  }.toList()
                    ..sort((a, b) => a.label.compareTo(b.label));

                  var list = _type == null
                      ? opportunities
                      : opportunities.where((r) => r.type == _type).toList();
                  list = ResourceQueries.search(list, _query);
                  if (_remoteOnly) {
                    list = list.where((r) => r.remote == true).toList();
                  }
                  if (_paidOnly) {
                    list = list.where((r) => r.paid == true).toList();
                  }
                  if (_verifiedOnly) {
                    list = list.where((r) => r.verified).toList();
                  }

                  return Column(
                    children: [
                      _CategoryChips(
                        types: types,
                        selected: _type,
                        onSelect: (t) => setState(() => _type = t),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? _messageState(
                                theme,
                                icon: Icons.filter_alt_off_rounded,
                                title: 'No matches',
                                body: 'Try clearing search or filters.',
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 120),
                                children: [
                                  for (final r in list)
                                    ResourceCard(
                                        resource: r, onTap: () => _open(r)),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageState(ThemeData theme,
      {required IconData icon,
      required String title,
      required String body}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _emptyContentState(ThemeData theme) {
    final hasProfile =
        ref.watch(userProfileProvider).valueOrNull?.hasAnyProfileDetails ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: softCard(context),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text('New opportunities are on the way',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                hasProfile
                    ? "We're curating scholarships, internships and deals matched to you. Check back soon."
                    : 'Add your country, degree & interests so we can match the best opportunities to you.',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center,
              ),
              if (!hasProfile) ...[
                const SizedBox(height: 16),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EditProfileScreen())),
                  child: const Text('Complete your profile'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final theme = Theme.of(ctx);
            void toggle(void Function() f) {
              setSheet(f);
              setState(f);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remote only'),
                      value: _remoteOnly,
                      onChanged: (v) => toggle(() => _remoteOnly = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paid only'),
                      value: _paidOnly,
                      onChanged: (v) => toggle(() => _paidOnly = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Verified only'),
                      value: _verifiedOnly,
                      onChanged: (v) => toggle(() => _verifiedOnly = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => toggle(() {
                            _remoteOnly = false;
                            _paidOnly = false;
                            _verifiedOnly = false;
                          }),
                          child: const Text('Clear all'),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Filters',
          onPressed: onTap,
        ),
        if (active)
          const Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
          ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<ResourceType> types;
  final ResourceType? selected;
  final ValueChanged<ResourceType?> onSelect;
  const _CategoryChips({
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t.label),
                avatar: Icon(t.icon, size: 16, color: t.color),
                selected: selected == t,
                onSelected: (_) => onSelect(t),
              ),
            ),
        ],
      ),
    );
  }
}
