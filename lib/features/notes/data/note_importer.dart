import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A note extracted from an imported file, ready to be reviewed/saved.
class ImportedNote {
  final String title;
  final String body;

  const ImportedNote({required this.title, required this.body});

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;
}

/// Picks PDF / text files and extracts their text into [ImportedNote]s.
///
/// - PDFs are parsed with Syncfusion's [PdfTextExtractor] (pure Dart, works on
///   all platforms). Scanned/image-only PDFs contain no selectable text, so
///   the body may come back empty for those.
/// - `.txt` / `.md` files are decoded as UTF-8.
class NoteImporter {
  const NoteImporter._();

  /// File extensions the picker will accept.
  static const List<String> allowedExtensions = [
    'pdf',
    'txt',
    'md',
    'markdown',
    'text',
  ];

  /// Opens the system file picker and returns one [ImportedNote] per selected
  /// file. Returns an empty list if the user cancels.
  static Future<List<ImportedNote>> pickAndExtract() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null) return const [];

    final notes = <ImportedNote>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final ext = (file.extension ?? '').toLowerCase();
      final title = _titleFromName(file.name);
      final body = ext == 'pdf' ? _extractPdf(bytes) : _decodeText(bytes);
      notes.add(ImportedNote(title: title, body: body.trim()));
    }
    return notes;
  }

  /// Strips the extension from a file name to use as a note title.
  static String _titleFromName(String name) {
    final withoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    return withoutExt.isEmpty ? 'Imported note' : withoutExt;
  }

  static String _extractPdf(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      return PdfTextExtractor(document).extractText();
    } catch (_) {
      return '';
    } finally {
      document?.dispose();
    }
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // Fall back to a lenient decode for non-UTF8 text files.
      return const Utf8Decoder(allowMalformed: true).convert(bytes);
    }
  }
}
