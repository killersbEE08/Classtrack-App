/// Pure text transformations used by the note editor's "/" insert menu. Kept
/// free of Flutter/controller state so the behaviour can be unit-tested.
class SlashFormatting {
  const SlashFormatting._();

  /// Removes the '/' at [slashIndex] when present, returning the cleaned text
  /// and the caret position to work from. When there's no slash to strip
  /// (e.g. the menu was opened from the toolbar), returns [text] unchanged with
  /// [fallbackCursor].
  static ({String text, int pos}) stripSlash(
      String text, int slashIndex, int fallbackCursor) {
    if (slashIndex >= 0 &&
        slashIndex < text.length &&
        text[slashIndex] == '/') {
      return (
        text: text.replaceRange(slashIndex, slashIndex + 1, ''),
        pos: slashIndex,
      );
    }
    return (text: text, pos: fallbackCursor.clamp(0, text.length));
  }

  /// Ensures the line containing [pos] starts with [prefix] (e.g. '# ', '- ').
  /// Idempotent — an already-prefixed line is left unchanged.
  static ({String text, int cursor}) linePrefix(
      String base, int pos, String prefix) {
    final searchFrom = pos - 1;
    final nl = searchFrom >= 0 ? base.lastIndexOf('\n', searchFrom) : -1;
    final lineStart = nl + 1;
    final already = base.startsWith(prefix, lineStart);
    final text =
        already ? base : base.replaceRange(lineStart, lineStart, prefix);
    final cursor = already ? pos : pos + prefix.length;
    return (text: text, cursor: cursor.clamp(0, text.length));
  }

  /// Inserts a standalone [block] (e.g. a '\n---\n' divider) at [pos].
  static ({String text, int cursor}) insertBlock(
      String base, int pos, String block) {
    final text = base.replaceRange(pos, pos, block);
    return (text: text, cursor: (pos + block.length).clamp(0, text.length));
  }
}
