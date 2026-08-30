// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

/// Web build supports client-side downloads.
bool get canDownloadFiles => true;

/// Triggers a browser download of [content] as [filename] using a temporary
/// object URL. UTF-8 encoded with a BOM so spreadsheet apps detect encoding.
void downloadTextFile(String filename, String mimeType, String content) {
  final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}
