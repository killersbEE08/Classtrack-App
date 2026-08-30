/// Domain model + pure parser for the AI Smart Weekly Planner (Pro).
///
/// The planner asks Gemini (via the existing `chat` Cloud Function) to return a
/// study/revision plan inside a fenced ```plan JSON block. [parseWeeklyPlan]
/// extracts and validates it — pure and side-effect free, so it's fully unit
/// testable without any network.
library;

import 'dart:convert';

/// The kind of a planned block, used only for display (icon/colour) in the UI.
enum PlanBlockKind { study, revision, task, exam, review, breakTime, other }

PlanBlockKind planBlockKindFromString(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'study':
      return PlanBlockKind.study;
    case 'revision':
    case 'revise':
      return PlanBlockKind.revision;
    case 'task':
    case 'assignment':
    case 'homework':
      return PlanBlockKind.task;
    case 'exam':
    case 'test':
      return PlanBlockKind.exam;
    case 'review':
    case 'recap':
      return PlanBlockKind.review;
    case 'break':
    case 'rest':
      return PlanBlockKind.breakTime;
    default:
      return PlanBlockKind.other;
  }
}

/// A single scheduled block in the weekly plan.
class PlanBlock {
  /// Calendar day as `yyyy-MM-dd`.
  final String day;

  /// Wall-clock start / end as `HH:MM`.
  final String start;
  final String end;

  final String title;
  final PlanBlockKind kind;

  /// Optional linked subject name and a short "why now" rationale.
  final String? subject;
  final String? reason;

  const PlanBlock({
    required this.day,
    required this.start,
    required this.end,
    required this.title,
    this.kind = PlanBlockKind.other,
    this.subject,
    this.reason,
  });

  /// Parsed [day] as a DateTime (date-only), or null when malformed.
  DateTime? get date {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(day.trim());
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  String get timeRange =>
      (start.trim().isEmpty && end.trim().isEmpty) ? '' : '$start–$end';

  static PlanBlock? fromJson(Map<String, dynamic> j) {
    final title = (j['title'] as String?)?.trim() ?? '';
    final day = (j['day'] as String?)?.trim() ?? '';
    if (title.isEmpty || day.isEmpty) return null;
    String s(dynamic v) => (v is String) ? v.trim() : '';
    return PlanBlock(
      day: day,
      start: s(j['start']),
      end: s(j['end']),
      title: title,
      kind: planBlockKindFromString(j['type'] as String?),
      subject: s(j['subject']).isEmpty ? null : s(j['subject']),
      reason: s(j['reason']).isEmpty ? null : s(j['reason']),
    );
  }
}

/// A full generated plan: an optional one-line [summary] plus the ordered
/// [blocks].
class WeeklyPlan {
  final String? summary;
  final List<PlanBlock> blocks;

  const WeeklyPlan({this.summary, this.blocks = const []});

  bool get isEmpty => blocks.isEmpty;

  /// Blocks grouped by their `day`, in ascending date order; blocks within a
  /// day are sorted by start time.
  Map<String, List<PlanBlock>> get byDay {
    final map = <String, List<PlanBlock>>{};
    for (final b in blocks) {
      (map[b.day] ??= <PlanBlock>[]).add(b);
    }
    final sortedKeys = map.keys.toList()..sort();
    final out = <String, List<PlanBlock>>{};
    for (final k in sortedKeys) {
      final list = map[k]!
        ..sort((a, b) => _minutes(a.start).compareTo(_minutes(b.start)));
      out[k] = list;
    }
    return out;
  }

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}

/// Extracts a [WeeklyPlan] from a model reply that contains a fenced ```plan
/// JSON block. Returns null when no valid plan block is present. Tolerates a
/// bare JSON object (no fence) as a fallback, and an unlabelled ```json fence.
WeeklyPlan? parseWeeklyPlan(String reply) {
  String? jsonStr;

  final fenced = RegExp(r'```(?:plan|json)?\s*([\s\S]*?)```', multiLine: true)
      .firstMatch(reply);
  if (fenced != null) {
    jsonStr = fenced.group(1)?.trim();
  } else {
    // Fallback: a bare {...} object somewhere in the text.
    final bare = RegExp(r'\{[\s\S]*\}').firstMatch(reply);
    jsonStr = bare?.group(0);
  }
  if (jsonStr == null || jsonStr.isEmpty) return null;

  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) return null;
    final rawBlocks = decoded['blocks'];
    if (rawBlocks is! List) return null;
    final blocks = <PlanBlock>[];
    for (final item in rawBlocks) {
      if (item is Map<String, dynamic>) {
        final b = PlanBlock.fromJson(item);
        if (b != null) blocks.add(b);
      }
    }
    if (blocks.isEmpty) return null;
    final summary = (decoded['summary'] as String?)?.trim();
    return WeeklyPlan(
      summary: (summary == null || summary.isEmpty) ? null : summary,
      blocks: blocks,
    );
  } catch (_) {
    return null;
  }
}
