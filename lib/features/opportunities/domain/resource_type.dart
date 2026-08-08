import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The kind of a [Resource]. A single unified collection backs every kind of
/// opportunity and discount; this discriminator decides how it's presented and
/// which surface (Opportunities vs Discounts) it belongs to.
///
/// The [key] is the stable string persisted in Firestore — never rename these.
enum ResourceType {
  scholarship('scholarship', 'Scholarship', Icons.school_rounded),
  internship('internship', 'Internship', Icons.work_outline_rounded),
  discount('discount', 'Student discount', Icons.local_offer_rounded),
  hackathon('hackathon', 'Hackathon', Icons.code_rounded),
  competition('competition', 'Competition', Icons.emoji_events_rounded),
  ambassador('ambassador', 'Ambassador program', Icons.campaign_rounded),
  course('course', 'Free course', Icons.menu_book_rounded),
  certification('certification', 'Certification', Icons.verified_rounded),
  research('research', 'Research program', Icons.science_rounded),
  event('event', 'Event', Icons.event_rounded),
  job('job', 'Job', Icons.business_center_rounded),
  grant('grant', 'Grant', Icons.volunteer_activism_rounded),
  exchange('exchange', 'Exchange program', Icons.public_rounded),
  conference('conference', 'Conference', Icons.groups_rounded),
  startup('startup', 'Startup program', Icons.rocket_launch_rounded);

  const ResourceType(this.key, this.label, this.icon);

  /// Stable Firestore value.
  final String key;

  /// Human-readable singular label.
  final String label;

  /// Icon used across cards and detail pages.
  final IconData icon;

  /// Discounts render on the Savings surface and use partner/redemption fields;
  /// everything else is an "opportunity".
  bool get isDiscount => this == ResourceType.discount;

  /// A representative accent colour for the type's chips/icons.
  Color get color {
    switch (this) {
      case ResourceType.scholarship:
      case ResourceType.ambassador:
        return AppColors.primary;
      case ResourceType.internship:
      case ResourceType.job:
      case ResourceType.certification:
        return AppColors.info;
      case ResourceType.discount:
      case ResourceType.course:
      case ResourceType.grant:
        return AppColors.success;
      case ResourceType.hackathon:
      case ResourceType.startup:
        return AppColors.coral;
      case ResourceType.competition:
      case ResourceType.event:
      case ResourceType.conference:
        return AppColors.accent;
      case ResourceType.research:
      case ResourceType.exchange:
        return AppColors.primaryLight;
    }
  }

  /// Parse a stored key back to a [ResourceType], defaulting to [scholarship]
  /// for unknown/legacy values so a bad document never crashes the feed.
  static ResourceType fromKey(String? key) {
    for (final t in ResourceType.values) {
      if (t.key == key) return t;
    }
    return ResourceType.scholarship;
  }
}
