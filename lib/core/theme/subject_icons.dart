import 'package:flutter/material.dart';

/// A curated catalog of subject/tag icons the user can pick from, instead of a
/// single generic book. Every entry is a `const IconData`, so Flutter's icon
/// tree-shaking keeps working (we store the string [key], never a raw
/// codePoint). Add new icons by appending to [catalog].
class SubjectIcons {
  SubjectIcons._();

  static const String defaultKey = 'book';

  /// Ordered so related subjects sit near each other in the picker.
  static const Map<String, IconData> catalog = {
    'book': Icons.menu_book_rounded,
    'notebook': Icons.auto_stories_rounded,
    'pencil': Icons.edit_note_rounded,
    'calculator': Icons.calculate_rounded,
    'function': Icons.functions_rounded,
    'science': Icons.science_rounded,
    'chemistry': Icons.biotech_rounded,
    'physics': Icons.bolt_rounded,
    'atom': Icons.blur_on_rounded,
    'biology': Icons.eco_rounded,
    'health': Icons.medical_services_rounded,
    'psychology': Icons.psychology_rounded,
    'code': Icons.code_rounded,
    'computer': Icons.computer_rounded,
    'data': Icons.storage_rounded,
    'ai': Icons.smart_toy_rounded,
    'network': Icons.hub_rounded,
    'design': Icons.brush_rounded,
    'art': Icons.palette_rounded,
    'photography': Icons.photo_camera_rounded,
    'music': Icons.music_note_rounded,
    'theater': Icons.theater_comedy_rounded,
    'language': Icons.translate_rounded,
    'literature': Icons.history_edu_rounded,
    'history': Icons.account_balance_rounded,
    'geography': Icons.public_rounded,
    'map': Icons.map_rounded,
    'astronomy': Icons.rocket_launch_rounded,
    'business': Icons.business_center_rounded,
    'finance': Icons.attach_money_rounded,
    'economics': Icons.trending_up_rounded,
    'law': Icons.gavel_rounded,
    'engineering': Icons.engineering_rounded,
    'architecture': Icons.architecture_rounded,
    'sports': Icons.sports_soccer_rounded,
    'food': Icons.restaurant_rounded,
    'nature': Icons.forest_rounded,
    'idea': Icons.lightbulb_rounded,
    'star': Icons.star_rounded,
    'school': Icons.school_rounded,
  };

  static List<String> get keys => catalog.keys.toList();

  /// Resolve a stored key to its icon, falling back to the generic book.
  static IconData resolve(String? key) =>
      catalog[key] ?? catalog[defaultKey]!;
}
