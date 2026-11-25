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
    // 안: ㅇ ㅣ · ㄴ / 녕: ㄴ · · ㅣ ㅇ / 하: ㅅㅅ(바로) ㅣ · / 세: ㅅ · ㅣ ㅣ / 요: · · ㅡ
    final keys = <CjKey>[]
      ..addAll(seq('ㅇㅣ·ㄴ'))
      ..addAll(seq('ㄴ··ㅣㅇ'))
      ..addAll(seq('ㅅㅅㅣ·'))
      ..addAll(seq('ㅅ·ㅣㅣ'))
      ..addAll(seq('··ㅡ'));
    // 거듭 누르기(ㅅㅅ)만 200ms 안 · 나머지는 2초씩 띄움
    var t = 0;
    final at = <int>[];
    for (var i = 0; i < keys.length; i++) {
      final sameFast = i == 15;   // 'ㅅㅅ' 의 두 번째
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
    expect(cjType(seq('ㅅㅅㅅㅣㅅㄷ')), '씻');       // ㅆ + ㅣ + 받침 ㅅ
    expect(cjType(seq('ㅈㅣ·ㅈㅈ')), '찾');          // 받침 ㅈ→ㅊ
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
