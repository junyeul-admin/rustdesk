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

import 'dart:async';

import 'package:flutter/services.dart';

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

// OAMap add-on 0012: send only finished syllables.
//
// Field report: Samsung Cheonjiin "안녕하세요" always arrived as "안녕하8요"
// while the remote PC's own Korean IME was in Hangul mode. The prefix diff
// above sent every intermediate composing state (ㅅ, ㅅᆞ, 서, 세 ...) as
// typed characters plus VK_BACK, and the PC's IME mixed some of them up.
// Now the text inside the composing range (the syllable still being built) is
// held back; it is sent once it is committed (next syllable, space, enter),
// after [idle] without a change, or when the keyboard closes (flush).
// Turn off in Settings > OAMap (or --dart-define=OAMAP_COMMIT_ONLY=false).
const bool kOamapCommitOnlyDefault =
    bool.fromEnvironment('OAMAP_COMMIT_ONLY', defaultValue: true);

class OamapComposeSender {
  OamapComposeSender(String seed, {this.idle = const Duration(milliseconds: 800)})
      : _sent = seed,
        _latest = seed;

  final Duration idle;
  String _sent;
  String _latest;
  Timer? _timer;
  void Function(String oldValue, String newValue)? _send;

  String get sent => _sent;

  void reset(String seed) {
    _timer?.cancel();
    _timer = null;
    _sent = seed;
    _latest = seed;
  }

  /// [value] = controller value at onChanged time (text + composing range).
  void handle(TextEditingValue value, String newValue, bool commitOnly,
      void Function(String oldValue, String newValue) send) {
    _send = send;
    _latest = newValue;
    _timer?.cancel();
    _timer = null;
    var target = newValue;
    final c = value.composing;
    if (commitOnly &&
        value.text == newValue &&
        c.isValid &&
        !c.isCollapsed &&
        c.start >= 0 &&
        c.end == newValue.length) {
      target = newValue.substring(0, c.start);
      _timer = Timer(idle, flush);
    }
    _emit(target);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    _emit(_latest);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit(String target) {
    final send = _send;
    if (send == null || target == _sent) return;
    final old = _sent;
    _sent = target;
    send(old, target);
  }
}
