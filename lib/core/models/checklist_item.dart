/// A single checkable item, reused by task subtasks and note checklists.
class ChecklistItem {
  final String text;
  final bool done;

  const ChecklistItem({required this.text, this.done = false});

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(text: text ?? this.text, done: done ?? this.done);

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        text: (map['text'] as String?) ?? '',
        done: (map['done'] as bool?) ?? false,
      );

  /// Parse a Firestore array into a list of items.
  static List<ChecklistItem> listFrom(dynamic raw) =>
      ((raw as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChecklistItem.fromMap)
          .toList();

  static List<Map<String, dynamic>> listToMap(List<ChecklistItem> items) =>
      items.map((e) => e.toMap()).toList();
}
