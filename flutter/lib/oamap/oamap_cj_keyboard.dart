// OAMap 천지인 자판 — 앱 안에서 한글을 직접 받는다(삼성·구글 자판을 거치지 않음)
//   1번 안(사장님 11/25): 한글 치기 + 길게 눌러 숫자 + ⌫ 길게 눌러 연달아 지우기까지.
//   영문·특수문자·음성은 폰 자판으로 오간다([가나다/ABC] 단추).
//   보내기는 이 파일이 하지 않는다 — onSend(지우기 수, 글자) 로 넘긴다(시험이 쉽게 돌도록).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'oamap_cheonjiin.dart';
import 'oamap_cj_send.dart';

typedef CjSendCb = void Function(int back, String text);

class OamapCjKeyboard extends StatefulWidget {
  final CjSendCb onSend;          // 원격으로 보낼 거리(지우기 수 · 글자)
  final VoidCallback? onPhoneIme; // [가나다/ABC] — 폰 자판으로 오감
  final bool preview;             // 조합 중 글자를 미리 보여 줄지(설정)
  final double keyHeight;
  const OamapCjKeyboard({
    super.key,
    required this.onSend,
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
  Timer? _repeat;   // ⌫ 길게 누르기

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

  void _tap(CjKey k) {
    _stopRepeat();
    _emit(cjPress(_st, k, nowMs: DateTime.now().millisecondsSinceEpoch));
  }

  void _long(CjKey k) {
    if (k == CjKey.back) { _startRepeat(); return; }
    final o = cjLongPress(_st, k);
    if (o.handled) _emit(o);
  }

  void _startRepeat() {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) => _tap(CjKey.back));
  }

  void _stopRepeat() { _repeat?.cancel(); _repeat = null; }

  Widget _key(String label, CjKey k, {String? digit, bool fn = false, int flex = 1}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          onTap: () => _tap(k),
          onLongPress: () => _long(k),
          onLongPressEnd: (_) => _stopRepeat(),
          child: Container(
            height: widget.keyHeight,
            decoration: BoxDecoration(
              color: fn ? (dark ? const Color(0xFF2C2C2E) : const Color(0xFFD8D8DC))
                        : (dark ? const Color(0xFF3A3A3C) : Colors.white),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Stack(children: [
              Center(child: Text(label, style: TextStyle(
                fontSize: fn ? 14 : 17,
                color: dark ? Colors.white : const Color(0xFF1C1C1E),
              ))),
              if (digit != null) Positioned(right: 5, top: 3, child: Text(digit, style: const TextStyle(fontSize: 9, color: Color(0xFF9A9AA0)))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _plain(String label, VoidCallback onTap, {int flex = 1}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: widget.keyHeight,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFD8D8DC),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(child: Text(label, style: TextStyle(fontSize: 13, color: dark ? Colors.white : const Color(0xFF1C1C1E)))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? const Color(0xFF1C1C1E) : const Color(0xFFE3E3E8),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _key('ㅣ', CjKey.ii, digit: '1'),
          _key('·', CjKey.dot, digit: '2'),
          _key('ㅡ', CjKey.eu, digit: '3'),
          _key('⌫', CjKey.back, fn: true),
        ]),
        Row(children: [
          _key('ㄱㅋ', CjKey.gk, digit: '4'),
          _key('ㄴㄹ', CjKey.nr, digit: '5'),
          _key('ㄷㅌ', CjKey.dt, digit: '6'),
          _key('↵', CjKey.enter, fn: true),
        ]),
        Row(children: [
          _key('ㅂㅍ', CjKey.bp, digit: '7'),
          _key('ㅅㅎ', CjKey.sh, digit: '8'),
          _key('ㅈㅊ', CjKey.jc, digit: '9'),
          _plain('.,?!', () { _emit(CjOut(cjCompose(_st) + '.', CjState())); }),   // 조합 중이던 글자를 굳히고 마침표
        ]),
        // 넷째 줄 — 삼성 천지인과 같은 자리: !#1 · 한/영 · ㅇㅁ · 띄어쓰기 · $
        //   !#1 과 한/영 은 폰 자판으로 오간다(1번 안 · 영문·특수문자는 폰 자판)
        Row(children: [
          _plain('!#1', () { widget.onPhoneIme?.call(); }, flex: 3),
          _plain('한/영', () { widget.onPhoneIme?.call(); }, flex: 2),
          _key('ㅇㅁ', CjKey.om, digit: '0', flex: 3),
          _key('␣', CjKey.space, fn: true, flex: 3),
          _plain('\$', () { widget.onPhoneIme?.call(); }, flex: 2),
        ]),
      ]),
    );
  }
}
