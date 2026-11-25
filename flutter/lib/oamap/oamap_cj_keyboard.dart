// OAMap 천지인 자판 — 앱 안에서 한글·영문·숫자를 모두 받는다(폰 자판을 거치지 않음)
//   사장님 11/26: [한/영]·[!#1] 은 폰 자판을 부르지 말고 '이 자판 안에서' 바뀌어야 한다.
//   그래야 폰 자판이 같이 보내던 숫자 신호('안녕하8요')가 아예 생기지 않는다.
//   보내기는 이 파일이 하지 않는다 — onSend(지우기 수, 글자) · onEnter() 로 넘긴다(시험이 쉽게 돌도록).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'oamap_cheonjiin.dart';
import 'oamap_cj_send.dart';

typedef CjSendCb = void Function(int back, String text);

/// 자판의 판 — 한글(천지인) · 영문(쿼티) · 숫자와 기호
enum CjLayer { ko, en, sym }

class OamapCjKeyboard extends StatefulWidget {
  final CjSendCb onSend;          // 원격으로 보낼 거리(지우기 수 · 글자)
  final VoidCallback? onEnter;    // 줄바꿈은 글자가 아니라 키로 보낸다
  final VoidCallback? onPhoneIme; // 폰 자판을 부르는 길(이제 숨은 단추로만)
  final bool preview;             // 조합 중 글자를 미리 보여 줄지(설정)
  final double keyHeight;
  const OamapCjKeyboard({
    super.key,
    required this.onSend,
    this.onEnter,
    this.onPhoneIme,
    this.preview = true,
    this.keyHeight = 46,
  });

  @override
  State<OamapCjKeyboard> createState() => _OamapCjKeyboardState();
}

class _OamapCjKeyboardState extends State<OamapCjKeyboard> {
  late final CjEcho _echo = CjEcho(preview: widget.preview);
  CjState _st = CjState();
  Timer? _repeat;        // ⌫ 꾹 누름
  Timer? _hold;          // 꾹 누르기 재기
  bool _held = false;    // 이번 누름이 '꾹'으로 끝났는가(그러면 탭은 버린다)
  CjLayer _layer = CjLayer.ko;
  bool _shift = false;   // 영문 대문자

