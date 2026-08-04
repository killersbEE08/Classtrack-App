/// App-wide constants and Firestore collection/field keys.
class AppConstants {
  AppConstants._();

  static const String appName = 'ClassTrack';
  static const String bundleId = 'com.classtracks.app';

  // Google Sign-In: the OAuth 2.0 *Web* client ID (client_type 3 in
  // google-services.json). Passing this explicitly to GoogleSignIn makes the
  // native SDK request an ID token directly, instead of relying on the
  // auto-generated `default_web_client_id` string resource — which R8's
  // resource shrinker strips from release builds, causing idToken == null and
  // sign-in to fail only on Play Store / release builds.
  static const String googleServerClientId =
      '401205940629-8qbn7p6an2icehcp8lbortsom24ii7oa.apps.googleusercontent.com';

  /// OAuth scope requested when importing a timetable from Google Calendar.
  /// Read-only: ClassTrack only ever reads the user's events, never writes.
  static const String googleCalendarScope =
      'https://www.googleapis.com/auth/calendar.readonly';

  // Defaults
  static const double defaultTargetAttendance = 75.0;

  // Firestore collections
  static const String usersCollection = 'users';
  static const String subjectsCollection = 'subjects';
  static const String sessionsCollection = 'sessions';
  static const String attendanceCollection = 'attendance';
  static const String importJobsCollection = 'importJobs';

  // Cloud Function
  static const String parseScheduleFunction = 'parseSchedule';
  static const String getReferralInfoFunction = 'getReferralInfo';
  static const String redeemReferralFunction = 'redeemReferral';

  // Referrals — each successful referral grants BOTH users this many free
  // days of ClassTrack Pro (written server-side to _entitlements/{uid}).
  static const int referralRewardDays = 3;
  // Number of successful invites that unlock the "ambassador" milestone.
  static const int referralAmbassadorGoal = 5;

  // SharedPreferences keys
  static const String prefsOnboardingDone = 'onboarding_done';
  static const String prefsThemeMode = 'theme_mode';
  static const String prefsGeminiKey = 'gemini_api_key';
  static const String prefsReminderLead = 'reminder_lead_minutes';
  static const String prefsRemindersEnabled = 'reminders_enabled';
  static const String prefsGpaScale = 'gpa_scale'; // 'four' or 'ten'
  static const String prefsCurrency = 'currency_symbol';
  static const String prefsMonthlyBudget = 'monthly_budget';
  static const String prefsAccentColor = 'accent_color'; // ARGB int, 0 = default

  // Notification preferences
  static const String prefsNotifyClasses = 'notify_classes';
  static const String prefsNotifyTasks = 'notify_tasks';
  static const String prefsNotifyExams = 'notify_exams';
  static const String prefsNotifyHabits = 'notify_habits';
  static const String prefsDailySummary = 'notify_daily_summary';
  static const String prefsDailySummaryHour = 'notify_daily_summary_hour';
  static const String prefsDailySummaryMinute = 'notify_daily_summary_minute';
  static const String prefsQuietHours = 'notify_quiet_hours';
  static const String prefsQuietStartHour = 'notify_quiet_start_hour';
  static const String prefsQuietEndHour = 'notify_quiet_end_hour';

  // Gemini
  static const String geminiModel = 'gemini-2.0-flash';

  // Website & legal (hosted pages)
  static const String websiteUrl = 'https://classtracks.app/';
  static const String privacyPolicyUrl = 'https://classtracks.app/privacy/';
  static const String termsUrl = 'https://classtracks.app/terms/';
  static const String supportUrl = 'https://classtracks.app/support/';

  // Contact
  static const String supportEmail = 'support@classtracks.app';
  static const String contactEmail = 'piyush@classtracks.app';

  // Store links
  static const String androidPackage = 'com.classtracks.app';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.classtracks.app';
  // Deep link that opens the Play Store app directly on the listing.
  static const String playStoreMarketUrl =
      'market://details?id=com.classtracks.app';
  // Where the store subscription-management screen lives.
  static const String manageSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';
}

/// Days of the week, Monday-first, matching DateTime.weekday (1..7)
/// but stored 0..6 (Mon=0) in Firestore for compactness.
class Weekdays {
  Weekdays._();

  static const List<String> full = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> short = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Convert DateTime.weekday (Mon=1..Sun=7) to storage index (Mon=0..Sun=6).
  static int fromDateTime(DateTime date) => date.weekday - 1;

  /// Parse "Monday".."Sunday" (case-insensitive) to 0..6, or null.
  static int? parse(String value) {
    final idx = full.indexWhere(
      (d) => d.toLowerCase() == value.trim().toLowerCase(),
    );
    return idx == -1 ? null : idx;
  }
}
