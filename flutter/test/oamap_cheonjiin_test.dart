// 천지인 조합 규칙 시험 — 화면·전송 0(규칙 파일만 떼어 봄)
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/oamap/oamap_cheonjiin.dart';

CjKey k(String s) {
  switch (s) {
    case 'ㅣ': return CjKey.ii;
    case '·': return CjKey.dot;
    case 'ㅡ': return CjKey.eu;
    case 'ㄱ': return CjKey.gk;
    case 'ㄴ': return CjKey.nr;
    case 'ㄷ': return CjKey.dt;
    case 'ㅂ': return CjKey.bp;
    case 'ㅅ': return CjKey.sh;
    case 'ㅈ': return CjKey.jc;
    case 'ㅇ': return CjKey.om;
    case '<': return CjKey.back;
    case ' ': return CjKey.space;
    case '\n': return CjKey.enter;
  }
  throw 'bad key $s';
}

List<CjKey> seq(String s) => s.split('').map(k).toList();

void main() {
  test('모음 하나씩', () {
    expect(cjType(seq('ㅣ·')), 'ㅏ');
    expect(cjType(seq('·ㅣ')), 'ㅓ');
    expect(cjType(seq('·ㅡ')), 'ㅗ');
    expect(cjType(seq('ㅡ·')), 'ㅜ');
    expect(cjType(seq('ㅣ··')), 'ㅑ');
    expect(cjType(seq('ㅡㅣ')), 'ㅢ');
  });

  // 점을 먼저 두 번 찍는 모음 — '··' 는 아직 모음이 아니라서 중간에 끊기기 쉽다
  test('점 두 번으로 시작하는 모음 — ㅕ ㅛ ㅠ ㅒ ㅖ', () {
    expect(cjType(seq('··ㅣ')), 'ㅕ');
    expect(cjType(seq('··ㅡ')), 'ㅛ');
    expect(cjType(seq('ㅡ··')), 'ㅠ');
    expect(cjType(seq('ㅣ··ㅣ')), 'ㅒ');
    expect(cjType(seq('··ㅣㅣ')), 'ㅖ');
    // 초성과 함께 — 녀 뇨 뉴
    expect(cjType(seq('ㄴ··ㅣ')), '녀');
    expect(cjType(seq('ㄴ··ㅡ')), '뇨');
    expect(cjType(seq('ㄴㅡ··')), '뉴');
  });

  test('글자 하나 — 가·나·하', () {
    expect(cjType(seq('ㄱㅣ·')), '가');
    expect(cjType(seq('ㄴㅣ·')), '나');
    expect(cjType(seq('ㅅㅅㅣ·')), '하');   // ㅅ→ㅎ 거듭 누르기
  });

  test('받침', () {
    expect(cjType(seq('ㅇㅣ·ㄴ')), '안');
    expect(cjType(seq('ㄱㅣ·ㅂ')), '갑');
    expect(cjType(seq('ㄱㅣ·ㅂㅅ')), '값');   // 겹받침 ㅄ
  });

  test('받침이 다음 글자 초성으로 넘어감', () {
    // 안 + ㅣ· → 아 + 나
    expect(cjType(seq('ㅇㅣ·ㄴㅣ·')), '아나');
  });

  test('안녕하세요 — 때(시간)를 주고', () {
    // 안: ㅇ ㅣ · ㄴ / 녕: ㄴ · · ㅣ ㅇ / 하: ㅅㅅ(바로) ㅣ · / 세: ㅅ · ㅣ ㅣ / 요: ㅇ · · ㅡ
    final keys = <CjKey>[]
      ..addAll(seq('ㅇㅣ·ㄴ'))      // 0 1 2 3
      ..addAll(seq('ㄴ··ㅣㅇ'))     // 4 5 6 7 8
      ..addAll(seq('ㅅㅅㅣ·'))      // 9 10 11 12
      ..addAll(seq('ㅅ·ㅣㅣ'))      // 13 14 15 16
      ..addAll(seq('ㅇ··ㅡ'));      // 17 18 19 20
    // 거듭 누르기(ㅅㅅ)만 200ms 안 · 나머지는 2초씩 띄움
    var t = 0;
    final at = <int>[];
    for (var i = 0; i < keys.length; i++) {
      final sameFast = i == 10;   // 'ㅅㅅ' 의 두 번째
      t += sameFast ? 200 : 2000;
      at.add(t);
    }
    expect(cjType(keys, atMs: at), '안녕하세요');
  });

  test('같은 자음 키 — 바로 다시 누르면 바뀌고, 쉬었다 누르면 새 글자', () {
    // 안 + (바로) ㄴ → 알
    expect(cjType(seq('ㅇㅣ·ㄴㄴ'), atMs: [0, 100, 200, 300, 400]), '알');
    // 안 + (쉬고) ㄴ → 안ㄴ
    expect(cjType(seq('ㅇㅣ·ㄴㄴ'), atMs: [0, 100, 200, 300, 5000]), '안ㄴ');
  });


  // 사장님 영상(삼성 노트 · 11/25)에 나온 글자들 — 이대로 쳐져야 한다
  test('영상에 나온 모음 — ㅢ ㅚ ㅐ ㅙ ㅝ ㅟ ㅞ', () {
    expect(cjType(seq('ㅡㅣ')), 'ㅢ');
    expect(cjType(seq('·ㅡㅣ')), 'ㅚ');
    expect(cjType(seq('ㅣ·ㅣ')), 'ㅐ');
    expect(cjType(seq('·ㅡㅣ·ㅣ')), 'ㅙ');
    expect(cjType(seq('ㅡ··ㅣ')), 'ㅝ');
    expect(cjType(seq('ㅡ·ㅣ')), 'ㅟ');
    expect(cjType(seq('ㅡ··ㅣㅣ')), 'ㅞ');
  });

  test('영상에 나온 쌍자음 — 까 빠 씻 찾', () {
    expect(cjType(seq('ㄱㄱㄱㅣ·')), '까');          // ㄱ→ㅋ→ㄲ
    expect(cjType(seq('ㅂㅂㅂㅣ·')), '빠');          // ㅂ→ㅍ→ㅃ
    expect(cjType(seq('ㅅㅅㅅㅣㅅ')), '씻');        // ㅆ + ㅣ + 받침 ㅅ
    expect(cjType(seq('ㅈㅈㅣ·ㅈ')), '찾');          // 초성 ㅈ→ㅊ · 받침 ㅈ
  });

  test('영상에 나온 낱말 — 왜 네 애 잘', () {
    expect(cjType(seq('ㅇ·ㅡㅣ·ㅣ')), '왜');
    expect(cjType(seq('ㄴ·ㅣㅣ')), '네');
    expect(cjType(seq('ㅇㅣ·ㅣ')), '애');
    expect(cjType(seq('ㅈㅣ·ㄴㄴ')), '잘');          // 받침 ㄴ→ㄹ
  });

  test('숫자 8 이 섞이지 않음 — 글쇠에 숫자 자리가 없다', () {
    final out = cjType(seq('ㅅㅅㅣ·'));
    expect(out.contains('8'), false);
    expect(out, '하');
  });

  // 사장님 실기와 같은 문장(R-1812) — 한 문장을 통째로
  test('한 문장 통째 — 안녕하세요 이준열입니다', () {
    final keys = <CjKey>[]
      ..addAll(seq('ㅇㅣ·ㄴ'))      // 안      0 1 2 3
      ..addAll(seq('ㄴ··ㅣㅇ'))     // 녕      4 5 6 7 8
      ..addAll(seq('ㅅㅅㅣ·'))      // 하      9 10 11 12
      ..addAll(seq('ㅅ·ㅣㅣ'))      // 세      13 14 15 16
      ..addAll(seq('ㅇ··ㅡ'))       // 요      17 18 19 20
      ..addAll(seq(' '))            // 띄어쓰기 21
      ..addAll(seq('ㅇㅣ'))         // 이      22 23
      ..addAll(seq('ㅈㅡ·ㄴ'))      // 준      24 25 26 27
      ..addAll(seq('ㅇ··ㅣㄴㄴ'))   // 열      28 29 30 31 32 33
      ..addAll(seq('ㅇㅣㅂ'))       // 입      34 35 36
      ..addAll(seq('ㄴㅣ'))         // 니      37 38
      ..addAll(seq('ㄷㅣ·'));       // 다      39 40 41
    // 같은 글쇠를 잇달아 '바로' 누르는 곳만 빠르게 — ㅅㅅ(ㅎ) 과 ㄴㄴ(받침 ㄹ)
    const fast = [10, 33];
    var t = 0;
    final at = <int>[];
    for (var i = 0; i < keys.length; i++) {
      t += fast.contains(i) ? 200 : 2000;
      at.add(t);
    }
    expect(cjType(keys, atMs: at), '안녕하세요 이준열입니다');
  });

  test('빠르게 연타해도 어긋나지 않는다 — 때를 안 줘도 같은 글자', () {
    // 때를 안 주면 늘 거듭 누르기로 본다(규칙) — 같은 글쇠가 잇닿지 않는 낱말은 그대로여야 한다
    expect(cjType(seq('ㄷㅣ·ㅅㅣㅇ')), '다싱');
    expect(cjType(seq('ㅂㅣ·ㄱㅣ')), '바기');
  });

  test('길게 눌러 숫자 — 글자 사이에 숫자가 섞여도 한글이 안 깨짐', () {
    var st = CjState();
    final out = StringBuffer();
    for (final key in seq('ㄱㅣ·')) {   // '가'
      final o = cjPress(st, key);
      st = o.state;
      out.write(o.commit);
    }
    final d = cjLongPress(st, CjKey.dt);   // 길게 ㄷ = 6
    expect(d.handled, true);
    out.write(d.commit);
    st = d.state;
    for (final key in seq('ㄴㅣ·')) {   // '나'
      final o = cjPress(st, key);
      st = o.state;
      out.write(o.commit);
    }
    expect(out.toString() + cjCompose(st), '가6나');
  });

  test('조합 중 미리보기 — 한 글자씩 자란다', () {
    var st = CjState();
    final shown = <String>[];
    for (final key in seq('ㅅㅅㅣ·ㄴ')) {
      final o = cjPress(st, key);
      st = o.state;
      shown.add(o.preview);
    }
    expect(shown, ['ㅅ', 'ㅎ', '히', '하', '한']);
  });

  test('⌫ 는 한 획씩', () {
    var st = CjState();
    for (final key in seq('ㅅㅅㅣ·ㄴ')) { st = cjPress(st, key).state; }
    expect(cjCompose(st), '한');
    st = cjPress(st, CjKey.back).state; expect(cjCompose(st), '하');
    st = cjPress(st, CjKey.back).state; expect(cjCompose(st), '히');
    st = cjPress(st, CjKey.back).state; expect(cjCompose(st), 'ㅎ');
    st = cjPress(st, CjKey.back).state; expect(cjCompose(st), '');
  });

  // 사장님 실기 11/26 — PC 에 'ㆍㆍ' 나 낱자모가 글자로 남던 것
  test('점만 쌓인 것은 글자로 굳지 않는다', () {
    // 점 두 개 뒤에 자음 → 점은 사라지고 그 자음만 남는다('··ㄱ' 아님)
    expect(cjType(seq('··ㄱㅣ·')), '가');
    // 점 하나 뒤에 띄어쓰기 → 점은 안 나간다
    var st = CjState();
    st = cjPress(st, CjKey.dot).state;
    final sp = cjPress(st, CjKey.space);
    expect(sp.commit, ' ');
    // 글자 뒤에 점을 찍다 멈추고 새 글자 → 점은 하나도 안 남는다
    //   (넘어간 받침 ㄴ 이 홀로 남는 것은 천지인 규칙대로 맞다)
    final mid = cjType(seq('ㄱㅣ·ㄴ··ㄷㅣ·'));
    expect(mid.contains('·'), false);
    expect(mid, '가ㄴ다');
  });

  test('점을 쌓는 중에도 보이는 것은 점 그대로', () {
    var st = CjState();
    st = cjPress(st, CjKey.dot).state;
    expect(cjCompose(st), '·');
    st = cjPress(st, CjKey.dot).state;
    expect(cjCompose(st), '··');
  });

  test('조합이 비면 우리가 처리하지 않음(원격에 ⌫ 그대로)', () {
    final o = cjPress(CjState(), CjKey.back);
    expect(o.handled, false);
  });

  test('띄어쓰기·줄바꿈은 글자를 굳힌다', () {
    var st = CjState();
    for (final key in seq('ㄱㅣ·')) { st = cjPress(st, key).state; }
    final o = cjPress(st, CjKey.space);
    expect(o.commit, '가 ');
    expect(o.preview, '');
  });
}
