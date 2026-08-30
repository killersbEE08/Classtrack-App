import 'dart:typed_data';

import '../../import/domain/parsed_schedule.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String text;
  final Uint8List? image;

  /// The file name of a PDF the user attached to this message (display only —
  /// the bytes are sent to the model but not retained on the message). Null
  /// when there's no PDF attached.
  final String? pdfName;

  /// If the assistant proposed a schedule, it's attached here so the UI can
  /// offer an "Add to calendar" action.
  final ParsedSchedule? schedule;

  /// Destructive actions (deletes) the assistant proposed that are HELD pending
  /// the user's explicit confirmation — they are NOT executed until the user
  /// taps Confirm. This guards against a prompt-injection (e.g. from a shared
  /// image/text) silently wiping the user's data. Null when there's nothing to
  /// confirm. [pendingSummary] is a human-readable description for the card.
  final List<Map<String, dynamic>>? pendingActions;
  final String? pendingSummary;

  const ChatMessage({
    required this.role,
    required this.text,
    this.image,
    this.pdfName,
    this.schedule,
    this.pendingActions,
    this.pendingSummary,
  });

  bool get isUser => role == ChatRole.user;

  /// Whether this message is awaiting the user's confirmation of a destructive
  /// action.
  bool get hasPendingActions =>
      pendingActions != null && pendingActions!.isNotEmpty;

  /// A copy with the pending actions cleared (after confirm/cancel), so the
  /// confirmation card collapses and the buttons can't be tapped twice.
  ChatMessage withoutPending() => ChatMessage(
        role: role,
        text: text,
        image: image,
        pdfName: pdfName,
        schedule: schedule,
      );
}
