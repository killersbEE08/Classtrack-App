import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app/browser. Shows a snackbar on failure.
Future<void> openUrl(BuildContext context, String? url) async {
  if (url == null || url.trim().isEmpty) return;
  var normalized = url.trim();
  if (!normalized.startsWith('http://') &&
      !normalized.startsWith('https://') &&
      !normalized.contains('://')) {
    normalized = 'https://$normalized';
  }
  final uri = Uri.tryParse(normalized);
  final messenger = ScaffoldMessenger.of(context);
  if (uri == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Invalid link')));
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $normalized')));
  }
}
