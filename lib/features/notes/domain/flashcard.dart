/// A single flashcard (question ⇄ answer) belonging to a note. Stored inline
/// in the note document's `flashcards` array so a lecture note carries its own
/// study deck.
class Flashcard {
  final String id;
  final String question;
  final String answer;

  const Flashcard({
    required this.id,
    required this.question,
    required this.answer,
  });

  bool get isEmpty => question.trim().isEmpty && answer.trim().isEmpty;

  Flashcard copyWith({String? question, String? answer}) => Flashcard(
        id: id,
        question: question ?? this.question,
        answer: answer ?? this.answer,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'q': question,
        'a': answer,
      };

  factory Flashcard.fromMap(Map<String, dynamic> map) => Flashcard(
        id: (map['id'] as String?) ?? '',
        question: (map['q'] as String?) ?? '',
        answer: (map['a'] as String?) ?? '',
      );

  /// Parse a Firestore array into a list of cards (skips fully-empty ones).
  static List<Flashcard> listFrom(dynamic raw) =>
      ((raw as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Flashcard.fromMap)
          .where((c) => !c.isEmpty)
          .toList();

  static List<Map<String, dynamic>> listToMap(List<Flashcard> cards) =>
      cards.map((e) => e.toMap()).toList();
}
