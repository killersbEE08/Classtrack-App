import 'dart:typed_data';

import '../../import/domain/parsed_schedule.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String text;
  final Uint8List? image;

  /// If the assistant proposed a schedule, it's attached here so the UI can
  /// offer an "Add to calendar" action.
  final ParsedSchedule? schedule;

  const ChatMessage({
    required this.role,
    required this.text,
    this.image,
    this.schedule,
  });

  bool get isUser => role == ChatRole.user;
}
