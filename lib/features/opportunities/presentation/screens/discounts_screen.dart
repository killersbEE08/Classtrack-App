import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/resource_repository.dart';
import '../../domain/resource.dart';
import '../providers/opportunities_providers.dart';
import '../widgets/resource_card.dart';
import 'resource_detail_screen.dart';
import 'saved_opportunities_screen.dart';

/// Student Savings — the discounts surface. Same unified `resources` model as
/// Opportunities (type == discount), so it reuses [ResourceCard] and
/// [ResourceDetailScreen] (which already renders the discount banner, redemption
/// instructions, optional verification note and the external "Get deal" CTA).
///
/// Country targeting comes from the user's profile (PRD §10), never IP.
class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key});

  @override
  ConsumerState<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends ConsumerState<DiscountsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _category; // null = All

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
      appBar: AppBar(
        title: const Text('Student discounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Saved',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SavedOpportunitiesScreen())),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _messageState(
          theme,
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load discounts",
          body: 'Check your connection and try again.',
        ),
        data: (all) {
          final discounts = all
              .where((r) => r.type.isDiscount)
              .where((r) => r.isInActiveFeed)
              .where((r) => r.targetsCountry(country))
              .where((r) => !hidden.contains(r.id))
              .toList();

          if (discounts.isEmpty) {
            return _messageState(
              theme,
              icon: Icons.local_offer_rounded,
              title: 'No student deals yet',
              body: 'Exclusive student discounts are coming soon.',
            );
          }

          final categories = <String>{
            for (final d in discounts) ...d.categories
          }.toList()
            ..sort();

          var list = _category == null
              ? discounts
              : discounts
                  .where((d) => d.categories.contains(_category))
                  .toList();
          list = ResourceQueries.search(list, _query);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search deals',
                    prefixIcon: const Icon(Icons.search_rounded),
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
              if (categories.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                      ),
                      for (final c in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? _messageState(
                        theme,
                        icon: Icons.filter_alt_off_rounded,
                        title: 'No matches',
                        body: 'Try a different search or category.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          for (final r in list)
                            ResourceCard(resource: r, onTap: () => _open(r)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _messageState(ThemeData theme,
      {required IconData icon, required String title, required String body}) {
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
}
