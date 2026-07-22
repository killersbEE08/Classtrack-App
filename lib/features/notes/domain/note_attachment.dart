/// The kind of file attached to a note.
enum NoteAttachmentType {
  image,
  pdf;

  static NoteAttachmentType fromName(String? name) =>
      name == 'pdf' ? NoteAttachmentType.pdf : NoteAttachmentType.image;
}

/// A file (image or PDF) attached to a note. The bytes live in Firebase Storage
/// at [storagePath]; the note document stores this lightweight reference (the
/// download [url] for display + [storagePath] so the file can be deleted).
class NoteAttachment {
  final String id;
  final NoteAttachmentType type;

  /// Public download URL used to display/open the file.
  final String url;

  /// Storage object path (users/{uid}/noteAttachments/...), used for deletion.
  final String storagePath;

  /// Original file name, shown for PDFs.
  final String name;

  /// File size in bytes (0 when unknown).
  final int sizeBytes;

  const NoteAttachment({
    required this.id,
    required this.type,
    required this.url,
    required this.storagePath,
    required this.name,
    this.sizeBytes = 0,
  });

  bool get isImage => type == NoteAttachmentType.image;
  bool get isPdf => type == NoteAttachmentType.pdf;

  /// Human-readable size, e.g. "820 KB" or "3.4 MB".
  String get prettySize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'url': url,
        'storagePath': storagePath,
        'name': name,
        'sizeBytes': sizeBytes,
      };

  factory NoteAttachment.fromMap(Map<String, dynamic> map) => NoteAttachment(
        id: (map['id'] as String?) ?? '',
        type: NoteAttachmentType.fromName(map['type'] as String?),
        url: (map['url'] as String?) ?? '',
        storagePath: (map['storagePath'] as String?) ?? '',
        name: (map['name'] as String?) ?? 'Attachment',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      );

  static List<NoteAttachment> listFrom(dynamic raw) =>
      ((raw as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NoteAttachment.fromMap)
          .where((a) => a.url.isNotEmpty)
          .toList();

  static List<Map<String, dynamic>> listToMap(List<NoteAttachment> items) =>
      items.map((e) => e.toMap()).toList();
}
