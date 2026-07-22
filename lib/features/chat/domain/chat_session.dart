import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_message.dart';

/// A saved AI chat conversation. Stored at users/{uid}/chatSessions/{id}.
///
/// Only the role + text of each message is persisted — transient attachments
/// (images, proposed-schedule cards) are not stored, so history stays small
/// and cheap to sync.
class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    this.messages = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// A short preview of the last message, for the history list.
  String get preview {
    for (final m in messages.reversed) {
      final t = m.text.trim();
      if (t.isNotEmpty) {
        return t.length > 90 ? '${t.substring(0, 90)}…' : t;
      }
    }
    return '';
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'messages': messages
            .where((m) => m.text.trim().isNotEmpty)
            .map((m) => {
                  'role': m.role == ChatRole.user ? 'user' : 'assistant',
                  'text': m.text,
                })
            .toList(),
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
      };

  factory ChatSession.fromMap(String id, Map<String, dynamic> map) {
    final raw = (map['messages'] as List<dynamic>?) ?? const [];
    final title = (map['title'] as String?)?.trim();
    return ChatSession(
      id: id,
      title: (title == null || title.isEmpty) ? 'Chat' : title,
      messages: raw
          .whereType<Map<String, dynamic>>()
          .map((m) => ChatMessage(
                role: (m['role'] as String?) == 'user'
                    ? ChatRole.user
                    : ChatRole.assistant,
                text: (m['text'] as String?) ?? '',
              ))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
