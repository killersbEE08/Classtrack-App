import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/validators.dart';
import 'resource_status.dart';
import 'resource_type.dart';

/// The unified content model backing every opportunity **and** discount
/// (PRD §7). One collection (`resources`) stores them all; [type] discriminates
/// and drives which fields matter (e.g. discounts use [company]/[discountText]/
/// [redemptionInstructions]).
///
/// Authored exclusively by the CMS (privileged roles / Admin SDK). Clients only
/// ever read it — students can never mutate [status], [sponsored], [priority]
/// or any other field (enforced by Firestore rules).
class Resource {
  final String id;
  final ResourceType type;
  final String title;
  final String organization;
  final String description;

  /// Country targeting. Empty or containing `'Global'` = available everywhere;
  /// otherwise the resource is meant for these countries only (matched against
  /// the user's profile country, not IP — PRD §10).
  final List<String> countries;

  final String? eligibility;

  /// Drives the automatic status lifecycle (see [effectiveStatus]).
  final DateTime? startDate;
  final DateTime? deadline;

  final String? applicationUrl;
  final String? imageUrl;
  final List<String> tags;

  /// The *stored* status. Prefer [effectiveStatus], which applies the automatic
  /// date-driven lifecycle on top of this.
  final ResourceStatus status;

  final bool featured;
  final bool sponsored;

  /// Higher shows first. Also feeds the recommendation score.
  final int priority;

  /// Optional filter flags (PRD §14).
  final bool? remote;
  final bool? paid;

  /// Officially verified/partnered content.
  final bool verified;

  /// SEO slug for future web pages (PRD §22), e.g. `google-summer-of-code`.
  final String? slug;

  // ── Discount-specific (optional) — PRD §9 ────────────────────────────────
  final String? company;
  final String? logoUrl;
  final String? discountText;
  final String? redemptionInstructions;
  final bool verificationRequired;
  final String? affiliateUrl;
  final String? terms;
  final List<String> categories;

  // ── Personalisation targeting — PRD §12/§13 ──────────────────────────────
  final List<String> targetDegrees;
  final List<String> targetDepartments;
  final List<String> targetInterests;
  final List<String> targetCareerGoals;
  final List<int> targetAcademicYears;

  // ── Extended content (P0 editor completeness) — all optional/additive ─────
  /// Long-form body (the existing [description] is the short summary).
  final String? fullDescription;
  final String? officialWebsite;
  final String? benefits;
  final String? howToApply;
  final String? requirements;

  // Discount-specific extras (distinct from [discountText]/[redemptionInstructions]).
  final String? discountCode;
  final num? discountPercent;
  final String? redemptionUrl;

  // Scheduled publishing (enforced server-side; see functions).
  final DateTime? scheduledPublishAt;
  final DateTime? scheduledUnpublishAt;

  // Editorial promotion controls (separate from algorithmic relevance).
  final bool homepageEligible;
  final bool recommendationEligible;

  /// Manually-curated related resources (ids), to avoid dead-end detail pages.
  final List<String> relatedResourceIds;

