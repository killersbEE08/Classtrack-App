import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures a widget wrapped in a [RepaintBoundary] to a PNG and shares it via
/// the OS share sheet, so students can post their milestone straight to
/// Instagram, WhatsApp, etc.
class MomentShareService {
  MomentShareService._();

  /// Renders the boundary behind [boundaryKey] to a high-resolution PNG and
  /// opens the share sheet with [caption]. Returns false if the boundary
  /// couldn't be captured.
  static Future<bool> shareBoundary(
    GlobalKey boundaryKey, {
    required String caption,
    String? subject,
  }) async {
    final bytes = await capturePng(boundaryKey);
    if (bytes == null) return false;

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/classtrack_moment_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: caption,
      subject: subject,
    );
    return true;
  }

  /// Rasterises the boundary to PNG bytes at [pixelRatio] (3.0 ≈ crisp on all
  /// devices). Returns null if the render object isn't ready.
  static Future<List<int>?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) return null;
    final object = context.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    final image = await object.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
