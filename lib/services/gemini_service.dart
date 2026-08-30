import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../features/import/domain/parsed_schedule.dart';

/// Gemini access that goes through auth-gated Cloud Functions. The API key
/// lives ONLY server-side (GEMINI_API_KEY secret) and is never shipped in the
/// app, so it cannot be extracted from the binary.
class GeminiService {
  final FirebaseFunctions _functions;
  GeminiService(this._functions);

  /// Always "configured" — the key is managed by the backend.
  bool get isConfigured => true;

  /// One-shot structured timetable parse from text and/or an image, via the
  /// `parseSchedule` Cloud Function (which validates + sanitizes server-side).
  Future<ParsedSchedule> parseSchedule({
    String? text,
    Uint8List? imageBytes,
    Uint8List? pdfBytes,
  }) async {
    final Map<String, dynamic> payload;
    if (text != null && text.trim().isNotEmpty) {
      payload = {'sourceType': 'text', 'text': text};
    } else if (pdfBytes != null) {
      // A PDF timetable (e.g. an exported college schedule). Gemini reads PDFs
      // natively, so we send the raw bytes inline with the PDF mime type and
      // the backend `parseSchedule` function forwards them to the model.
      payload = {
        'sourceType': 'pdf',
        'inlineData': base64Encode(pdfBytes),
        'mimeType': 'application/pdf',
      };
    } else if (imageBytes != null) {
      payload = {
        'sourceType': 'image',
        'inlineData': base64Encode(imageBytes),
        'mimeType': 'image/jpeg',
      };
    } else {
      return ParsedSchedule(subjects: const [], confidence: 'low');
    }

    final callable = _functions.httpsCallable('parseSchedule');
    final res = await callable.call(payload);
    // Deep-convert the callable result into plain JSON maps/lists.
    final map = jsonDecode(jsonEncode(res.data)) as Map<String, dynamic>;
    return ParsedSchedule.fromJson(map);
  }

  /// Multi-turn chat via the `chat` Cloud Function. [history] is a serializable
  /// list of {role, parts:[{text}|{inlineData:{data,mimeType}}]}. [context] is
  /// an optional plain-text summary of the user's app data.
  Future<String> chat(List<Map<String, dynamic>> history,
      {String? context}) async {
    final callable = _functions.httpsCallable('chat');
    final res = await callable.call({
      'history': history,
      if (context != null && context.isNotEmpty) 'context': context,
    });
    final data = res.data;
    if (data is Map && data['text'] is String) return data['text'] as String;
    return "Sorry, I couldn't come up with a reply.";
  }

  // --- Reply parsing helpers (client-side, no network) -----------------------

  static ParsedSchedule _parseScheduleJson(String raw) {
    final cleaned =
        raw.trim().replaceAll(RegExp(r'```(json|schedule)?'), '').trim();
    try {
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      return ParsedSchedule.fromJson(map);
    } catch (_) {
      return ParsedSchedule(subjects: const [], confidence: 'low');
    }
  }

  static ParsedSchedule? extractScheduleFromReply(String reply) {
    final match = RegExp(r'```schedule\s*([\s\S]*?)```', multiLine: true)
        .firstMatch(reply);
    if (match == null) return null;
    final json = match.group(1)?.trim() ?? '';
    if (json.isEmpty) return null;
    final parsed = _parseScheduleJson(json);
    return parsed.isEmpty ? null : parsed;
  }

  static String stripScheduleBlock(String reply) => reply
      .replaceAll(RegExp(r'```schedule[\s\S]*?```', multiLine: true), '')
      .trim();

  // --- Action ("invisible function calling") parsing --------------------------

  /// Pulls the list of structured actions out of an `actions` fenced block, if
  /// present. Returns an empty list when there's nothing to run.
  static List<Map<String, dynamic>> extractActionsFromReply(String reply) {
    final match = RegExp(r'```actions\s*([\s\S]*?)```', multiLine: true)
        .firstMatch(reply);
    if (match == null) return const [];
    final json = match.group(1)?.trim() ?? '';
    if (json.isEmpty) return const [];
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final list = map['actions'];
      if (list is! List) return const [];
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Removes the `actions` block so it never shows in the chat bubble.
  static String stripActionsBlock(String reply) => reply
      .replaceAll(RegExp(r'```actions[\s\S]*?```', multiLine: true), '')
      .trim();

  /// Removes ANY remaining fenced code block (```lang … ```), so raw JSON or
  /// script the model sometimes echoes alongside its actions — e.g. a
  /// ```json duplicate of the delete list — never shows in the plain-text chat
  /// bubble. (The functional `actions`/`schedule` blocks are extracted from the
  /// original reply beforehand, so removing them here only affects display.)
  static String stripAllCodeFences(String reply) => reply
      .replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '')
      // A trailing, unclosed fence (truncated response) — drop from the fence
      // marker to the end so a half-printed code block can't leak through.
      .replaceAll(RegExp(r'```[a-zA-Z]*[\s\S]*$'), '')
      .trim();

  /// Removes a bare (unfenced) actions/schedule JSON object the model sometimes
  /// writes straight into the prose, e.g. `{ "actions": [ … ] }`.
  static String stripBareActionsJson(String reply) => reply
      .replaceAll(
          RegExp(r'\{\s*"(actions|subjects|schedule)"\s*:[\s\S]*\}',
              multiLine: true),
          '')
      .trim();
}
