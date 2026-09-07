import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/pro_constants.dart';

/// Wraps RevenueCat (`purchases_flutter`) behind a small, null-safe surface so
/// the rest of the app never touches the SDK directly and keeps working even
/// when subscriptions aren't configured yet.
///
/// Every method is a safe no-op when [ProConstants.enabled] is false, so the
/// app runs on the free tier without a RevenueCat key.
class SubscriptionService {
  bool _configured = false;
  bool _isPro = false;

  final StreamController<bool> _proController =
      StreamController<bool>.broadcast();

  bool get isConfigured => _configured;
  bool get isProNow => _isPro;

  /// Emits the latest Pro entitlement state (true = unlocked).
  Stream<bool> get isProStream => _proController.stream;

  /// Configure the SDK once at startup. Safe to call when no key is set.
  Future<void> configure({String? appUserId}) async {
    if (_configured || !ProConstants.enabled) return;
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      final config = PurchasesConfiguration(ProConstants.apiKey)
        ..appUserID = (appUserId != null && appUserId.isNotEmpty)
            ? appUserId
            : null;
      await Purchases.configure(config);
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      await refresh();
    } catch (_) {
      // Never let a store/config error crash startup — stay on free tier.
      _configured = false;
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active;
    // ClassTrack has a single paid tier, so treat the user as Pro when the
    // configured entitlement is active OR — to stay robust to the exact
    // entitlement identifier chosen in RevenueCat (e.g. "pro" vs
    // "ClassTrack Pro") — when ANY entitlement is active.
    final pro = active.containsKey(ProConstants.entitlementId) ||
        active.isNotEmpty;
    if (pro != _isPro) {
      _isPro = pro;
      if (!_proController.isClosed) _proController.add(pro);
    }
  }

  /// Re-reads the entitlement state from RevenueCat. Pass [invalidateCache] to
  /// force a network fetch (bypassing RevenueCat's local cache) — used on login
  /// and app resume so an expired/cancelled/test subscription is reflected
  /// promptly instead of showing a stale "Pro".
  Future<bool> refresh({bool invalidateCache = false}) async {
    if (!_configured) return false;
    try {
      if (invalidateCache) {
        await Purchases.invalidateCustomerInfoCache();
      }
      _onCustomerInfo(await Purchases.getCustomerInfo());
    } catch (_) {/* keep last known state */}
    return _isPro;
  }

  /// Tie purchases to the signed-in Firebase user so entitlements follow them
  /// across devices. No-op when unconfigured.
  Future<void> logIn(String uid) async {
    if (!_configured || uid.isEmpty) return;
    try {
      final result = await Purchases.logIn(uid);
      _onCustomerInfo(result.customerInfo);
      // Don't trust RevenueCat's cached CustomerInfo here: force a fresh fetch
      // so an expired or cancelled subscription (including sandbox/test buys
      // that lapse) is reflected right away instead of lingering as "Pro".
      await refresh(invalidateCache: true);
    } catch (_) {}
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      // Anonymous users can't log out; ignore that specific failure.
      await Purchases.logOut();
    } catch (_) {}
    if (_isPro) {
      _isPro = false;
      if (!_proController.isClosed) _proController.add(false);
    }
  }

  /// The purchasable packages from the current offering (empty when disabled).
  Future<List<Package>> fetchPackages() async {
    if (!_configured) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      final current =
          offerings.getOffering(ProConstants.offeringId) ?? offerings.current;
      return current?.availablePackages ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Purchases a package. Returns true when Pro is now active, false when the
  /// user cancelled. Throws [SubscriptionException] on a real error.
  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      // purchases_flutter 9.0.0+ returns a PurchaseResult (customerInfo +
      // storeTransaction) instead of a bare CustomerInfo, and `purchasePackage`
      // is deprecated in favour of `purchase(PurchaseParams)`.
      final result =
          await Purchases.purchase(PurchaseParams.package(package));
      _onCustomerInfo(result.customerInfo);
      return _isPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      throw SubscriptionException(_messageFor(code));
    }
  }

  /// Reads the active entitlement's full details (purchase/expiry dates, store,
  /// renewal state, management URL) for the Pro status screen. Returns null
  /// when subscriptions aren't configured, no entitlement is active, or the
  /// lookup fails — the UI then falls back to the server-trusted entitlement
  /// (e.g. a referral/promo grant, which isn't a store purchase).
  Future<ProDetails?> fetchDetails({bool invalidateCache = false}) async {
    if (!_configured) return null;
    try {
      if (invalidateCache) {
        await Purchases.invalidateCustomerInfoCache();
      }
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active;
      // Prefer the configured entitlement id, but fall back to any active one
      // (mirrors _onCustomerInfo, which stays robust to the entitlement's name).
      final ent = active[ProConstants.entitlementId] ??
          (active.isNotEmpty ? active.values.first : null);
      if (ent == null) return null;
      DateTime? parse(String? s) =>
          (s == null || s.isEmpty) ? null : DateTime.tryParse(s)?.toLocal();
      return ProDetails(
        active: ent.isActive,
        willRenew: ent.willRenew,
        inTrial: ent.periodType == PeriodType.trial,
        isSandbox: ent.isSandbox,
        hasBillingIssue: ent.billingIssueDetectedAt != null,
        cancelled: ent.unsubscribeDetectedAt != null,
        purchaseDate: parse(ent.originalPurchaseDate),
        latestRenewalDate: parse(ent.latestPurchaseDate),
        expirationDate: parse(ent.expirationDate),
        storeLabel: _storeLabel(ent.store),
        productIdentifier: ent.productIdentifier,
        managementUrl: info.managementURL,
      );
    } catch (_) {
      return null;
    }
  }

  /// Friendly, user-facing name for a RevenueCat [Store]. Keeps the SDK enum
  /// out of the UI layer.
  String _storeLabel(Store store) => switch (store) {
        Store.playStore => 'Google Play',
        Store.appStore || Store.macAppStore => 'App Store',
        Store.stripe => 'Stripe',
        Store.amazon => 'Amazon Appstore',
        Store.promotional => 'Promo',
        Store.rcBilling => 'Web',
        Store.paddle => 'Paddle',
        Store.galaxy => 'Galaxy Store',
        Store.testStore => 'Test store',
        Store.externalStore => 'External store',
        _ => 'Store',
      };

  /// Restores previous purchases (required by both stores).
  ///
  /// A ClassTrack Pro subscription is tied to the account that originally
  /// bought it. If the same Google Play/App Store purchase is restored while
  /// signed into a *different* ClassTrack account, the store (configured with
  /// "keep purchases with the original App User ID") refuses to transfer it and
  /// raises [PurchasesErrorCode.receiptAlreadyInUseError]. We surface that as a
  /// distinct outcome so the UI can tell the user to sign in with the original
  /// account or buy a separate subscription for this one — rather than silently
  /// unlocking Pro on a second account for a single payment.
  Future<RestoreResult> restore() async {
    if (!_configured) {
      return const RestoreResult(
        RestoreStatus.error,
        'Subscriptions aren\'t available right now.',
      );
    }
    try {
      _onCustomerInfo(await Purchases.restorePurchases());
      if (_isPro) {
        return const RestoreResult(
          RestoreStatus.restored,
          'Purchases restored — Pro is active.',
        );
      }
      return const RestoreResult(
        RestoreStatus.nothingFound,
        'No previous purchases found for this account.',
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.receiptAlreadyInUseError) {
        return const RestoreResult(
          RestoreStatus.linkedToAnotherAccount,
          'This subscription is already linked to a different ClassTrack '
          'account. Sign in with that account to use Pro here, or buy a '
          'separate Pro subscription for this account.',
        );
      }
      return RestoreResult(RestoreStatus.error, _messageFor(code));
    } catch (_) {
      return const RestoreResult(
        RestoreStatus.error,
        'Couldn\'t restore purchases. Please try again.',
      );
    }
  }

  String _messageFor(PurchasesErrorCode code) => switch (code) {
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are not allowed on this device.',
        PurchasesErrorCode.paymentPendingError =>
          'Your payment is pending. Pro unlocks once it clears.',
        PurchasesErrorCode.networkError =>
          'Network error. Check your connection and try again.',
        // The store account already owns this subscription, but it belongs to
        // a *different* ClassTrack account. It can't be shared across accounts.
        PurchasesErrorCode.receiptAlreadyInUseError =>
          'This Google subscription is linked to a different ClassTrack '
          'account. Sign in with that account to use Pro, or buy a separate '
          'subscription for this account.',
        // This same ClassTrack account already owns Pro on the store.
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own Pro on this account — try Restore purchases.',
        _ => 'Something went wrong with the purchase. Please try again.',
      };

  void dispose() {
    if (!_proController.isClosed) _proController.close();
  }
}

