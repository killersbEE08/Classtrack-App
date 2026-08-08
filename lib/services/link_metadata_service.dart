import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/tasks/domain/task_item.dart';

/// Metadata resolved for a shared/pasted URL, used to pre-fill the "New item"
/// sheet. Everything except [url] is best-effort — when a fetch fails only the
/// URL is populated and the user still gets an editable sheet.
class LinkMetadata {
  final String url;
  final String? title;
  final String? thumbnail;
  final TaskType type;

  const LinkMetadata({
    required this.url,
    this.title,
    this.thumbnail,
    this.type = TaskType.task,
  });
}

/// Resolves lightweight metadata (title, thumbnail, item type) for a URL so the
/// share flow can pre-fill the editable task sheet.
///
/// Pure networking, no plugins: uses YouTube's public oEmbed endpoint for
/// videos and a small HTML `<title>` / Open-Graph scrape for everything else.
/// Always resolves (never throws) so the caller can open the sheet regardless.
class LinkMetadataService {
  final http.Client _client;
  final Duration timeout;

  LinkMetadataService({http.Client? client, this.timeout = const Duration(seconds: 6)})
      : _client = client ?? http.Client();

  /// Pulls the first http(s) URL out of arbitrary shared text (share targets
  /// often send "Check this out: https://…"). Returns null when none is found.
  static String? extractUrl(String? shared) {
    if (shared == null) return null;
    final m = RegExp(r'https?://[^\s<>"]+', caseSensitive: false)
        .firstMatch(shared.trim());
    return m?.group(0);
  }

  /// True for links this app understands well enough to enrich.
  static bool isSupported(String url) => Uri.tryParse(url)?.hasScheme ?? false;

  Future<LinkMetadata> resolve(String rawUrl) async {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return LinkMetadata(url: url);

    final host = uri.host.toLowerCase();
    final isYouTube = host.contains('youtube.com') || host.contains('youtu.be');

    try {
      if (isYouTube) {
        final meta = await _youtube(uri);
        if (meta != null) return meta;
      }
      final scraped = await _scrape(uri);
      if (scraped != null) return scraped;
    } catch (_) {
      // Fall through to the URL-only result below.
    }

    // Couldn't fetch metadata — still classify by URL shape so the type toggle
    // starts on a sensible option, and pre-fill only the URL.
    return LinkMetadata(url: url, type: _typeForUri(uri));
  }

  /// YouTube oEmbed: reliable title + thumbnail without an API key.
  Future<LinkMetadata?> _youtube(Uri uri) async {
    final endpoint = Uri.https('www.youtube.com', '/oembed', {
      'url': uri.toString(),
      'format': 'json',
    });
    final res = await _client.get(endpoint).timeout(timeout);
    final type = _typeForUri(uri);
    if (res.statusCode != 200) {
      // A playlist (or unavailable video) may not have oEmbed; derive a
      // thumbnail from the video id when we can.
      return LinkMetadata(
          url: uri.toString(),
          type: type,
          thumbnail: _youtubeThumb(uri));
    }
    final body = jsonDecode(res.body);
    if (body is! Map) return null;
    final title = (body['title'] as String?)?.trim();
    final thumb = (body['thumbnail_url'] as String?)?.trim();
    return LinkMetadata(
      url: uri.toString(),
      title: (title == null || title.isEmpty) ? null : title,
      thumbnail: (thumb == null || thumb.isEmpty) ? _youtubeThumb(uri) : thumb,
      type: type,
    );
  }

  /// Best-effort HTML scrape: prefers Open-Graph tags, falls back to <title>.
  Future<LinkMetadata?> _scrape(Uri uri) async {
    final res = await _client.get(
      uri,
      headers: const {'User-Agent': 'Mozilla/5.0 (compatible; ClassTrack/1.0)'},
    ).timeout(timeout);
    if (res.statusCode != 200) return null;
    final html = res.body;

    final ogTitle = _meta(html, 'og:title') ?? _titleTag(html);
    final ogImage = _meta(html, 'og:image');

    return LinkMetadata(
      url: uri.toString(),
      title: ogTitle,
      thumbnail: ogImage,
      type: _typeForUri(uri),
    );
  }

  /// Classifies a URL into a task type by well-known hosts / paths.
  static TaskType _typeForUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isPlaylist = uri.queryParameters.containsKey('list') &&
        !uri.queryParameters.containsKey('v');

    const courseHosts = <String>[
      'udemy.com',
      'coursera.org',
      'edx.org',
      'khanacademy.org',
      'skillshare.com',
      'udacity.com',
      'pluralsight.com',
      'linkedin.com', // LinkedIn Learning
      'futurelearn.com',
      'codecademy.com',
      'brilliant.org',
      'classroom.google.com',
    ];
    if (courseHosts.any(host.contains)) return TaskType.event;

    final isYouTube = host.contains('youtube.com') || host.contains('youtu.be');
    if (isYouTube) {
      // A pure playlist reads more like a course/series than a single video.
      return isPlaylist ? TaskType.event : TaskType.video;
    }

    const videoHosts = <String>['vimeo.com', 'twitch.tv', 'dailymotion.com'];
    if (videoHosts.any(host.contains)) return TaskType.video;
    if (path.endsWith('.mp4') || path.endsWith('.mov')) return TaskType.video;

    return TaskType.task;
  }

  /// Derives the standard YouTube thumbnail from a watch/short URL id.
  static String? _youtubeThumb(Uri uri) {
    String? id;
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else {
      id = uri.queryParameters['v'];
      if (id == null && uri.pathSegments.length >= 2) {
        // /shorts/<id> or /embed/<id>
        id = uri.pathSegments[1];
      }
    }
    if (id == null || id.isEmpty) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  static String? _meta(String html, String property) {
    // Matches <meta property="og:title" content="..."> in either attribute
    // order, for property= or name=.
    final patterns = [
      RegExp(
          '<meta[^>]+(?:property|name)=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']*)["\']',
          caseSensitive: false),
      RegExp(
          '<meta[^>]+content=["\']([^"\']*)["\'][^>]+(?:property|name)=["\']${RegExp.escape(property)}["\']',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      final v = m?.group(1)?.trim();
      if (v != null && v.isNotEmpty) return _unescape(v);
    }
    return null;
  }

  static String? _titleTag(String html) {
    final m = RegExp(r'<title[^>]*>([^<]*)</title>', caseSensitive: false)
        .firstMatch(html);
    final v = m?.group(1)?.trim();
    return (v == null || v.isEmpty) ? null : _unescape(v);
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  void dispose() => _client.close();
}