  @override
  void didUpdateWidget(covariant OamapCjKeyboard old) {
    super.didUpdateWidget(old);
    if (old.preview != widget.preview) _echo.preview = widget.preview;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _emit(CjOut o) {
    if (!o.handled) {
      // 우리가 처리하지 않는 것(조합이 빈 채로 ⌫) = 원격에 그대로 지우기 하나
      widget.onSend(1, '');
      return;
    }
    final s = _echo.step(o.commit, o.preview);
    setState(() => _st = o.state);
    if (!s.isEmpty) widget.onSend(s.back, s.text);
  }

  // 글쇠 한 번 — 되풀이 타이머는 건드리지 않는다(⌫ 꾹 누름이 스스로를 끄지 않게)
  void _press(CjKey k) {
    if (k == CjKey.enter) { _pressEnter(); return; }
    _emit(cjPress(_st, k));
  }

  void _tap(CjKey k) {
    _stopRepeat();
    _press(k);
  }

  // ↵ — 조합 중이던 글자를 먼저 굳혀 보내고, 줄바꿈은 글자가 아니라 키로 보낸다
  //   (글자로 '\n' 을 보내면 PC 쪽 프로그램에 따라 줄이 안 바뀐다)
  void _pressEnter() {
    final o = cjPress(_st, CjKey.enter);
    final done = o.commit.endsWith('\n')
        ? o.commit.substring(0, o.commit.length - 1)
        : o.commit;
    final s = _echo.step(done, '');
    setState(() => _st = o.state);
    if (!s.isEmpty) widget.onSend(s.back, s.text);
    widget.onEnter?.call();
  }

  /// 한글이 아닌 글자(영문·숫자·기호) — 조합 중이던 글자를 굳히고 그 뒤에 붙인다
  void _text(String ch) {
    _stopRepeat();
    final s = _echo.step(cjCompose(_st) + ch, '');
    setState(() => _st = CjState());
    if (!s.isEmpty) widget.onSend(s.back, s.text);
  }

  /// 판을 바꾼다 — 조합 중이던 글자는 먼저 굳힌다(판이 바뀌며 글자가 깨지지 않게)
  void _go(CjLayer to) {
    _stopRepeat();
    final done = cjCompose(_st);
    if (done.isNotEmpty) {
      final s = _echo.step(done, '');
      if (!s.isEmpty) widget.onSend(s.back, s.text);
    }
    setState(() {
      _st = CjState();
      _layer = to;
      _shift = false;
    });
  }

  // 꾹 누르기 — 안드로이드 기본(0.5초)은 글자를 치다 손가락이 머물면 걸려서
  //   '안4' 처럼 숫자가 섞였다. 사장님 11/26: 넉넉히 1초.
  static const int holdMs = 1000;

  void _downKey(VoidCallback? onHold) {
    _held = false;
    _hold?.cancel();
    if (onHold == null) { _hold = null; return; }
    _hold = Timer(const Duration(milliseconds: holdMs), () {
      _held = true;
      onHold();
    });
  }

  void _upKey() {
    _hold?.cancel();
    _hold = null;
    _stopRepeat();
  }

  /// 꾹 눌러 숫자 — 조합 중이던 글자를 굳히고 그 뒤에 숫자를 붙인다
  void _holdDigit(CjKey k) {
    final d = cjDigit[k];
    if (d == null) return;
    _text(d);
  }

  // ⌫ 꾹 누름 — 꾹 누르기가 걸린 그때 한 번, 그 뒤 빠르게 되풀이
  void _startRepeat() {
    _repeat?.cancel();
    _press(CjKey.back);
    _repeat = Timer.periodic(
        const Duration(milliseconds: 90), (_) => _press(CjKey.back));
  }

  void _stopRepeat() { _repeat?.cancel(); _repeat = null; }

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Widget _box({
    required String label,
    required VoidCallback onTap,
    VoidCallback? onHold,   // 1초 꾹 눌렀을 때
    String? digit,          // 오른쪽 위 작은 숫자
    bool fn = false,
    bool on = false,
    int flex = 1,
    double size = 17,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Listener(
          onPointerDown: (_) => _downKey(onHold),
          onPointerUp: (_) => _upKey(),
          onPointerCancel: (_) => _upKey(),
          child: GestureDetector(
            onTap: () {
              if (_held) { _held = false; return; }   // 꾹 누름으로 끝난 것은 버린다
              onTap();
            },
            child: Container(
              height: widget.keyHeight,
              decoration: BoxDecoration(
                color: on
                    ? const Color(0xFF3478F6)
                    : (fn
                        ? (_dark ? const Color(0xFF2C2C2E) : const Color(0xFFD8D8DC))
                        : (_dark ? const Color(0xFF3A3A3C) : Colors.white)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Stack(children: [
                Center(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: size,
                        color: on
                            ? Colors.white
                            : (_dark ? Colors.white : const Color(0xFF1C1C1E)),
                      )),
                ),
                if (digit != null)
                  Positioned(
                    right: 6,
                    top: 3,
                    child: Text(digit,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9A9AA0))),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // 천지인 글쇠 — 오른쪽 위에 숫자를 보이고, 1초 꾹 누르면 그 숫자가 들어간다
  Widget _cj(String label, CjKey k, {bool fn = false, int flex = 1}) => _box(
        label: label,
        onTap: () => _tap(k),
        onHold: cjDigit.containsKey(k) ? () => _holdDigit(k) : null,
        digit: cjDigit[k],
        fn: fn,
        flex: flex,
        size: fn ? 14 : 17,
      );

  Widget _ch(String ch, {int flex = 1, double size = 16}) =>
      _box(label: ch, onTap: () => _text(ch), flex: flex, size: size);

  Widget _fn(String label, VoidCallback onTap, {int flex = 1, bool on = false}) =>
      _box(label: label, onTap: onTap, fn: true, on: on, flex: flex, size: 13);

  Widget _back() => _box(
        label: '⌫',
        onTap: () => _tap(CjKey.back),
        onHold: _startRepeat,
        fn: true,
        size: 14,
      );

  Widget _enter({int flex = 1}) =>
      _box(label: '↵', onTap: () => _tap(CjKey.enter), fn: true, flex: flex, size: 14);

  Widget _space({int flex = 3}) => _layer == CjLayer.ko
      ? _box(label: '␣', onTap: () => _tap(CjKey.space), fn: true, flex: flex, size: 14)
      : _box(label: '␣', onTap: () => _text(' '), fn: true, flex: flex, size: 14);

  List<Widget> _rowOf(String s) =>
      s.split('').map((c) => _ch(_shift ? c.toUpperCase() : c)).toList();

  // ── 한글(천지인) — 삼성과 같은 자리
  List<Widget> _ko() => [
        Row(children: [
          _cj('ㅣ', CjKey.ii), _cj('·', CjKey.dot), _cj('ㅡ', CjKey.eu), _back(),
        ]),
        Row(children: [
          _cj('ㄱㅋ', CjKey.gk), _cj('ㄴㄹ', CjKey.nr), _cj('ㄷㅌ', CjKey.dt), _enter(),
        ]),
        Row(children: [
          _cj('ㅂㅍ', CjKey.bp), _cj('ㅅㅎ', CjKey.sh), _cj('ㅈㅊ', CjKey.jc),
          _box(label: '.,?!', onTap: () => _text('.'), fn: true, size: 13),
        ]),
        Row(children: [
          _fn('!#1', () => _go(CjLayer.sym), flex: 3),
          _fn('한/영', () => _go(CjLayer.en), flex: 2),
          _cj('ㅇㅁ', CjKey.om, flex: 3),
          _space(flex: 3),
          _ch('\$', flex: 2),
        ]),
      ];

  // ── 영문(쿼티)
  List<Widget> _en() => [
        Row(children: _rowOf('qwertyuiop')),
        Row(children: [
          const Spacer(flex: 1),
          ..._rowOf('asdfghjkl').map((w) => w),
          const Spacer(flex: 1),
        ]),
        Row(children: [
          _fn(_shift ? '⇧' : '⇪', () => setState(() => _shift = !_shift),
              flex: 2, on: _shift),
          ..._rowOf('zxcvbnm'),
          _back(),
        ]),
        Row(children: [
          _fn('!#1', () => _go(CjLayer.sym), flex: 3),
          _fn('한/영', () => _go(CjLayer.ko), flex: 2),
          _space(flex: 6),
          _ch('.', flex: 2),
          _enter(flex: 2),
        ]),
      ];

  // ── 숫자와 기호
  List<Widget> _sym() => [
        Row(children: _rowOf('1234567890')),
        Row(children: _rowOf('-/:;()₩&@')),
        Row(children: [
          _ch('.', flex: 2), ..._rowOf(',?!\'"*#%'), _back(),
        ]),
        Row(children: [
          _fn('가나다', () => _go(CjLayer.ko), flex: 3),
          _fn('ABC', () => _go(CjLayer.en), flex: 2),
          _space(flex: 6),
          _ch('+', flex: 2),
          _enter(flex: 2),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final rows = _layer == CjLayer.ko
        ? _ko()
        : (_layer == CjLayer.en ? _en() : _sym());
    return Container(
      color: _dark ? const Color(0xFF1C1C1E) : const Color(0xFFE3E3E8),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
