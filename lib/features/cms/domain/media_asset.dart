import 'package:cloud_firestore/cloud_firestore.dart';

/// An uploaded media asset indexed in `mediaAssets/{id}` (the file lives in
/// Cloud Storage under [path]). Reusable across Resource/Banner editors.
class MediaAsset {
  final String id;
  final String url;
  final String name;
  final String path; // storage path, for deletion
  final String? contentType;
  final int size;
  final DateTime? createdAt;

  const MediaAsset({
    required this.id,
    required this.url,
    required this.name,
    required this.path,
    this.contentType,
    this.size = 0,
    this.createdAt,
  });

  factory MediaAsset.fromMap(String id, Map<String, dynamic> m) => MediaAsset(
        id: id,
        url: (m['url'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        path: (m['path'] as String?) ?? '',
        contentType: m['contentType'] as String?,
        size: (m['size'] as num?)?.toInt() ?? 0,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

/// Normalises an upload filename to a safe, lowercase `base.ext` form.
/// Pure — unit-testable.
String sanitizeMediaFilename(String name) {
  final lower = name.trim().toLowerCase();
  final dot = lower.lastIndexOf('.');
  final base = dot > 0 ? lower.substring(0, dot) : lower;
  final ext = dot > 0 ? lower.substring(dot + 1) : '';
  String clean(String s) => s
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final safeBase = clean(base).isEmpty ? 'file' : clean(base);
  final safeExt = clean(ext);
  return safeExt.isEmpty ? safeBase : '$safeBase.$safeExt';
}

/// A human-readable size label, e.g. 24 KB / 1.4 MB.
String prettyBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
