import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/media_asset.dart';

void main() {
  group('sanitizeMediaFilename', () {
    test('lowercases, hyphenates and keeps extension', () {
      expect(sanitizeMediaFilename('My Logo (Final).PNG'),
          'my-logo-final.png');
    });
    test('handles no extension and messy names', () {
      expect(sanitizeMediaFilename('  Hello  World!! '), 'hello-world');
      expect(sanitizeMediaFilename('***'), 'file');
    });
    test('collapses separators in base and extension', () {
      expect(sanitizeMediaFilename('a__b..jpg'), 'a-b.jpg');
    });
  });

  group('prettyBytes', () {
    test('formats B/KB/MB', () {
      expect(prettyBytes(500), '500 B');
      expect(prettyBytes(2048), '2 KB');
      expect(prettyBytes(1572864), '1.5 MB');
    });
  });

  group('MediaAsset.fromMap', () {
    test('parses fields with safe defaults', () {
      final a = MediaAsset.fromMap('m1', {
        'url': 'https://x/img.png',
        'name': 'img.png',
        'path': 'cms/media/1/img.png',
        'contentType': 'image/png',
        'size': 1234,
      });
      expect(a.url, 'https://x/img.png');
      expect(a.path, 'cms/media/1/img.png');
      expect(a.size, 1234);
      final empty = MediaAsset.fromMap('m2', {});
      expect(empty.size, 0);
      expect(empty.name, '');
    });
  });
}
