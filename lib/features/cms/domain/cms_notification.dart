import 'package:cloud_firestore/cloud_firestore.dart';

/// A CMS-composed targeted notification (see `notifications` collection). The
/// CMS creates it as `queued`; the `sendQueuedNotification` Cloud Function
/// delivers it and fills in status/topic/sentAt.
class CmsNotification {
  final String id;
  final String title;
  final String body;
  final String? country; // null/Global = broadcast to all
  final String? payload; // deep-link payload
  final String status; // queued | sent | failed
  final String? topic;
  final String? error;
  final DateTime? createdAt;
  final DateTime? sentAt;

  const CmsNotification({
    required this.id,
    required this.title,
    required this.body,
    this.country,
    this.payload,
    this.status = 'queued',
    this.topic,
    this.error,
    this.createdAt,
    this.sentAt,
  });

  factory CmsNotification.fromMap(String id, Map<String, dynamic> m) {
    return CmsNotification(
      id: id,
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      country: m['country'] as String?,
      payload: m['payload'] as String?,
      status: (m['status'] as String?) ?? 'queued',
      topic: m['topic'] as String?,
      error: m['error'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      sentAt: (m['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