  /// Server-owned URL health records keyed by field name (applicationUrl,
  /// affiliateUrl, redemptionUrl, officialWebsite). Read-only on the client —
  /// written by the URL-health Cloud Functions, never by [toMap].
  final Map<String, UrlHealth> urlHealth;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  const Resource({
    required this.id,
    required this.type,
    required this.title,
    required this.organization,
    this.description = '',
    this.countries = const [],
    this.eligibility,
    this.startDate,
    this.deadline,
    this.applicationUrl,
    this.imageUrl,
    this.tags = const [],
    this.status = ResourceStatus.draft,
    this.featured = false,
    this.sponsored = false,
    this.priority = 0,
    this.remote,
    this.paid,
    this.verified = false,
    this.slug,
    this.company,
    this.logoUrl,
    this.discountText,
    this.redemptionInstructions,
    this.verificationRequired = false,
    this.affiliateUrl,
    this.terms,
    this.categories = const [],
    this.targetDegrees = const [],
    this.targetDepartments = const [],
    this.targetInterests = const [],
    this.targetCareerGoals = const [],
    this.targetAcademicYears = const [],
    this.fullDescription,
    this.officialWebsite,
    this.benefits,
    this.howToApply,
    this.requirements,
    this.discountCode,
    this.discountPercent,
    this.redemptionUrl,
    this.scheduledPublishAt,
    this.scheduledUnpublishAt,
    this.homepageEligible = false,
    this.recommendationEligible = true,
    this.relatedResourceIds = const [],
    this.urlHealth = const {},
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// The status after applying the automatic date-driven lifecycle on top of
  /// the stored [status].
  ResourceStatus get effectiveStatus => resolveResourceStatus(
        stored: status,
        startDate: startDate,
        deadline: deadline,
      );

  bool get isVisibleToStudents => effectiveStatus.isVisibleToStudents;
  bool get isInActiveFeed => effectiveStatus.isInActiveFeed;
  bool get isOpen => effectiveStatus.isOpen;

  /// Whole days until the deadline (negative once past); null when no deadline.
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    final now = DateTime.now();
    return DateTime(deadline!.year, deadline!.month, deadline!.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  /// Whether this resource targets [userCountry]. Global/untargeted resources
  /// match everyone; a null user country only matches global/untargeted ones.
  bool targetsCountry(String? userCountry) {
    if (countries.isEmpty) return true;
    if (countries.any((c) => c.toLowerCase() == 'global')) return true;
    if (userCountry == null) return false;
    return countries.any((c) => c.toLowerCase() == userCountry.toLowerCase());
  }

  /// Display brand: a discount shows its [company]; everything else its
  /// [organization].
  String get brandName =>
      (company != null && company!.isNotEmpty) ? company! : organization;

  /// Best available image (hero image, then logo).
  String? get displayImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ? imageUrl : logoUrl;

  /// Returns a fresh DRAFT copy (no id/slug/timestamps, status reset) — used by
  /// the CMS "Duplicate" action so a new document is created rather than the
  /// original overwritten.
  Resource copyDraft({String titleSuffix = ''}) => Resource(
        id: '',
        type: type,
        title: '$title$titleSuffix',
        organization: organization,
        description: description,
        countries: countries,
        eligibility: eligibility,
        startDate: startDate,
        deadline: deadline,
        applicationUrl: applicationUrl,
        imageUrl: imageUrl,
        tags: tags,
        status: ResourceStatus.draft,
        featured: false,
        sponsored: sponsored,
        priority: priority,
        remote: remote,
        paid: paid,
        verified: verified,
        slug: null,
        company: company,
        logoUrl: logoUrl,
        discountText: discountText,
        redemptionInstructions: redemptionInstructions,
        verificationRequired: verificationRequired,
        affiliateUrl: affiliateUrl,
        terms: terms,
        categories: categories,
        targetDegrees: targetDegrees,
        targetDepartments: targetDepartments,
        targetInterests: targetInterests,
        targetCareerGoals: targetCareerGoals,
        targetAcademicYears: targetAcademicYears,
        fullDescription: fullDescription,
        officialWebsite: officialWebsite,
        benefits: benefits,
        howToApply: howToApply,
        requirements: requirements,
        discountCode: discountCode,
        discountPercent: discountPercent,
        redemptionUrl: redemptionUrl,
        // A duplicate should not inherit a publish schedule.
        scheduledPublishAt: null,
        scheduledUnpublishAt: null,
        homepageEligible: homepageEligible,
        recommendationEligible: recommendationEligible,
        relatedResourceIds: relatedResourceIds,
      );

  // ── Serialization ─────────────────────────────────────────────────────────

  factory Resource.fromMap(String id, Map<String, dynamic> map) {
    List<String> strList(dynamic v) => (v as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    List<int> intList(dynamic v) => (v as List?)
            ?.map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()))
            .whereType<int>()
            .toList() ??
        const [];
    DateTime? ts(dynamic v) => (v as Timestamp?)?.toDate();
    String? clean(dynamic v) => v == null
        ? null
        : Validators.sanitizeText(v.toString(), multiline: true);

    return Resource(
      id: id,
      type: ResourceType.fromKey(map['type'] as String?),
      title: Validators.sanitizeText((map['title'] as String?) ?? 'Untitled',
          maxLength: 160),
      organization: Validators.sanitizeText(
          (map['organization'] as String?) ?? '',
          maxLength: 160),
      description: clean(map['description']) ?? '',
      countries: strList(map['countries']),
      eligibility: clean(map['eligibility']),
      startDate: ts(map['startDate']),
      deadline: ts(map['deadline']),
      applicationUrl: map['applicationUrl'] as String?,
      imageUrl: map['imageUrl'] as String?,
      tags: strList(map['tags']),
      status: ResourceStatus.fromKey(map['status'] as String?),
      featured: (map['featured'] as bool?) ?? false,
      sponsored: (map['sponsored'] as bool?) ?? false,
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      remote: map['remote'] as bool?,
      paid: map['paid'] as bool?,
      verified: (map['verified'] as bool?) ?? false,
      slug: map['slug'] as String?,
      company: clean(map['company']),
      logoUrl: map['logoUrl'] as String?,
      discountText: clean(map['discountText']),
      redemptionInstructions: clean(map['redemptionInstructions']),
      verificationRequired: (map['verificationRequired'] as bool?) ?? false,
      affiliateUrl: map['affiliateUrl'] as String?,
      terms: clean(map['terms']),
      categories: strList(map['categories']),
      targetDegrees: strList(map['targetDegrees']),
      targetDepartments: strList(map['targetDepartments']),
      targetInterests: strList(map['targetInterests']),
      targetCareerGoals: strList(map['targetCareerGoals']),
      targetAcademicYears: intList(map['targetAcademicYears']),
      fullDescription: clean(map['fullDescription']),
      officialWebsite: map['officialWebsite'] as String?,
      benefits: clean(map['benefits']),
      howToApply: clean(map['howToApply']),
      requirements: clean(map['requirements']),
      discountCode: map['discountCode'] as String?,
      discountPercent: map['discountPercent'] as num?,
      redemptionUrl: map['redemptionUrl'] as String?,
      scheduledPublishAt: ts(map['scheduledPublishAt']),
      scheduledUnpublishAt: ts(map['scheduledUnpublishAt']),
      homepageEligible: (map['homepageEligible'] as bool?) ?? false,
      recommendationEligible:
          (map['recommendationEligible'] as bool?) ?? true,
      relatedResourceIds: strList(map['relatedResourceIds']),
      urlHealth: UrlHealth.mapFromDynamic(map['urlHealth']),
      createdAt: ts(map['createdAt']),
      updatedAt: ts(map['updatedAt']),
      publishedAt: ts(map['publishedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.key,
        'title': title,
        'organization': organization,
        'description': description,
        'countries': countries,
        'eligibility': eligibility,
        'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
        'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
        'applicationUrl': applicationUrl,
        'imageUrl': imageUrl,
        'tags': tags,
        'status': status.key,
        'featured': featured,
        'sponsored': sponsored,
        'priority': priority,
        'remote': remote,
        'paid': paid,
        'verified': verified,
        'slug': slug,
        'company': company,
        'logoUrl': logoUrl,
        'discountText': discountText,
        'redemptionInstructions': redemptionInstructions,
        'verificationRequired': verificationRequired,
        'affiliateUrl': affiliateUrl,
        'terms': terms,
        'categories': categories,
        'targetDegrees': targetDegrees,
        'targetDepartments': targetDepartments,
        'targetInterests': targetInterests,
        'targetCareerGoals': targetCareerGoals,
        'targetAcademicYears': targetAcademicYears,
        'fullDescription': fullDescription,
        'officialWebsite': officialWebsite,
        'benefits': benefits,
        'howToApply': howToApply,
        'requirements': requirements,
        'discountCode': discountCode,
        'discountPercent': discountPercent,
        'redemptionUrl': redemptionUrl,
        'scheduledPublishAt': scheduledPublishAt != null
            ? Timestamp.fromDate(scheduledPublishAt!)
            : null,
        'scheduledUnpublishAt': scheduledUnpublishAt != null
            ? Timestamp.fromDate(scheduledUnpublishAt!)
            : null,
        'homepageEligible': homepageEligible,
        'recommendationEligible': recommendationEligible,
        'relatedResourceIds': relatedResourceIds,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedAt':
            publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      };
}


/// A single URL's health record (server-computed). Immutable on the client.
class UrlHealth {
  /// 'ok' | 'broken' | 'unknown'.
  final String state;
  final int? httpStatus;
  final DateTime? checkedAt;

  const UrlHealth({required this.state, this.httpStatus, this.checkedAt});

  bool get isOk => state == 'ok';
  bool get isBroken => state == 'broken';

  factory UrlHealth.fromMap(Map<String, dynamic> m) => UrlHealth(
        state: (m['state'] as String?) ?? 'unknown',
        httpStatus: (m['httpStatus'] as num?)?.toInt(),
        checkedAt: (m['checkedAt'] as Timestamp?)?.toDate(),
      );

  /// Parses the raw `urlHealth` map ({field: {state,httpStatus,checkedAt}}).
  static Map<String, UrlHealth> mapFromDynamic(dynamic v) {
    if (v is! Map) return const {};
    final out = <String, UrlHealth>{};
    v.forEach((key, value) {
      if (value is Map) {
        out[key.toString()] =
            UrlHealth.fromMap(value.cast<String, dynamic>());
      }
    });
    return out;
  }
}
