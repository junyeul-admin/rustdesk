// OAMap add-on 0017: 천지인 자판을 앱 안에 둔다(폰 자판을 거치지 않음)
//   까닭 ①: 폰 자판의 'ㅅㅎ' 키가 숫자 8 을 같이 보내 '안녕하8요' 가 되던 일이 아예 없어진다.
//   까닭 ②: 조합 중인 글자를 우리가 알고 있으므로 한 글자씩 원격 화면에 미리 보여 줄 수 있다.
//   한글은 이 자판 · 영문·특수문자·음성은 폰 자판([!#1] [한/영] [$] 로 오감).
//
// 설정 > OAMap: '천지인 자판 쓰기' · '조합 중 글자 미리 보여 주기'
// 통째로 끄기(빌드 때): --dart-define=OAMAP_CHEONJIIN=false
library;

import 'package:flutter/material.dart';

import '../models/model.dart';
import '../models/platform_model.dart';
import 'oamap_cheonjiin.dart';
import 'oamap_cj_bridge.dart';
import 'oamap_cj_keyboard.dart';

const bool kOamapCheonjiin =
    bool.fromEnvironment('OAMAP_CHEONJIIN', defaultValue: true);

const String kOamapCjOnKey = 'oamap-cj-on';
const String kOamapCjPreviewKey = 'oamap-cj-preview';
const String kOamapCjCycleKey = 'oamap-cj-cycle';

/// 같은 글쇠를 다시 눌러 글자를 바꿀 수 있는 시간 — 빠르게 / 보통 / 느리게
///   짧으면 'ㅅㅅ'(ㅎ)을 재게 눌러야 하고, 길면 '안녕'처럼 같은 글쇠로 새 글자를 시작할 때 더 쉬어야 한다.
const Map<String, int> kOamapCjCycles = {'빠르게': 600, '보통': 900, '느리게': 1300};

bool _yes(String key) => bind.mainGetLocalOption(key: key) != 'N';

/// 자판 단추를 눌렀을 때 천지인 자판을 띄울지(끄면 예전처럼 폰 자판)
bool get oamapCjOn => kOamapCheonjiin && _yes(kOamapCjOnKey);

/// 조합 중인 글자를 원격 화면에 미리 보여 줄지
///   끄면 다 된 글자만 보낸다 — 명령 창처럼 지우기가 어색한 곳에서 쓴다.
bool get oamapCjPreview => _yes(kOamapCjPreviewKey);

/// 설정에서 고른 '다시 누르기' 시간(밀리초) — 안 골랐으면 보통
int get oamapCjCycleMs {
  final v = int.tryParse(bind.mainGetLocalOption(key: kOamapCjCycleKey));
  return (v != null && kOamapCjCycles.containsValue(v)) ? v : cjCycleMs;
}

/// 지금 고른 값의 이름('보통' 등)
String get oamapCjCycleName {
  final ms = oamapCjCycleMs;
  for (final e in kOamapCjCycles.entries) {
    if (e.value == ms) return e.key;
  }
  return '보통';
}

/// 화면 바닥에 붙는 천지인 자판 — 누를 때마다 원격으로 바로 보낸다.
class OamapCjPanel extends StatelessWidget {
  final FFI ffi;
  final VoidCallback onPhoneIme; // 폰 자판으로 오감
  final VoidCallback onClose;
  const OamapCjPanel({
    super.key,
    required this.ffi,
    required this.onPhoneIme,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFE3E3E8),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 머리 줄 — 무엇인지 알리고 닫는 자리
          SizedBox(
            height: 30,
            child: Row(children: [
              const SizedBox(width: 12),
              Text('천지인',
                  style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.white70 : Colors.black54)),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
                icon: Icon(Icons.keyboard_hide,
                    size: 18, color: dark ? Colors.white70 : Colors.black54),
                onPressed: onClose,
              ),
              const SizedBox(width: 6),
            ]),
          ),
          OamapCjKeyboard(
            preview: oamapCjPreview,
            cycleMs: oamapCjCycleMs,
            onPhoneIme: onPhoneIme,
            onSend: (back, text) => oamapCjSendToRemote(
              inputModel: ffi.inputModel,
              sessionId: ffi.sessionId,
              back: back,
              text: text,
            ),
          ),
        ]),
      ),
    );
  }
}
