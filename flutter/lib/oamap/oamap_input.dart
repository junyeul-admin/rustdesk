// OAMap add-on 0001: soft keyboard text diff for composing IMEs (Korean Hangul,
// also Japanese / Chinese). Called from
// mobile/pages/remote_page.dart _handleNonIOSSoftKeyboardInput.
//
// Upstream diffs the hidden text field by length only. Composing IMEs replace
// the last character in place ("이" -> "인" -> "이주" -> "이준"), so same-length
// replacements were dropped and replacements were typed as new characters:
// "이준열" arrived as "이이이이이이". Diff by common prefix instead: delete what
// changed in the old value, type the new tail.
//
// Turn off at build time: --dart-define=OAMAP_HANGUL_INPUT=false

const bool kOamapHangulInput =
    bool.fromEnvironment('OAMAP_HANGUL_INPUT', defaultValue: true);

// Whatever is typed for the remote PC (passwords too) goes through the hidden
// field above; ask the phone keyboard not to learn it into its suggestion
// dictionary (Android IME_FLAG_NO_PERSONALIZED_LEARNING, "incognito" in
// Gboard). Input itself, Hangul composition included, is unchanged.
// Turn off at build time: --dart-define=OAMAP_IME_NO_LEARNING=false
const bool kOamapImeNoLearning =
    bool.fromEnvironment('OAMAP_IME_NO_LEARNING', defaultValue: true);

/// Sends the difference between [oldValue] and [newValue] of the hidden soft
/// keyboard field to the peer.
///
/// [back] sends one VK_BACK, [char] types one character (inputChar: maps
/// '\n' / ' ' to VK_RETURN / VK_SPACE), [string] types a string in one go
/// (sessionInputString).
void oamapSoftKeyboardDiff(
  String oldValue,
  String newValue, {
  required void Function() back,
  required void Function(String) char,
  required void Function(String) string,
}) {
  if (oldValue.isNotEmpty &&
      newValue.isNotEmpty &&
      oldValue[0] == '1' &&
      newValue[0] != '1') {
    // Same clipboard heuristic as upstream: the '1' * 1024 seed was replaced.
    oldValue = '';
  }
  var common = 0;
  for (;
      common < oldValue.length &&
          common < newValue.length &&
          oldValue[common] == newValue[common];
      ++common) {}
  // Never split a surrogate pair (emoji): back up to its first half.
  if (common > 0 &&
      (common < oldValue.length || common < newValue.length) &&
      (oldValue.codeUnitAt(common - 1) & 0xFC00) == 0xD800) {
    --common;
  }
  // One VK_BACK per character (code point) the host editor deletes.
  final removed = oldValue.substring(common).runes.length;
  final tail = newValue.substring(common);
  for (var k = 0; k < removed; ++k) {
    back();
  }
  if (tail.isEmpty) return;
  // Auto-paired punctuation ("()", "《》") needs no special case: the caret the
  // IME leaves inside the pair is handled by the prefix diff on the next edit,
  // "()" -> "(a)" sends VK_BACK + "a)".
  if (tail.length > 1) {
    string(tail);
  } else {
    char(tail);
  }
}
