import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/ics_exporter.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../schedule/domain/class_session.dart';
import '../../subjects/domain/subject.dart';

/// Builds and shares schedule/attendance exports.
class ExportService {
  ExportService._();

  /// Row of attendance summary data for one subject.
  static List<List<dynamic>> _summaryRows(
    List<Subject> subjects,
    Map<String, AttendanceStats> statsBySubject,
  ) {
    final rows = <List<dynamic>>[
      ['Subject', 'Present', 'Absent', 'Cancelled', 'Held', 'Attendance %'],
    ];
    for (final s in subjects) {
      final st = statsBySubject[s.id] ?? const AttendanceStats();
      rows.add([
        s.name,
        st.present,
        st.absent,
        st.cancelled,
        st.held,
        st.held == 0 ? '—' : st.percent.toStringAsFixed(1),
      ]);
    }
    return rows;
  }

  static Future<File> _write(String fileName, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> _writeString(String fileName, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return file;
  }

  // ---------------- ICS ----------------
  static Future<void> shareIcs({
    required List<Subject> subjects,
    required Map<String, List<ClassSession>> sessionsBySubject,
    required DateTime semesterStart,
    required DateTime semesterEnd,
  }) async {
    final ics = IcsExporter.build(
      subjects: subjects,
      sessionsBySubject: sessionsBySubject,
      semesterStart: semesterStart,
      semesterEnd: semesterEnd,
    );
    final file = await _writeString(IcsExporter.fileName(), ics);
    await Share.shareXFiles([XFile(file.path)],
        subject: 'ClassTrack schedule');
  }

  // ---------------- CSV ----------------
  static Future<void> shareCsv({
    required List<Subject> subjects,
    required Map<String, AttendanceStats> statsBySubject,
  }) async {
    final csv = const ListToCsvConverter()
        .convert(_summaryRows(subjects, statsBySubject));
    final name =
        'ClassTrack_attendance_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final file = await _writeString(name, csv);
    await Share.shareXFiles([XFile(file.path)],
        subject: 'ClassTrack attendance summary');
  }

  // ---------------- PDF ----------------
  static Future<void> sharePdf({
    required String userName,
    required List<Subject> subjects,
    required Map<String, AttendanceStats> statsBySubject,
    required double target,
  }) async {
    final doc = pw.Document();
    final rows = _summaryRows(subjects, statsBySubject);

    // overall
    var total = const AttendanceStats();
    for (final s in subjects) {
      total = total + (statsBySubject[s.id] ?? const AttendanceStats());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ClassTrack — Attendance Summary',
                    style: const pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$userName · Generated ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Overall attendance',
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  total.held == 0
                      ? '—'
                      : '${total.percent.toStringAsFixed(1)}%  (target ${target.toStringAsFixed(0)}%)',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: total.percent >= target
                        ? PdfColors.green800
                        : PdfColors.red800,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: rows.first.map((e) => e.toString()).toList(),
            data: rows
                .skip(1)
                .map((r) => r.map((e) => e.toString()).toList())
                .toList(),
            headerStyle: const pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.indigo),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final name =
        'ClassTrack_attendance_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file = await _write(name, bytes);
    await Share.shareXFiles([XFile(file.path)],
        subject: 'ClassTrack attendance summary');
  }
}
