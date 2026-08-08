/// Reusable form-field validators.
///
/// Centralising these keeps validation identical wherever a field appears and
/// makes the rules unit-testable without spinning up any widgets.
class Validators {
  Validators._();

  /// Minimum length for NEW account passwords.
  static const int minPasswordLength = 8;

  /// Human-readable summary of the password policy, shown as helper text so the
  /// requirement is communicated up front rather than only after a failure.
  static const String passwordPolicyHint =
      'At least 8 characters, including letters and numbers';

  /// Sign-up password policy: at least [minPasswordLength] characters and a mix
  /// of letters AND numbers. Returns null when valid, otherwise a short message
  /// suitable for a [TextFormField] validator.
  ///
  /// This is intentionally only used when CREATING a password (sign-up / change
  /// password) — sign-in must never re-check it, or existing users with older,
  /// weaker passwords would be locked out.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'[0-9]').hasMatch(v);
    if (!hasLetter || !hasDigit) {
      return 'Include both letters and numbers';
    }
    return null;
  }

  /// Permissive email check. Firebase Auth performs the authoritative
  /// validation server-side; this just catches obvious typos before a network
  /// round-trip. Requires text@domain.tld with no spaces.
  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'Enter a valid email';
  }

  /// Non-empty display name that can't be used to smuggle markup.
  ///
  /// Rejects names containing angle brackets so a user can't set their name to
  /// something like `<b style="color:red;">Alert</b>` — a stored-HTML / XSS
  /// probe that could render/execute on any HTML surface (web build, emails,
  /// exported documents). The authoritative defence is [sanitizeName] applied
  /// on write + read; this just gives immediate feedback in the form.
  static String? name(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Enter your name';
    if (RegExp(r'[<>]').hasMatch(raw)) {
      return 'Name can’t contain the characters < or >';
    }
    if (sanitizeName(raw).isEmpty) return 'Enter a valid name';
    return null;
  }

  /// Strips HTML tags, angle brackets and control characters from a
  /// user-provided display name, collapses whitespace and caps the length.
  /// Applied wherever a name is written to or read from storage so neither new
  /// input nor previously-stored payloads can inject markup downstream.
  static String sanitizeName(String? input) {
    var s = (input ?? '').trim();
    if (s.isEmpty) return s;
    s = s.replaceAll(RegExp(r'<[^>]*>'), ''); // remove <...> tags
    s = s.replaceAll(RegExp(r'[<>]'), ''); // remove stray angle brackets
    s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ''); // control chars
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim(); // collapse whitespace
    if (s.length > 60) s = s.substring(0, 60).trim();
    return s;
  }

  /// Neutralises injected HTML in free-text CONTENT fields (titles, notes,
  /// bodies) while preserving legitimate text.
  ///
  /// Unlike [sanitizeName] this is deliberately gentle: it removes only
  /// complete HTML tags (e.g. `<b>`, `</b>`, `<script …>`) and control
  /// characters — it does NOT strip a lone `<` or `>`, so genuine content like
  /// "if x < 0" survives. When [multiline] is true, line breaks are preserved
  /// (for note bodies); otherwise all whitespace is collapsed to single spaces
  /// (for single-line titles). [maxLength], when given, caps the result — pass
  /// it only for short fields so long notes are never truncated.
  static String sanitizeText(String? input,
      {bool multiline = false, int? maxLength}) {
    var s = input ?? '';
    if (s.isEmpty) return s;
    // Strip complete HTML/XML tags: a '<', one or more non-'>' chars, then '>'.
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    if (multiline) {
      s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      // Remove control chars EXCEPT tab (\u0009) and newline (\u000A).
      s = s.replaceAll(
          RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '');
      // Trim trailing spaces per line and collapse 3+ blank lines to 2.
      s = s
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'[ \t]+$'), ''))
          .join('\n');
      s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    } else {
      s = s.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (maxLength != null && s.length > maxLength) {
      s = s.substring(0, maxLength).trim();
    }
    return s;
  }
}
