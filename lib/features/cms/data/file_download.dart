// Cross-platform entry point for triggering a client-side file download.
//
// The real implementation lives in `file_download_web.dart` (uses the browser
// download mechanism) and is selected only when compiling for the web. On
// other platforms the stub is used, so mobile builds and `flutter test` (VM)
// compile cleanly without any `dart:html` dependency.
export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
