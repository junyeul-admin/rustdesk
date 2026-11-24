// OAMap add-on 0002: [한/영] [한자] buttons in the mobile special-key bar
// (mobile/pages/remote_page.dart, KeyHelpTools modifiers row).
//
// KEY_MAP in src/client.rs already maps "VK_HANGUL" / "VK_HANJA" to
// ControlKey::Hangul / Hanja and the host presses them
// (src/server/input_service.rs). Hidden for macOS peers.
//
// Turn off at build time: --dart-define=OAMAP_IME_KEYS=false

import 'package:flutter/widgets.dart';

import '../models/input_model.dart';

const bool kOamapImeKeys =
    bool.fromEnvironment('OAMAP_IME_KEYS', defaultValue: true);

/// [wrap] is KeyHelpTools.wrap (text button in the key bar).
List<Widget> oamapImeKeys(
    Widget Function(String text, void Function() onPressed) wrap,
    InputModel inputModel,
    bool isMac) {
  if (!kOamapImeKeys || isMac) return const [];
  return [
    wrap('한/영', () => inputModel.inputKey('VK_HANGUL')),
    wrap('한자', () => inputModel.inputKey('VK_HANJA')),
  ];
}
