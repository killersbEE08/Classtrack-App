import 'package:classtrack/features/notes/domain/flashcard.dart';
import 'package:classtrack/features/notes/domain/note.dart';
import 'package:classtrack/features/notes/domain/note_attachment.dart';
import 'package:classtrack/features/notes/domain/note_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flashcard', () {
    test('round-trips through toMap/fromMap', () {
      const card = Flashcard(id: 'c1', question: 'Capital of France?', answer: 'Paris');
      final restored = Flashcard.fromMap(card.toMap());
      expect(restored.id, 'c1');
      expect(restored.question, 'Capital of France?');
      expect(restored.answer, 'Paris');
    });

    test('listFrom drops fully-empty cards', () {
      final list = Flashcard.listFrom([
        {'id': 'a', 'q': 'Q', 'a': 'A'},
        {'id': 'b', 'q': '', 'a': ''}, // empty → dropped
      ]);
      expect(list.length, 1);
      expect(list.first.id, 'a');
    });
  });

  group('NoteAttachment', () {
    test('image round-trips and reports type', () {
      const a = NoteAttachment(
        id: 'i1',
        type: NoteAttachmentType.image,
        url: 'https://example.com/p.jpg',
        storagePath: 'users/u1/noteAttachments/i1.jpg',
        name: 'p.jpg',
        sizeBytes: 2048,
      );
      final restored = NoteAttachment.fromMap(a.toMap());
      expect(restored.isImage, isTrue);
      expect(restored.isPdf, isFalse);
      expect(restored.storagePath, 'users/u1/noteAttachments/i1.jpg');
      expect(restored.prettySize, '2 KB');
    });

    test('pdf type parsed from name', () {
      final pdf = NoteAttachment.fromMap({
        'id': 'd1',
        'type': 'pdf',
        'url': 'https://example.com/d.pdf',
        'storagePath': 'users/u1/noteAttachments/d1.pdf',
        'name': 'd.pdf',
        'sizeBytes': 3 * 1024 * 1024,
      });
      expect(pdf.isPdf, isTrue);
      expect(pdf.prettySize, '3.0 MB');
    });

    test('listFrom skips entries without a url', () {
      final list = NoteAttachment.listFrom([
        {'id': 'ok', 'type': 'image', 'url': 'https://x/y.png'},
        {'id': 'bad', 'type': 'image', 'url': ''}, // no url → dropped
      ]);
      expect(list.length, 1);
      expect(list.first.id, 'ok');
    });
  });

  group('Note with flashcards + attachments', () {
    test('is not empty when it only has flashcards', () {
      const note = Note(
        id: 'n1',
        title: '',
        body: '',
        flashcards: [Flashcard(id: 'c', question: 'Q', answer: 'A')],
      );
      expect(note.isEmpty, isFalse);
      expect(note.hasFlashcards, isTrue);
      expect(note.flashcardCount, 1);
    });

    test('is not empty when it only has attachments', () {
      const note = Note(
        id: 'n2',
        title: '',
        body: '',
        attachments: [
          NoteAttachment(
            id: 'i',
            type: NoteAttachmentType.image,
            url: 'https://x/y.jpg',
            storagePath: 'p',
            name: 'y.jpg',
          ),
        ],
      );
      expect(note.isEmpty, isFalse);
      expect(note.imageAttachments.length, 1);
      expect(note.pdfAttachments, isEmpty);
    });

    test('serialization preserves flashcards and attachments', () {
      final note = Note(
        id: 'n3',
        title: 'Lecture 1',
        body: 'Intro',
        flashcards: const [Flashcard(id: 'c1', question: 'Q1', answer: 'A1')],
        attachments: const [
          NoteAttachment(
            id: 'd1',
            type: NoteAttachmentType.pdf,
            url: 'https://x/d.pdf',
            storagePath: 'users/u/noteAttachments/d1.pdf',
            name: 'd.pdf',
            sizeBytes: 1024,
          ),
        ],
        // Provide timestamps so toMap emits real Timestamps rather than the
        // FieldValue.serverTimestamp() sentinel (which Firestore resolves
        // server-side, but a direct in-memory round-trip cannot).
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );
      final map = note.toMap();
      final restored = Note.fromMap('n3', map);
      expect(restored.flashcards.length, 1);
      expect(restored.flashcards.first.answer, 'A1');
      expect(restored.attachments.length, 1);
      expect(restored.attachments.first.isPdf, isTrue);
      expect(restored.pdfAttachments.length, 1);
    });
  });

  group('SlashFormatting (/ insert menu)', () {
    test('stripSlash removes the trigger slash and reports its position', () {
      // "abc /" with slash at index 4.
      final r = SlashFormatting.stripSlash('abc /', 4, 5);
      expect(r.text, 'abc ');
      expect(r.pos, 4);
    });

    test('stripSlash falls back to cursor when there is no slash', () {
      final r = SlashFormatting.stripSlash('hello', -1, 3);
      expect(r.text, 'hello');
      expect(r.pos, 3);
    });

    test('linePrefix adds a heading marker at the start of the line', () {
      // Cursor at end of "Title" (pos 5) on the first line.
      final r = SlashFormatting.linePrefix('Title', 5, '# ');
      expect(r.text, '# Title');
      expect(r.cursor, 7); // pushed right by the 2-char prefix
    });

    test('linePrefix targets the current line in multi-line text', () {
      const base = 'first\nsecond';
      // pos 12 is at end of "second".
      final r = SlashFormatting.linePrefix(base, 12, '- ');
      expect(r.text, 'first\n- second');
    });

    test('linePrefix is idempotent when the prefix already exists', () {
      final r = SlashFormatting.linePrefix('# Title', 7, '# ');
      expect(r.text, '# Title');
      expect(r.cursor, 7);
    });

    test('insertBlock inserts a divider at the caret', () {
      final r = SlashFormatting.insertBlock('ab', 2, '\n---\n');
      expect(r.text, 'ab\n---\n');
      expect(r.cursor, 7);
    });
  });
}
