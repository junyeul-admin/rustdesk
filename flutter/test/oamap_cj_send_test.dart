// 천지인 미리보기 보내기 셈 시험 — 원격 연결 0
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/oamap/oamap_cheonjiin.dart';
import 'package:flutter_hbb/oamap/oamap_cj_send.dart';

void main() {
  test('한 글자가 자라는 동안 — 지우고 다시 보냄', () {
    final e = CjEcho();
    expect(e.step('', 'ㅅ'), const CjSend(0, 'ㅅ'));
    expect(e.step('', 'ㅎ'), const CjSend(1, 'ㅎ'));
    expect(e.step('', '히'), const CjSend(1, '히'));
    expect(e.step('', '하'), const CjSend(1, '하'));
    expect(e.step('', '한'), const CjSend(1, '한'));
    expect(e.shown, '한');
  });

  test('겉모양이 안 바뀌면 아무것도 안 보낸다', () {
    final e = CjEcho();
    expect(e.step('', 'ㄴ'), const CjSend(0, 'ㄴ'));
    expect(e.step('', 'ㄴ'), const CjSend(0, ''));   // 점을 쌓는 중 — 보이는 글자 그대로
    expect(e.step('', 'ㄴ'), const CjSend(0, ''));
    expect(e.step('', '녀'), const CjSend(1, '녀'));
    expect(e.shown, '녀');
  });

  test('굳힌 글자는 지우지 않는다', () {
    final e = CjEcho();
    e.step('', '가');                                   // 조합 중 '가'
    expect(e.step('가 ', ''), const CjSend(1, '가 '));   // 띄어쓰기로 굳힘
    expect(e.shown, '');
  });

  test('받침이 다음 글자로 넘어갈 때', () {
    final e = CjEcho();
    e.step('', '안');
    // '아' 를 굳히고 '나' 를 조합 중으로
    expect(e.step('아', '나'), const CjSend(1, '아나'));
    expect(e.shown, '나');
  });

  test('미리보기를 끄면 굳힌 글자만', () {
    final e = CjEcho(preview: false);
    expect(e.step('', 'ㅅ'), const CjSend(0, ''));
    expect(e.step('', '하'), const CjSend(0, ''));
    expect(e.step('한', ''), const CjSend(0, '한'));
  });

  test('끄는 중간에 떠 있던 글자는 지운다', () {
    final e = CjEcho();
    e.step('', '하');
    e.preview = false;
    expect(e.step('', '한'), const CjSend(1, ''));   // 떠 있던 '하' 를 지우고 아무것도 안 보냄
  });

  test('접속이 끊겼다 붙으면 기억만 비움', () {
    final e = CjEcho();
    e.step('', '하');
    e.forget();
    expect(e.step('', '한'), const CjSend(0, '한'));   // 지우기 0(남의 화면을 함부로 지우지 않음)
  });

  test('엔진과 이어 붙임 — 안녕 두 글자', () {
    final e = CjEcho();
    var st = CjState();
    final sends = <CjSend>[];
    for (final k in [CjKey.om, CjKey.ii, CjKey.dot, CjKey.nr]) {
      final o = cjPress(st, k);
      st = o.state;
      sends.add(e.step(o.commit, o.preview));
    }
    expect(sends.map((s) => s.text).toList(), ['ㅇ', '이', '아', '안']);
    expect(sends.map((s) => s.back).toList(), [0, 1, 1, 1]);
  });

  test('길게 눌러 숫자 — 조합 중이던 글자를 굳히고 숫자', () {
    final e = CjEcho();
    var st = CjState();
    for (final k in [CjKey.gk, CjKey.ii, CjKey.dot]) { st = cjPress(st, k).state; }
    final o = cjLongPress(st, CjKey.sh);   // 길게 ㅅ = 8
    expect(o.commit, '가8');
    e.step('', '가');
    expect(e.step(o.commit, o.preview), const CjSend(1, '가8'));
  });
}
