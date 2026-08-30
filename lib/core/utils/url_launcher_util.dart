import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app/browser. Shows a snackbar on failure.
///
/// SECURITY: only a small allowlist of schemes is permitted. Links come from
/// CMS content, user-entered subject resource links and shared URLs, so a bare
/// `launchUrl` could be coerced into opening dangerous schemes
/// (`file://`, `content://`, `intent://`, `javascript:`, `data:`, `smb://`, …).
/// A scheme-less input is treated as https.
Future<void> openUrl(BuildContext context, String? url) async {
  if (url == null || url.trim().isEmpty) return;
  var normalized = url.trim();
  if (!normalized.startsWith('http://') &&
      !normalized.startsWith('https://') &&
      !normalized.contains('://')) {
    normalized = 'https://$normalized';
  }
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Invalid link')));
    return;
  }
  // Allowlist: web links, email and phone only. Anything else is refused.
  const allowedSchemes = {'http', 'https', 'mailto', 'tel'};
  if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
    messenger.showSnackBar(const SnackBar(content: Text('Link type not allowed')));
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $normalized')));
  }
}
