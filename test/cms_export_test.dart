import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/cms_export.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

void main() {
  group('buildResourcesCsv', () {
    test('emits a header and one row per resource', () {
      final csv = buildResourcesCsv(const [
        Resource(id: '1', type: ResourceType.scholarship, title: 'Alpha', organization: 'Org'),
        Resource(id: '2', type: ResourceType.internship, title: 'Beta', organization: 'Org'),
      ]);
      final lines = csv.split('\r\n');
      expect(lines.length, 3); // header + 2 rows
      expect(lines.first.startsWith('id,title,type,organization,'), isTrue);
      expect(lines[1].startsWith('1,Alpha,Scholarship,Org,'), isTrue);
    });

    test('RFC-4180 quotes fields with commas, quotes and newlines', () {
      final csv = buildResourcesCsv(const [
        Resource(
          id: '1',
          type: ResourceType.scholarship,
          title: 'He said "hi", ok',
          organization: 'Multi\nline',
        ),
      ]);
      final row = csv.split('\r\n')[1];
      // Quotes doubled, whole field wrapped; newline field wrapped too.
      expect(row.contains('"He said ""hi"", ok"'), isTrue);
      expect(row.contains('"Multi\nline"'), isTrue);
    });

    test('includes effective status column', () {
      final csv = buildResourcesCsv([
        Resource(
          id: '1',
          type: ResourceType.scholarship,
          title: 'T',
          organization: 'O',
          status: ResourceStatus.active,
          deadline: DateTime(2000, 1, 1), // past -> applications closed
        ),
      ]);
      expect(csv.contains('Applications closed'), isTrue);
    });

    test('neutralises CSV formula-injection in string cells', () {
      final csv = buildResourcesCsv(const [
        Resource(
          id: '1',
          type: ResourceType.scholarship,
          // A malicious title that Excel would otherwise execute as a formula.
          title: '=HYPERLINK("http://evil","click")',
          organization: '@SUM(A1:A9)',
        ),
      ]);
      final row = csv.split('\r\n')[1];
      // Both dangerous cells are prefixed with an apostrophe (then RFC-4180
      // quoted because they contain a comma / parens+quote).
      expect(row.contains("'=HYPERLINK"), isTrue);
      expect(row.contains("'@SUM(A1:A9)"), isTrue);
    });
  });
}
