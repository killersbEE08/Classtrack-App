/// The caller's referral state, returned by the `getReferralInfo` Cloud
/// Function. All fields are server-owned — the client only ever reads them.
class ReferralInfo {
  /// The user's own shareable invite code (e.g. "K7P2QM9").
  final String code;

  /// How many friends have successfully joined with this user's code.
  final int referralCount;

  /// The referrer uid this user redeemed, if any. Non-null once they've
  /// accepted an invite (each account may redeem only once).
  final String? referredBy;

  /// Free Pro days granted to each side per successful referral.
  final int rewardDays;

  const ReferralInfo({
    required this.code,
    required this.referralCount,
    required this.referredBy,
    required this.rewardDays,
  });

  bool get hasRedeemed => referredBy != null;

  /// Total free Pro days this user has earned by inviting friends.
  int get earnedDays => referralCount * rewardDays;

  factory ReferralInfo.fromMap(Map<String, dynamic> map) {
    return ReferralInfo(
      code: (map['code'] as String?) ?? '',
      referralCount: (map['referralCount'] as num?)?.toInt() ?? 0,
      referredBy: map['referredBy'] as String?,
      rewardDays: (map['rewardDays'] as num?)?.toInt() ?? 3,
    );
  }

  ReferralInfo copyWith({int? referralCount, String? referredBy}) => ReferralInfo(
        code: code,
        referralCount: referralCount ?? this.referralCount,
        referredBy: referredBy ?? this.referredBy,
        rewardDays: rewardDays,
      );
}
