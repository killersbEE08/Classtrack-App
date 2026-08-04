import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/subscription_service.dart';

/// The app-wide subscription service. Overridden in main() with the instance
/// that was configured at startup (see main.dart).
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive Pro entitlement state. Seeds from the service's current value and
/// updates live whenever RevenueCat reports an entitlement change (purchase,
/// restore, expiry, refund).
class ProStatusController extends StateNotifier<bool> {
  ProStatusController(this._service) : super(_service.isProNow) {
    _sub = _service.isProStream.listen((value) {
      if (mounted) state = value;
    });
  }

  final SubscriptionService _service;
  late final dynamic _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final proStatusProvider =
    StateNotifierProvider<ProStatusController, bool>((ref) {
  return ProStatusController(ref.watch(subscriptionServiceProvider));
});

/// Convenience boolean: is the current user a Pro subscriber?
///
/// True when EITHER RevenueCat reports the entitlement active, OR the
/// server-trusted `_entitlements/{uid}.pro` flag is set. The latter lets you
/// grant Pro to any user with a single Firestore toggle (comps, promos,
/// support), and also keeps real purchases unlocked on the client since the
/// RevenueCat webhook writes that same flag.
final isProProvider = Provider<bool>((ref) {
  final fromStore = ref.watch(proStatusProvider);
  final fromServer = ref.watch(serverProProvider).valueOrNull ?? false;
  return fromStore || fromServer;
});

/// Streams the server-trusted Pro flag at `_entitlements/{uid}`. The user can
/// READ their own flag (firestore.rules) but never write it — only the backend
/// (RevenueCat webhook or an admin/console edit) sets it. Honors either a
/// permanent `pro: true` flag or a time-boxed `proUntil` gift date.
final serverProProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('_entitlements')
      .doc(uid)
      .snapshots()
      .map((snap) => entitlementIsActive(snap.data()));
});

/// True when the entitlement doc grants Pro: a permanent `pro: true` flag, or a
/// `proUntil` date/timestamp still in the future.
bool entitlementIsActive(Map<String, dynamic>? data) =>
    parseEntitlement(data).active;

/// Rich, server-trusted Pro entitlement details for the current user: whether
/// it's active, whether it's a permanent flag (e.g. a paid subscription), and
/// the expiry date for a time-boxed gift (referral reward / promo).
class ProEntitlement {
  final bool active;
  final bool permanent;
  final DateTime? until;

  const ProEntitlement({
    this.active = false,
    this.permanent = false,
    this.until,
  });

  /// Whole days remaining on a time-boxed grant (rounded up). 0 when there is
  /// no expiry (permanent or inactive).
  int get daysLeft {
    final u = until;
    if (u == null) return 0;
    final mins = u.difference(DateTime.now()).inMinutes;
    if (mins <= 0) return 0;
    return (mins / (60 * 24)).ceil();
  }
}

/// Parses an `_entitlements/{uid}` document into a [ProEntitlement].
ProEntitlement parseEntitlement(Map<String, dynamic>? data) {
  if (data == null) return const ProEntitlement();
  final permanent = data['pro'] == true;
  final raw = data['proUntil'];
  DateTime? untilDate;
  if (raw is Timestamp) {
    untilDate = raw.toDate();
  } else if (raw is num) {
    untilDate = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  final futureUntil =
      (untilDate != null && untilDate.isAfter(DateTime.now())) ? untilDate : null;
  return ProEntitlement(
    active: permanent || futureUntil != null,
    permanent: permanent,
    until: futureUntil,
  );
}

/// Streams the current user's full Pro entitlement details (permanent flag +
/// expiry), so screens can show the real Pro status rather than a cosmetic
/// estimate. Reads the owner-readable `_entitlements/{uid}` doc.
final proEntitlementProvider = StreamProvider<ProEntitlement>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const ProEntitlement());
  final db = ref.watch(firestoreProvider);
  return db
      .collection('_entitlements')
      .doc(uid)
      .snapshots()
      .map((snap) => parseEntitlement(snap.data()));
});

/// One-shot fetch of the active subscription's store details (purchase/expiry
/// dates, renewal state, store, management URL) for the Pro status screen.
///
/// Returns null when subscriptions aren't configured or the user's Pro comes
/// from a server-side grant (a referral reward / promo written to
/// `_entitlements/{uid}`) rather than an actual store purchase — in that case
/// the screen shows the [proEntitlementProvider] details instead. Re-fetches
/// automatically whenever the live entitlement state flips.
final proDetailsProvider =
    FutureProvider.autoDispose<ProDetails?>((ref) async {
  ref.watch(proStatusProvider);
  return ref.watch(subscriptionServiceProvider).fetchDetails();
});

/// Keeps RevenueCat's identity in sync with Firebase auth: logs the user in to
/// RevenueCat when they sign in, and out when they sign out. Watch this once
/// (e.g. in HomeShell) so entitlements follow the account across devices.
final subscriptionAuthLinkProvider = Provider<void>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  final uid = ref.watch(currentUidProvider);
  if (uid != null && uid.isNotEmpty) {
    service.logIn(uid);
  } else {
    service.logOut();
  }
});
