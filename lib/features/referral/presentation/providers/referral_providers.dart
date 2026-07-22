import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/referral_repository.dart';
import '../../domain/referral_info.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.watch(firebaseFunctionsProvider));
});

/// Fetches the caller's invite code + stats. Refetched whenever the signed-in
/// user changes. Invalidate this after a successful redeem to refresh state.
final referralInfoProvider = FutureProvider<ReferralInfo>((ref) async {
  // Re-run when auth identity changes so a new account gets its own code.
  ref.watch(currentUidProvider);
  return ref.watch(referralRepositoryProvider).getReferralInfo();
});

/// Handles the "redeem a friend's code" mutation with loading/error state.
class RedeemController extends StateNotifier<AsyncValue<int?>> {
  RedeemController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  /// Returns the granted reward days on success, or null on failure (state
  /// carries the error for the UI to surface).
  Future<int?> redeem(String code) async {
    state = const AsyncLoading();
    try {
      final days = await _ref.read(referralRepositoryProvider).redeem(code);
      state = AsyncData(days);
      // Refresh the invite info so `referredBy` flips to redeemed.
      _ref.invalidate(referralInfoProvider);
      return days;
    } on FirebaseFunctionsException catch (e, st) {
      state = AsyncError(e.message ?? 'Could not redeem that code.', st);
      return null;
    } catch (e, st) {
      state = AsyncError('Something went wrong. Please try again.', st);
      return null;
    }
  }
}

final redeemControllerProvider =
    StateNotifierProvider<RedeemController, AsyncValue<int?>>((ref) {
  return RedeemController(ref);
});
