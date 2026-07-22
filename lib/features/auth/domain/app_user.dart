import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

/// App-level user profile stored at users/{uid}.
class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final double targetAttendancePercent;
  final double monthlyBudget;
  final String currency;
  final DateTime? createdAt;

  /// The user's own shareable invite code (allocated on first visit to the
  /// referral screen by the getReferralInfo Cloud Function). Null until then.
  final String? referralCode;

  /// How many friends have redeemed this user's code.
  final int referralCount;

  /// The referral code / referrer uid this user redeemed, if any. Non-null once
  /// they've accepted someone's invite (each user may redeem only once).
  final String? referredBy;

  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.targetAttendancePercent = AppConstants.defaultTargetAttendance,
    this.monthlyBudget = 0,
    this.currency = '₹',
    this.createdAt,
    this.referralCode,
    this.referralCount = 0,
    this.referredBy,
  });

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    double? targetAttendancePercent,
    double? monthlyBudget,
    String? currency,
    String? referralCode,
    int? referralCount,
    String? referredBy,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      targetAttendancePercent:
          targetAttendancePercent ?? this.targetAttendancePercent,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      referralCode: referralCode ?? this.referralCode,
      referralCount: referralCount ?? this.referralCount,
      referredBy: referredBy ?? this.referredBy,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'targetAttendancePercent': targetAttendancePercent,
        'monthlyBudget': monthlyBudget,
        'currency': currency,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        // NOTE: referralCode / referralCount / referredBy are intentionally NOT
        // written here. They are owned by the Cloud Functions backend (admin
        // SDK) so a client can never spoof their invite count or reward. The
        // client only ever reads them (see fromMap below).
      };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      displayName: map['displayName'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      targetAttendancePercent:
          (map['targetAttendancePercent'] as num?)?.toDouble() ??
              AppConstants.defaultTargetAttendance,
      monthlyBudget: (map['monthlyBudget'] as num?)?.toDouble() ?? 0,
      currency: (map['currency'] as String?) ?? '₹',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      referralCode: map['referralCode'] as String?,
      referralCount: (map['referralCount'] as num?)?.toInt() ?? 0,
      referredBy: map['referredBy'] as String?,
    );
  }
}
