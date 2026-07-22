import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/referral_info.dart';

/// Talks to the referral Cloud Functions. All referral state is server-owned
/// (see functions/index.js) so the client can't spoof invite counts or rewards.
class ReferralRepository {
  final FirebaseFunctions _functions;

  ReferralRepository(this._functions);

  /// Fetches (allocating on first call) the caller's invite code and stats.
  Future<ReferralInfo> getReferralInfo() async {
    final res = await _functions
        .httpsCallable(AppConstants.getReferralInfoFunction)
        .call<Object?>();
    return ReferralInfo.fromMap(_asMap(res.data));
  }

  /// Redeems a friend's [code]. Returns the number of free Pro days granted.
  /// Throws [FirebaseFunctionsException] with a friendly message on failure
  /// (invalid/own/already-redeemed code).
  Future<int> redeem(String code) async {
    final res = await _functions
        .httpsCallable(AppConstants.redeemReferralFunction)
        .call<Object?>({'code': code.trim().toUpperCase()});
    final data = _asMap(res.data);
    return (data['rewardDays'] as num?)?.toInt() ?? 0;
  }

  /// Callable results arrive as `Map<Object?, Object?>`; normalise to a typed
  /// string-keyed map.
  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }
}
