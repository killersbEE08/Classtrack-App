import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../domain/note_attachment.dart';

/// Picks images/PDFs and uploads them to Firebase Storage under
/// `users/{uid}/noteAttachments/`, returning lightweight [NoteAttachment]
/// references to store on the note. Also deletes files from Storage.
///
/// Storage rules already restrict this path to the owner and to image/PDF
/// files under 10 MB (see storage.rules).
class NoteAttachmentService {
  final FirebaseStorage _storage;
  final String uid;
  final ImagePicker _picker;

  static const _uuid = Uuid();

  /// Matches the 10 MB cap enforced by storage.rules — checked client-side too
  /// so the user gets a friendly message instead of an opaque upload failure.
  static const int maxBytes = 10 * 1024 * 1024;

  NoteAttachmentService({
    required FirebaseStorage storage,
    required this.uid,
    ImagePicker? picker,
  })  : _storage = storage,
        _picker = picker ?? ImagePicker();

  /// Thrown when a picked file exceeds [maxBytes].
  static const oversizeMessage = 'Files must be under 10 MB.';

  /// Picks one or more images from the gallery and uploads them.
  Future<List<NoteAttachment>> pickAndUploadGalleryImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    return _uploadImageFiles(files);
  }

  /// Captures a photo with the camera and uploads it.
  Future<List<NoteAttachment>> pickAndUploadCameraImage() async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    return _uploadImageFiles(file == null ? const [] : [file]);
  }

  Future<List<NoteAttachment>> _uploadImageFiles(List<XFile> files) async {
    final out = <NoteAttachment>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      _ensureSize(bytes);
      final ext = _extOf(f.name, fallback: 'jpg');
      out.add(await _upload(
        bytes: bytes,
        name: f.name,
        ext: ext,
        contentType: _imageContentType(ext),
        type: NoteAttachmentType.image,
      ));
    }
    return out;
  }

  /// Picks one or more PDFs and uploads them.
  Future<List<NoteAttachment>> pickAndUploadPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null) return const [];

    final out = <NoteAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      _ensureSize(bytes);
      out.add(await _upload(
        bytes: bytes,
        name: file.name,
        ext: 'pdf',
        contentType: 'application/pdf',
        type: NoteAttachmentType.pdf,
      ));
    }
    return out;
  }

  Future<NoteAttachment> _upload({
    required Uint8List bytes,
    required String name,
    required String ext,
    required String contentType,
    required NoteAttachmentType type,
  }) async {
    final id = _uuid.v4();
    final path = 'users/$uid/noteAttachments/$id.$ext';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return NoteAttachment(
      id: id,
      type: type,
      url: url,
      storagePath: path,
      name: name,
      sizeBytes: bytes.length,
    );
  }

  /// Best-effort deletion of a single attachment's Storage object.
  Future<void> deleteByPath(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {
      // Object may already be gone — ignore.
    }
  }

  /// Best-effort deletion of every attachment's file (e.g. when a note is
  /// deleted).
  Future<void> deleteAll(List<NoteAttachment> attachments) async {
    for (final a in attachments) {
      await deleteByPath(a.storagePath);
    }
  }

  void _ensureSize(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw Exception(oversizeMessage);
    }
  }

  static String _extOf(String name, {required String fallback}) {
    final match = RegExp(r'\.([^.]+)$').firstMatch(name);
    final ext = match?.group(1)?.toLowerCase();
    return (ext == null || ext.isEmpty) ? fallback : ext;
  }

  static String _imageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
