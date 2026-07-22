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
      final info = await Purchases.purchasePackage(package);
      _onCustomerInfo(info);
      return _isPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      throw SubscriptionException(_messageFor(code));
    }
  }

  /// Restores previous purchases (required by both stores). Returns true when
  /// a Pro entitlement was found.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      _onCustomerInfo(await Purchases.restorePurchases());
    } catch (_) {}
    return _isPro;
  }

  String _messageFor(PurchasesErrorCode code) => switch (code) {
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are not allowed on this device.',
        PurchasesErrorCode.paymentPendingError =>
          'Your payment is pending. Pro unlocks once it clears.',
        PurchasesErrorCode.networkError =>
          'Network error. Check your connection and try again.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own this — try Restore purchases.',
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
