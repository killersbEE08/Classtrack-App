/// Non-web stub: file downloads are only supported in the browser build of the
/// CMS. Kept as a no-op so shared code compiles on mobile / under `flutter test`.
bool get canDownloadFiles => false;

/// No-op on non-web platforms.
void downloadTextFile(String filename, String mimeType, String content) {
  // Intentionally empty — see file_download_web.dart for the real behaviour.
}
