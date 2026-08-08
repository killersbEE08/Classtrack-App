import 'package:flutter/material.dart';

import '../../../../services/link_metadata_service.dart';
import 'tasks_screen.dart';

/// Handles a URL/text shared INTO the app (Android/iOS share sheet).
///
/// Fetches best-effort metadata (title, thumbnail, Video/Course detection) for
/// the shared URL, then opens the SAME editable "New item" bottom sheet used
/// elsewhere, pre-filled with what we found. Nothing is saved automatically —
/// every field stays editable and the user must tap "Add". If metadata can't
/// be fetched, only the URL is pre-filled.
Future<void> openSharedLinkEditor(
  BuildContext context,
  String sharedText,
) async {
  final url = LinkMetadataService.extractUrl(sharedText) ?? sharedText.trim();
  if (url.isEmpty || !context.mounted) return;

  final service = LinkMetadataService();

  // Brief spinner while the link is enriched (bounded by the service timeout).
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  LinkMetadata meta;
  try {
    meta = await service.resolve(url);
  } catch (_) {
    meta = LinkMetadata(url: url);
  } finally {
    service.dispose();
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // dismiss the spinner
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskEditorSheet(
      initialType: meta.type,
      initialTitle: meta.title,
      initialLink: meta.url,
      initialThumbnail: meta.thumbnail,
    ),
  );
}
