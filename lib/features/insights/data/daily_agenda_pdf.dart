import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// One line in a daily-agenda section: a bold [title] and a muted [detail].
class AgendaLine {
  final String title;
  final String detail;
  const AgendaLine(this.title, this.detail);
}

/// One day's worth of scheduled classes for the weekly (last 7 days) report.
class DaySection {
  final DateTime date;
  final List<AgendaLine> classes;
  const DaySection(this.date, this.classes);
}

/// Builds and shares nicely formatted "Daily agenda" PDFs.
///
/// The bundled PDF fonts (Helvetica) don't carry glyphs like the bullet (•) or
/// en-dash (–), which render as empty boxes. To keep every export clean we
/// sanitise text to a safe ASCII subset and draw our own bullet dots instead
/// of relying on a bullet glyph.
class DailyAgendaPdf {
  DailyAgendaPdf._();

  static const _accent = PdfColor.fromInt(0xFF6C5CE7);
  static const _tint = PdfColor.fromInt(0xFFEDEAFB);

  /// Replace Unicode punctuation the standard PDF fonts can't render with
  /// plain ASCII equivalents so nothing shows up as a tofu box.
  static String _ascii(String s) => s
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('•', '-')
      .replaceAll('·', '-')
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('…', '...')
      .replaceAll('₹', 'Rs ')
      .replaceAll('→', '->');

  // ── Shared building blocks ─────────────────────────────────────────────

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
        child: pw.Text(
          _ascii(text),
          style: const pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _accent,
          ),
        ),
      );

  /// A dot-bulleted row with a bold title and optional muted detail.
  static pw.Widget _bulletLine(AgendaLine l) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 5,
              height: 5,
              margin: const pw.EdgeInsets.only(top: 4, right: 8),
              decoration: const pw.BoxDecoration(
                  color: _accent, shape: pw.BoxShape.circle),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: _ascii(l.title),
                      style: const pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    if (l.detail.trim().isNotEmpty)
                      pw.TextSpan(
                        text: '   ${_ascii(l.detail)}',
                        style: const pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  static pw.Widget _lines(List<AgendaLine> items, String emptyText) {
    if (items.isEmpty) {
      return pw.Text(_ascii(emptyText),
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [for (final l in items) _bulletLine(l)],
    );
  }

  /// Turns the AI summary's plain text into clean paragraphs and bullet rows
  /// (splitting on "• "/"- " markers) so nothing renders as a box.
  static List<pw.Widget> _summaryWidgets(String raw) {
    final out = <pw.Widget>[];
    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        out.add(pw.SizedBox(height: 5));
        continue;
      }
      final bullet = RegExp(r'^[•\-\*]\s+');
      if (bullet.hasMatch(line)) {
        final text = _ascii(line.replaceFirst(bullet, ''));
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 5,
                height: 5,
                margin: const pw.EdgeInsets.only(top: 4, right: 8),
                decoration: const pw.BoxDecoration(
                    color: _accent, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(
                child: pw.Text(text,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
              ),
            ],
          ),
        ));
      } else {
        out.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(_ascii(line),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ));
      }
    }
    return out;
  }

  static pw.Widget _headerBanner(String title, String subtitle) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          color: _accent,
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_ascii(title),
                style: const pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text(_ascii(subtitle),
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey200)),
          ],
        ),
      );

  static pw.Widget _footer() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              _ascii(
                  'Generated by ClassTrack - ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
      );

  static Future<void> _writeAndShare(pw.Document doc, String name) async {
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)],
        subject: 'ClassTrack - Daily agenda');
  }

  // ── Today ──────────────────────────────────────────────────────────────

  static Future<void> share({
    required String userName,
    required DateTime date,
    required List<AgendaLine> classes,
    required List<AgendaLine> tasks,
    required List<AgendaLine> exams,
    String? aiSummary,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _headerBanner(
            'Daily Agenda',
            '${userName.isEmpty ? 'Student' : userName}  -  '
                '${DateFormat('EEEE, d MMMM yyyy').format(date)}',
          ),
          if (aiSummary != null && aiSummary.trim().isNotEmpty) ...[
            _sectionTitle('AI summary'),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _tint,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _summaryWidgets(aiSummary),
              ),
            ),
          ],
          _sectionTitle("Today's classes"),
          _lines(classes, 'No classes scheduled today.'),
          _sectionTitle('Tasks & deadlines'),
          _lines(tasks, "No pending tasks - you're all caught up."),
          _sectionTitle('Upcoming exams'),
          _lines(exams, 'No exams on the horizon.'),
          _footer(),
        ],
      ),
    );
    await _writeAndShare(
        doc, 'ClassTrack_agenda_${DateFormat('yyyyMMdd').format(date)}.pdf');
  }

  // ── Last 7 days ──────────────────────────────────────────────────────────

  static Future<void> shareWeek({
    required String userName,
    required List<DaySection> days,
    required List<AgendaLine> tasks,
    required List<AgendaLine> exams,
    String? aiSummary,
  }) async {
    final doc = pw.Document();
    final start = days.isNotEmpty ? days.first.date : DateTime.now();
    final end = days.isNotEmpty ? days.last.date : DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _headerBanner(
            'Weekly Agenda',
            '${userName.isEmpty ? 'Student' : userName}  -  '
                '${DateFormat('d MMM').format(start)} - '
                '${DateFormat('d MMM yyyy').format(end)}',
          ),
          if (aiSummary != null && aiSummary.trim().isNotEmpty) ...[
            _sectionTitle('AI summary'),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _tint,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _summaryWidgets(aiSummary),
              ),
            ),
          ],
          _sectionTitle('Classes by day'),
          for (final d in days) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
              child: pw.Text(
                _ascii(DateFormat('EEEE, d MMM').format(d.date)),
                style: const pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6),
              child: _lines(d.classes, 'No classes.'),
            ),
          ],
          _sectionTitle('Pending tasks'),
          _lines(tasks, "No pending tasks - you're all caught up."),
          _sectionTitle('Upcoming exams'),
          _lines(exams, 'No exams on the horizon.'),
          _footer(),
        ],
      ),
    );
    await _writeAndShare(doc,
        'ClassTrack_week_${DateFormat('yyyyMMdd').format(end)}.pdf');
  }
}
