import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/subscription_service.dart';
import '../../domain/pro_constants.dart';
import '../../domain/pro_features.dart';
import '../providers/subscription_providers.dart';

/// Opens the ClassTrack Pro paywall. Returns true if the user became Pro.
Future<bool> showPaywall(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
        builder: (_) => const PaywallScreen(), fullscreenDialog: true),
  );
  return result ?? false;
}

/// Outcome-led value statements — what Pro actually *does for you*, not a
/// feature dump. Kept short and benefit-first for conversion.
class _Outcome {
  final IconData icon;
  final String text;
  const _Outcome(this.icon, this.text);
}

const List<_Outcome> _outcomes = [
  _Outcome(Icons.bolt_rounded,
      'Turn a photo or PDF of your timetable into a ready schedule in seconds.'),
  _Outcome(Icons.shield_moon_rounded,
      'See exactly how many classes you can safely skip — no more guessing.'),
  _Outcome(Icons.wb_sunny_rounded,
      'Start each day with one clear plan of classes, deadlines and exams.'),
  _Outcome(Icons.auto_awesome_rounded,
      'Ask the AI assistant anything, anytime — with no monthly limit.'),
];

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _packages = const [];
  Package? _selected;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(subscriptionServiceProvider);
    final packages = await service.fetchPackages();
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _selected = packages.isNotEmpty ? _preferAnnual(packages) : null;
      _loading = false;
    });
  }

  Package _preferAnnual(List<Package> packages) => packages.firstWhere(
        (p) => p.packageType == PackageType.annual,
        orElse: () => packages.first,
      );

  Future<void> _buy() async {
    final selected = _selected;
    if (selected == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok =
          await ref.read(subscriptionServiceProvider).purchase(selected);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _busy = false); // user cancelled
      }
    } on SubscriptionException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(subscriptionServiceProvider).restore();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'No previous purchases found for this account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClassTrack Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _hero(theme),
            const SizedBox(height: 14),
            _trustStrip(theme),
            const SizedBox(height: 22),

            // Benefit-led outcomes — the reason to upgrade.
            Text('What you get with Pro',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ..._outcomes.map((o) => _outcomeRow(theme, o)),
            const SizedBox(height: 22),

            // Plans first so pricing is front-and-centre once convinced.
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!ProConstants.enabled)
              _notice(theme,
                  'Subscriptions aren\'t set up yet. Add your RevenueCat key and store products to enable Pro.')
            else if (_packages.isEmpty)
              _notice(theme,
                  'No plans available right now. Please check back shortly.')
            else ...[
              Text('Choose your plan',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ..._packages.map(_planTile),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.danger)),
            ],

            const SizedBox(height: 18),
            FilledButton(
              onPressed: (_selected == null || _busy || !ProConstants.enabled)
                  ? null
                  : _buy,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_ctaLabel(),
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w800)),
            ),
            if (_ctaSubcaption() != null) ...[
              const SizedBox(height: 10),
              Text(_ctaSubcaption()!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],

            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: const Text('Restore purchases'),
            ),

            // Everything included — reassurance for the detail-oriented,
            // placed after the CTA so it never blocks the decision.
            const SizedBox(height: 8),
            _everythingIncluded(theme),

            const SizedBox(height: 14),
            Text(
              'Subscriptions renew automatically until cancelled. Manage or '
              'cancel anytime in your store account settings.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  // --- Hero -----------------------------------------------------------------

  Widget _hero(ThemeData theme) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('CLASSTRACK PRO',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Stay on top of every class — effortlessly.',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15)),
            const SizedBox(height: 8),
            Text(
                'Let AI, insights and smart reminders do the heavy lifting so '
                'you never miss a class, deadline or safe skip.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
          ],
        ),
      );

  // --- Trust / risk-reversal strip -----------------------------------------

  Widget _trustStrip(ThemeData theme) {
    Widget item(IconData icon, String label) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Row(
      children: [
        item(Icons.lock_outline_rounded, 'Secure\ncheckout'),
        item(Icons.event_available_rounded, 'Cancel\nanytime'),
        item(Icons.flash_on_rounded, 'Instant\nunlock'),
      ],
    );
  }

  // --- Outcomes -------------------------------------------------------------

  Widget _outcomeRow(ThemeData theme, _Outcome o) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(o.icon, color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(o.text,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
              ),
            ),
          ],
        ),
      );

  // --- Everything included (full feature list, collapsed after CTA) --------

  Widget _everythingIncluded(ThemeData theme) => Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          title: Text('See everything included',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          children: [
            for (final f in ProFeatures.all)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                          Text(f.subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  // --- Plans ----------------------------------------------------------------

  Widget _planTile(Package package) {
    final theme = Theme.of(context);
    final selected = identical(package, _selected) ||
        package.identifier == _selected?.identifier;
    final product = package.storeProduct;
    final popular =
        package.packageType == PackageType.annual && _packages.length > 1;
    final savings = _badgeFor(package);
    final perMonth = _perMonthLabel(package);
    final trial = _freeTrialLabel(product);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _selected = package),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (popular
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : theme.dividerColor),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : theme.cardColor,
          ),
          child: Column(
            children: [
              if (popular)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: AppColors.primary,
                  child: Text('MOST POPULAR',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? AppColors.primary : theme.hintColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(_periodLabel(package.packageType),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                              ),
                              if (trial != null) ...[
                                const SizedBox(width: 8),
                                _pill('FREE TRIAL', AppColors.success, theme),
                              ] else if (savings != null) ...[
                                const SizedBox(width: 8),
                                _pill(savings, AppColors.success, theme),
                              ],
                            ],
                          ),
                          if (_planSubtitle(package, trial, perMonth) !=
                              null) ...[
                            const SizedBox(height: 2),
                            Text(_planSubtitle(package, trial, perMonth)!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color)),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Localized, store-provided price — never hardcoded.
                        Text(product.priceString,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(_perPeriodWord(package.packageType),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color, ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      );

  /// Subtitle that anchors value: trial terms, per-month equivalent for annual,
  /// or a plain billing cadence.
  String? _planSubtitle(Package package, String? trial, String? perMonth) {
    final product = package.storeProduct;
    if (trial != null) {
      return '$trial, then ${product.priceString} ${_perPeriodWord(package.packageType)}';
    }
    if (perMonth != null) {
      return 'Just $perMonth · billed yearly';
    }
    if (package.packageType == PackageType.lifetime) {
      return 'One-time payment — yours forever';
    }
    if (product.description.isNotEmpty) return product.description;
    return null;
  }

  // --- CTA copy -------------------------------------------------------------

  String _ctaLabel() {
    final p = _selected;
    if (p == null) return 'Continue';
    if (_freeTrialLabel(p.storeProduct) != null) return 'Start my free trial';
    if (p.packageType == PackageType.lifetime) return 'Unlock Pro forever';
    return 'Unlock ClassTrack Pro';
  }

  String? _ctaSubcaption() {
    final p = _selected;
    if (p == null || !ProConstants.enabled) return null;
    final product = p.storeProduct;
    final trial = _freeTrialLabel(product);
    if (trial != null) {
      return 'Free for your $trial, then ${product.priceString} ${_perPeriodWord(p.packageType)}. Cancel anytime.';
    }
    if (p.packageType == PackageType.lifetime) {
      return '${product.priceString} once. No subscription, yours forever.';
    }
    return '${product.priceString} ${_perPeriodWord(p.packageType)} · cancel anytime.';
  }

  // --- Pricing helpers ------------------------------------------------------

  /// A short marketing badge: savings % on the annual plan (vs 12× monthly),
  /// or "BEST VALUE"/"BEST DEAL" when a percentage can't be computed.
  String? _badgeFor(Package package) {
    if (package.packageType == PackageType.lifetime) return 'BEST DEAL';
    if (package.packageType != PackageType.annual) return null;
    Package? monthly;
    for (final p in _packages) {
      if (p.packageType == PackageType.monthly) {
        monthly = p;
        break;
      }
    }
    if (monthly == null) return 'BEST VALUE';
    final yearIfMonthly = monthly.storeProduct.price * 12;
    if (yearIfMonthly <= 0) return 'BEST VALUE';
    final pct = (1 - package.storeProduct.price / yearIfMonthly) * 100;
    return pct >= 1 ? 'SAVE ${pct.round()}%' : 'BEST VALUE';
  }

  /// Per-month equivalent for an annual plan (localized). Null otherwise.
  String? _perMonthLabel(Package package) {
    final product = package.storeProduct;
    if (package.packageType != PackageType.annual || product.price <= 0) {
      return null;
    }
    try {
      final formatter = NumberFormat.simpleCurrency(name: product.currencyCode);
      return '${formatter.format(product.price / 12)}/mo';
    } catch (_) {
      return null;
    }
  }

  /// A human-readable free-trial label (e.g. "7-day free trial") when the
  /// selected product has a zero-cost introductory offer.
  String? _freeTrialLabel(StoreProduct product) {
    final intro = product.introductoryPrice;
    if (intro == null || intro.price > 0) return null;
    final n = intro.periodNumberOfUnits <= 0 ? 1 : intro.periodNumberOfUnits;
    final unit = switch (intro.periodUnit) {
      PeriodUnit.day => 'day',
      PeriodUnit.week => 'week',
      PeriodUnit.month => 'month',
      PeriodUnit.year => 'year',
      PeriodUnit.unknown => 'day',
    };
    return '$n-$unit free trial';
  }

  String _perPeriodWord(PackageType type) => switch (type) {
        PackageType.annual => 'per year',
        PackageType.sixMonth => 'per 6 months',
        PackageType.threeMonth => 'per 3 months',
        PackageType.twoMonth => 'per 2 months',
        PackageType.monthly => 'per month',
        PackageType.weekly => 'per week',
        PackageType.lifetime => 'one-time',
        _ => '',
      };

  String _periodLabel(PackageType type) => switch (type) {
        PackageType.annual => 'Yearly',
        PackageType.sixMonth => '6 months',
        PackageType.threeMonth => '3 months',
        PackageType.twoMonth => '2 months',
        PackageType.monthly => 'Monthly',
        PackageType.weekly => 'Weekly',
        PackageType.lifetime => 'Lifetime',
        _ => 'Plan',
      };

  Widget _notice(ThemeData theme, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: theme.textTheme.bodySmall),
      );
}
