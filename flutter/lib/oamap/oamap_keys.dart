// OAMap add-on 0002: [한/영] [한자] buttons in the mobile special-key bar
// (mobile/pages/remote_page.dart, KeyHelpTools modifiers row).
//
// KEY_MAP in src/client.rs already maps "VK_HANGUL" / "VK_HANJA" to
// ControlKey::Hangul / Hanja and the host presses them
// (src/server/input_service.rs). Hidden for macOS peers.
//
// Turn off at build time: --dart-define=OAMAP_IME_KEYS=false
//
// OAMap add-on 0009: while the soft keyboard is open the key bar is one short
// row - [Ctrl+C] [Ctrl+V] [한/영] [Ctrl] [Alt] ... [⋯]. [⋯] opens the full upstream bar, its
// own [...] button comes back to the short row. Each time the keyboard opens
// the bar starts short again.
//
// Turn off at build time: --dart-define=OAMAP_COMPACT_BAR=false

import 'package:flutter/widgets.dart';

import '../models/input_model.dart';

const bool kOamapImeKeys =
    bool.fromEnvironment('OAMAP_IME_KEYS', defaultValue: true);

const bool kOamapCompactBar =
    bool.fromEnvironment('OAMAP_COMPACT_BAR', defaultValue: true);

/// [wrap] is KeyHelpTools.wrap (text button in the key bar).
List<Widget> oamapImeKeys(
    Widget Function(String text, void Function() onPressed) wrap,
    InputModel inputModel,
    bool isMac,
    {bool hangulOnly = false}) {
  if (!kOamapImeKeys || isMac) return const [];
  return [
    wrap('한/영', () => inputModel.inputKey('VK_HANGUL')),
    if (!hangulOnly) wrap('한자', () => inputModel.inputKey('VK_HANJA')),
  ];
}

/// The short row: copy, paste, IME key, modifiers on the left, [more] at the end.
Widget oamapCompactKeyRow({
  required Widget copy,
  required Widget paste,
  required Widget ctrl,
  required Widget alt,
  required List<Widget> imeKeys,
  required Widget more,
}) {
  const gap = SizedBox(width: 4);
  return Row(
    children: [
      copy,
      gap,
      paste,
      for (final k in imeKeys) ...[gap, k],
      gap,
      ctrl,
      gap,
      alt,
      const Spacer(),
      more,
    ],
  );
}
