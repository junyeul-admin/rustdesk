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
// row - [Ctrl+C] [Ctrl+V] [Win] [Ctrl] [Alt] ... [⋯]. [⋯] shows / hides a
// second row with the arrow keys. Each time the keyboard opens the bar starts
// with one row again.
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

/// The short row: [keys] on the left (scroll sideways on a narrow phone),
/// [more] at the end; [extra] (arrow keys) as a second row when shown.
Widget oamapCompactKeyRow({
  required List<Widget> keys,
  required Widget more,
  List<Widget>? extra,
}) {
  const gap = SizedBox(width: 4);
  Widget line(List<Widget> ks) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < ks.length; i++) ...[
              if (i > 0) gap,
              ks[i],
            ],
          ],
        ),
      );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: line(keys)),
          gap,
          more,
        ],
      ),
      if (extra != null) ...[const SizedBox(height: 4), line(extra)],
    ],
  );
}