/// A user-presentable purchase error.
class SubscriptionException implements Exception {
  final String message;
  const SubscriptionException(this.message);
  @override
  String toString() => message;
}

/// Outcome of a [SubscriptionService.restore] attempt.
enum RestoreStatus {
  /// A Pro entitlement was found and is now active for this account.
  restored,

  /// The restore succeeded but this account has no purchases to restore.
  nothingFound,

  /// The store purchase belongs to a *different* ClassTrack account and can't
  /// be transferred/shared. The user must sign in with the original account or
  /// buy a separate subscription for this one.
  linkedToAnotherAccount,

  /// The restore failed (network/store error).
  error,
}

/// Result of a restore attempt: a machine-readable [status] plus a ready-to-
/// show [message].
class RestoreResult {
  final RestoreStatus status;
  final String message;
  const RestoreResult(this.status, this.message);

  /// True only when Pro is now active for the current account.
  bool get isPro => status == RestoreStatus.restored;
}

/// A read-only snapshot of the user's active Pro subscription, surfaced on the
/// Pro status screen. Dates are already parsed to local [DateTime]s and the
/// store is a friendly label, so the UI never touches the RevenueCat SDK.
class ProDetails {
  /// Whether the entitlement is currently active.
  final bool active;

  /// True if the subscription is set to auto-renew at [expirationDate].
  final bool willRenew;

  /// True while the user is in a free-trial / introductory period.
  final bool inTrial;

  /// True for sandbox/test purchases (not a real production buy).
  final bool isSandbox;

  /// True if the store reported a billing problem (payment failing). Access may
  /// still be active during the grace period.
  final bool hasBillingIssue;

  /// True if the user turned off auto-renew but still has access until expiry.
  final bool cancelled;

  /// First time this subscription was purchased.
  final DateTime? purchaseDate;

  /// Most recent purchase/renewal date.
  final DateTime? latestRenewalDate;

  /// When access ends (or renews). Null for lifetime/non-expiring access.
  final DateTime? expirationDate;

  /// Friendly store name, e.g. "Google Play" or "App Store".
  final String storeLabel;

  /// The purchased product identifier (SKU).
  final String productIdentifier;

  /// Deep link to manage the subscription in the store, when available.
  final String? managementUrl;

  const ProDetails({
    required this.active,
    required this.willRenew,
    required this.inTrial,
    required this.isSandbox,
    required this.hasBillingIssue,
    required this.cancelled,
    required this.purchaseDate,
    required this.latestRenewalDate,
    required this.expirationDate,
    required this.storeLabel,
    required this.productIdentifier,
    required this.managementUrl,
  });
}
