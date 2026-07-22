import 'package:flutter/material.dart';

/// Drop-in replacement for the unmaintained `phosphor_flutter` package, which
/// is incompatible with Flutter's `final class IconData`. Maps the icon names
/// this app uses to built-in Material icons. The optional style argument is
/// accepted for call-site compatibility and ignored.
enum PhosphorIconsStyle { thin, light, regular, bold, fill, duotone }

class PhosphorIcons {
  const PhosphorIcons._();

  static IconData house([PhosphorIconsStyle? s]) => Icons.home_rounded;
  static IconData calendarBlank([PhosphorIconsStyle? s]) =>
      Icons.calendar_today_rounded;
  static IconData calendarCheck([PhosphorIconsStyle? s]) =>
      Icons.event_available_rounded;
  static IconData calendarPlus([PhosphorIconsStyle? s]) =>
      Icons.calendar_month_rounded;
  static IconData sparkle([PhosphorIconsStyle? s]) =>
      Icons.auto_awesome_rounded;
  static IconData checkCircle([PhosphorIconsStyle? s]) =>
      Icons.check_circle_rounded;
  static IconData export([PhosphorIconsStyle? s]) => Icons.ios_share_rounded;
  static IconData coffee([PhosphorIconsStyle? s]) => Icons.coffee_rounded;
  static IconData camera([PhosphorIconsStyle? s]) =>
      Icons.photo_camera_rounded;
  static IconData image([PhosphorIconsStyle? s]) => Icons.image_rounded;
  static IconData filePdf([PhosphorIconsStyle? s]) =>
      Icons.picture_as_pdf_rounded;
  static IconData fileCsv([PhosphorIconsStyle? s]) => Icons.table_chart_rounded;
  static IconData bell([PhosphorIconsStyle? s]) => Icons.notifications_rounded;
  static IconData shieldCheck([PhosphorIconsStyle? s]) =>
      Icons.verified_user_rounded;
  static IconData info([PhosphorIconsStyle? s]) => Icons.info_outline_rounded;
  static IconData signOut([PhosphorIconsStyle? s]) => Icons.logout_rounded;
  static IconData confetti([PhosphorIconsStyle? s]) =>
      Icons.celebration_rounded;
  static IconData warning([PhosphorIconsStyle? s]) =>
      Icons.warning_amber_rounded;
  static IconData warningCircle([PhosphorIconsStyle? s]) =>
      Icons.error_outline_rounded;
  static IconData chartPieSlice([PhosphorIconsStyle? s]) =>
      Icons.pie_chart_rounded;
  static IconData clock([PhosphorIconsStyle? s]) => Icons.access_time_rounded;
  static IconData books([PhosphorIconsStyle? s]) => Icons.menu_book_rounded;
  static IconData gear([PhosphorIconsStyle? s]) => Icons.settings_rounded;
}
