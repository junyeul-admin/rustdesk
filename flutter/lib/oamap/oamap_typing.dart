// OAMap add-on 0008: phone keyboard lag while typing Hangul.
//
// Field report (Samsung keyboard, Cheonjiin): English typed fast is fine, but
// Hangul multi-tap (ㄱ x2 = ㅋ, x3 = ㄲ) and long-press (ㄱ held = 4) are
// misread while connected: the keyboard waits on the app, the app is busy
// drawing the remote screen, so taps are taken late.
//
// Two switches (Settings > OAMap), both read when the keyboard opens:
//  1. Lower the remote frame rate while the soft keyboard is open
//     (default on). Temporary only: the per-peer 'custom-fps' setting is put
//     back right away, and the old rate is sent again when the keyboard closes.
//  2. Short hidden-field seed (default on): 31 '1's and a tab instead of
//     1024 '1's. Screen recording: the Samsung keyboard shows "1111111111..."
//     in its suggestion strip, i.e. it treats the whole 1024-character seed
//     plus the typed text as the current word and runs prediction over it on
//     every tap. The tab ends that word, so the keyboard only looks at what
//     is typed after it (a tab, not a space or a new line: no double-space period, no auto capital). The prefix diff (oamap_input.dart) is unchanged: the
//     seed still starts with '1' (paste heuristic) and every seed character
//     deleted is one VK_BACK, as before. Once the seed is used up, Backspace
//     on the empty field goes by the key event route as upstream already
//     does.
//
// Turn off at build time: --dart-define=OAMAP_TYPING_TUNE=false

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../models/model.dart';
import '../models/platform_model.dart';
import 'oamap_cj_panel.dart';
import 'oamap_cursor.dart';
import 'oamap_input.dart';

const bool kOamapTypingTune =
    bool.fromEnvironment('OAMAP_TYPING_TUNE', defaultValue: true);

const String kOamapTypingLowFpsKey = 'oamap-typing-low-fps';
const String kOamapShortSeedKey = 'oamap-short-seed';
const String kOamapCommitOnlyKey = 'oamap-commit-only'; // OAMap 0012
const int kOamapTypingFps = 10;

bool _oamapOpt(String key, bool def) {
  final v = bind.mainGetLocalOption(key: key);
  if (v == 'Y') return true;
  if (v == 'N') return false;
  return def;
}

bool get oamapTypingLowFps =>
    kOamapTypingTune && _oamapOpt(kOamapTypingLowFpsKey, true);
bool get oamapCommitOnly =>
    kOamapCommitOnlyDefault && _oamapOpt(kOamapCommitOnlyKey, false); // OAMap 0013: default off (real cause was the key event)
bool get oamapShortSeed =>
    kOamapTypingTune && _oamapOpt(kOamapShortSeedKey, true);

/// Seed of the hidden soft keyboard field (remote_page.dart initText).
String oamapSeed() => oamapShortSeed ? '${'1' * 31}\t' : '1' * 1024;

/// remote_page onSoftKeyboardChanged -> lower / restore the frame rate.
/// Calls are queued so a quick open/close cannot leave the low rate behind.
class OamapTypingFps {
  final FFI ffi;
  bool _low = false;
  String _saved = '';
  Future<void> _queue = Future.value();

  OamapTypingFps(this.ffi);

  void onKeyboard(bool open) {
    _queue = _queue.then((_) => _apply(open)).catchError((e) {
      debugPrint('OAMap typing fps: $e');
    });
  }

  Future<void> _apply(bool open) async {
    final sid = ffi.sessionId;
    if (open) {
      if (_low || !oamapTypingLowFps) return;
      final saved =
          await bind.sessionGetOption(sessionId: sid, arg: 'custom-fps') ?? '';
      final cur = int.tryParse(saved) ?? 30;
      if (cur <= kOamapTypingFps) return;
      _saved = saved;
      _low = true;
      await bind.sessionSetCustomFps(sessionId: sid, fps: kOamapTypingFps);
      // sessionSetCustomFps also saves the value for this peer; put it back.
      await bind.sessionPeerOption(
          sessionId: sid, name: 'custom-fps', value: _saved);
    } else {
      if (!_low) return;
      _low = false;
      final cur = int.tryParse(_saved) ?? 30;
      await bind.sessionSetCustomFps(sessionId: sid, fps: cur);
      await bind.sessionPeerOption(
          sessionId: sid, name: 'custom-fps', value: _saved);
    }
  }
}

/// Settings > OAMap: the two switches above.
AbstractSettingsSection oamapTypingSettingsSection(VoidCallback refresh) {
  Future<void> save(String key, bool v) async {
    await bind.mainSetLocalOption(key: key, value: v ? 'Y' : 'N');
    refresh();
  }

  return SettingsSection(
    title: const Text('OAMap'),
    tiles: [
      // OAMap 0017: 앱 안 천지인 자판
      if (kOamapCheonjiin)
        SettingsTile.switchTile(
          title: const Text('천지인 자판 쓰기(앱 안에서 한글 치기)'),
          initialValue: oamapCjOn,
          onToggle: (v) => save(kOamapCjOnKey, v),
        ),
      if (kOamapCheonjiin && oamapCjOn)
        SettingsTile.switchTile(
          title: const Text('치는 글자를 한 글자씩 바로 보여 주기'),
          initialValue: oamapCjPreview,
          onToggle: (v) => save(kOamapCjPreviewKey, v),
        ),
      SettingsTile.switchTile(
        title: const Text('자판 열면 화면 속도 낮춤(한글 입력 빠르게)'),
        initialValue: oamapTypingLowFps,
        onToggle: (v) => save(kOamapTypingLowFpsKey, v),
      ),
      SettingsTile.switchTile(
        title: const Text('완성된 글자만 보내기(한글 오타 줄이기)'),
        initialValue: oamapCommitOnly,
        onToggle: (v) => save(kOamapCommitOnlyKey, v),
      ),
      SettingsTile.switchTile(
        title: const Text('숨은 입력칸 짧게(한글 오타 줄이기)'),
        initialValue: oamapShortSeed,
        onToggle: (v) => save(kOamapShortSeedKey, v),
      ),
      if (kOamapCursorPlus)
        SettingsTile(
          title: const Text('원격 마우스 포인터 크기'),
          value: Text(oamapCursorScale == 1.0
              ? '1배'
              : (oamapCursorScale == 2.0 ? '2배' : '1.5배')),
          onPressed: (context) async {
            final i = kOamapCursorScales.indexOf(oamapCursorScale);
            final next = kOamapCursorScales[(i + 1) % kOamapCursorScales.length];
            await bind.mainSetLocalOption(
                key: kOamapCursorScaleKey, value: next.toString());
            refresh();
          },
        ),
    ],
  );
}
