import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/checklist_item.dart';
import '../../../core/utils/validators.dart';
import 'flashcard.dart';
import 'note_attachment.dart';

/// A quick note / lecture note. Stored at users/{uid}/notes/{id}.
class Note {
  final String id;
  final String title;
  final String body;
  final String? subjectId;
  final String? linkedExamId; // optional link to an exam/event
  final int? colorHex; // optional accent color
  final bool pinned;
  final List<ChecklistItem> checklist;

  /// Study deck attached to this note (question/answer pairs).
  final List<Flashcard> flashcards;

  /// Files (images / PDFs) attached to this note, stored in Firebase Storage.
  final List<NoteAttachment> attachments;

  final DateTime? updatedAt;
  final DateTime? createdAt;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.subjectId,
    this.linkedExamId,
    this.colorHex,
    this.pinned = false,
    this.checklist = const [],
    this.flashcards = const [],
    this.attachments = const [],
    this.updatedAt,
    this.createdAt,
  });

  String get preview {
    final text = body.trim().replaceAll('\n', ' ');
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  bool get isEmpty =>
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      checklist.isEmpty &&
      flashcards.isEmpty &&
      attachments.isEmpty;

  bool get hasChecklist => checklist.isNotEmpty;
  int get checklistDone => checklist.where((c) => c.done).length;

  bool get hasFlashcards => flashcards.isNotEmpty;
  int get flashcardCount => flashcards.length;

  List<NoteAttachment> get imageAttachments =>
      attachments.where((a) => a.isImage).toList();
  List<NoteAttachment> get pdfAttachments =>
      attachments.where((a) => a.isPdf).toList();

  Note copyWith({
    String? title,
    String? body,
    String? subjectId,
    String? linkedExamId,
    int? colorHex,
    bool? pinned,
    List<ChecklistItem>? checklist,
    List<Flashcard>? flashcards,
    List<NoteAttachment>? attachments,
    DateTime? updatedAt,
    bool clearSubject = false,
    bool clearColor = false,
    bool clearLinkedExam = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      linkedExamId:
          clearLinkedExam ? null : (linkedExamId ?? this.linkedExamId),
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      pinned: pinned ?? this.pinned,
      checklist: checklist ?? this.checklist,
      flashcards: flashcards ?? this.flashcards,
      attachments: attachments ?? this.attachments,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': Validators.sanitizeText(title, maxLength: 200),
        'body': Validators.sanitizeText(body, multiline: true),
        'subjectId': subjectId,
        'linkedExamId': linkedExamId,
        'colorHex': colorHex,
        'pinned': pinned,
        'checklist': ChecklistItem.listToMap(checklist),
        'flashcards': Flashcard.listToMap(flashcards),
        'attachments': NoteAttachment.listToMap(attachments),
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      title: Validators.sanitizeText((map['title'] as String?) ?? '',
          maxLength: 200),
      body: Validators.sanitizeText((map['body'] as String?) ?? '',
          multiline: true),
      subjectId: map['subjectId'] as String?,
      linkedExamId: map['linkedExamId'] as String?,
      colorHex: (map['colorHex'] as num?)?.toInt(),
      pinned: (map['pinned'] as bool?) ?? false,
      checklist: ChecklistItem.listFrom(map['checklist']),
      flashcards: Flashcard.listFrom(map['flashcards']),
      attachments: NoteAttachment.listFrom(map['attachments']),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
