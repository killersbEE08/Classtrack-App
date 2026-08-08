import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The lifecycle state of a [Resource] (PRD §8).
///
/// Some states are **manual/terminal** — an admin sets them and dates never
/// override them ([draft], [hidden], [discontinued], [archived]). The rest are
/// **date-driven** and computed automatically from the resource's start date
/// and deadline (see [resolveResourceStatus]).
///
/// [key] is the stable Firestore value — never rename.
enum ResourceStatus {
  /// Not visible to students. Work in progress.
  draft('draft', 'Draft'),

  /// Program exists but applications haven't opened yet.
  openingSoon('opening_soon', 'Opening soon'),

  /// Students can apply / use the opportunity now.
  active('active', 'Active'),

  /// The application window has closed.
  applicationsClosed('applications_closed', 'Applications closed'),

  /// The opportunity's validity has ended.
  expired('expired', 'Expired'),

  /// The organisation permanently stopped the program.
  discontinued('discontinued', 'Discontinued'),

  /// Admin-only state (never shown to students).
  hidden('hidden', 'Hidden'),

  /// Historical record retained but not actively displayed.
  archived('archived', 'Archived');

  const ResourceStatus(this.key, this.label);

  final String key;
  final String label;

  /// Students can browse it (draft/hidden are never exposed, even by direct
  /// link). Used as the read gate in Firestore security rules too.
  bool get isVisibleToStudents =>
      this != ResourceStatus.draft && this != ResourceStatus.hidden;

  /// Appears in the default Opportunities/Discounts browse feed.
  bool get isInActiveFeed =>
      this == ResourceStatus.openingSoon || this == ResourceStatus.active;

  /// The application/redemption action should be enabled.
  bool get isOpen => this == ResourceStatus.active;

  /// Manual states that date-based transitions must never override.
  bool get isManual =>
      this == ResourceStatus.draft ||
      this == ResourceStatus.hidden ||
      this == ResourceStatus.discontinued ||
      this == ResourceStatus.archived;

  /// Accent colour for status chips.
  Color get color {
    switch (this) {
      case ResourceStatus.active:
        return AppColors.success;
      case ResourceStatus.openingSoon:
        return AppColors.info;
      case ResourceStatus.applicationsClosed:
      case ResourceStatus.expired:
        return AppColors.warning;
      case ResourceStatus.discontinued:
        return AppColors.danger;
      case ResourceStatus.draft:
      case ResourceStatus.hidden:
      case ResourceStatus.archived:
        return AppColors.cancelled;
    }
  }

  static ResourceStatus fromKey(String? key) {
    for (final s in ResourceStatus.values) {
      if (s.key == key) return s;
    }
    // Unknown/absent → treat as draft (invisible) so a malformed doc can never
    // leak into the student feed.
    return ResourceStatus.draft;
  }
}

/// Resolves the *effective* status of a resource from its stored [stored]
/// status and its configured dates.
///
/// Manual states ([ResourceStatus.isManual]) are returned unchanged so an admin
/// override always wins. Date-driven states transition automatically:
///
/// ```
/// before startDate         → Opening soon
/// startDate … deadline      → Active
/// after deadline            → Applications closed
/// ```
///
/// When neither date is configured, the [stored] status is trusted as-is (an
/// admin is driving the lifecycle manually).
ResourceStatus resolveResourceStatus({
  required ResourceStatus stored,
  DateTime? startDate,
  DateTime? deadline,
  DateTime? now,
}) {
  if (stored.isManual) return stored;
  final t = now ?? DateTime.now();
  if (startDate == null && deadline == null) return stored;
  if (startDate != null && t.isBefore(startDate)) {
    return ResourceStatus.openingSoon;
  }
  if (deadline != null && t.isAfter(deadline)) {
    return ResourceStatus.applicationsClosed;
  }
  return ResourceStatus.active;
}
