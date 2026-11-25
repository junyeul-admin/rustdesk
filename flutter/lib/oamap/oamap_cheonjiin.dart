// OAMap 천지인 — 앱 안에서 한글을 직접 조합한다(삼성·구글 자판을 거치지 않음)
//   까닭 ①: 삼성 천지인 'ㅅㅎ' 키가 숫자 8 신호를 같이 보내 '안녕하8요' 가 되던 문제가 아예 없어진다.
//   까닭 ②: 조합 중인 글자를 우리가 알고 있으므로, 한 글자씩 원격 화면에 미리 보여 줄 수 있다.
//   이 파일은 '규칙'만 담는다(화면·전송 0 · Flutter 에 기대지 않음) — 시험이 이 파일만 떼어 돌린다.
library;

/// 천지인 글쇠 — 화면 단추 하나가 이 가운데 하나를 보낸다.
enum CjKey {
  ii,     // ㅣ (하늘아래 사람)
  dot,    // · (하늘)
  eu,     // ㅡ (땅)
  gk,     // ㄱㅋㄲ
  nr,     // ㄴㄹ
  dt,     // ㄷㅌㄸ
  bp,     // ㅂㅍㅃ
  sh,     // ㅅㅎㅆ
  jc,     // ㅈㅊㅉ
  om,     // ㅇㅁ
  back,   // ⌫ 한 획씩 지움
  space,  // 띄어쓰기(조합 끝냄)
  enter,  // 줄 바꿈(조합 끝냄)
}

const Map<CjKey, List<String>> _cycle = {
  CjKey.gk: ['ㄱ', 'ㅋ', 'ㄲ'],
  CjKey.nr: ['ㄴ', 'ㄹ'],
  CjKey.dt: ['ㄷ', 'ㅌ', 'ㄸ'],
  CjKey.bp: ['ㅂ', 'ㅍ', 'ㅃ'],
  CjKey.sh: ['ㅅ', 'ㅎ', 'ㅆ'],
  CjKey.jc: ['ㅈ', 'ㅊ', 'ㅉ'],
  CjKey.om: ['ㅇ', 'ㅁ'],
};

const List<String> _cho = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
const List<String> _jung = ['ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ', 'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ'];
const List<String> _jong = ['', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ', 'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];

/// 겹받침 — 앞 받침 + 새 자음 = 겹받침(없으면 null)
const Map<String, String> _jongPair = {
  'ㄱㅅ': 'ㄳ', 'ㄴㅈ': 'ㄵ', 'ㄴㅎ': 'ㄶ', 'ㄹㄱ': 'ㄺ', 'ㄹㅁ': 'ㄻ', 'ㄹㅂ': 'ㄼ',
  'ㄹㅅ': 'ㄽ', 'ㄹㅌ': 'ㄾ', 'ㄹㅍ': 'ㄿ', 'ㄹㅎ': 'ㅀ', 'ㅂㅅ': 'ㅄ',
};
/// 겹받침을 되돌릴 때(⌫) 쓰는 표
const Map<String, List<String>> _jongSplit = {
  'ㄳ': ['ㄱ', 'ㅅ'], 'ㄵ': ['ㄴ', 'ㅈ'], 'ㄶ': ['ㄴ', 'ㅎ'], 'ㄺ': ['ㄹ', 'ㄱ'], 'ㄻ': ['ㄹ', 'ㅁ'],
  'ㄼ': ['ㄹ', 'ㅂ'], 'ㄽ': ['ㄹ', 'ㅅ'], 'ㄾ': ['ㄹ', 'ㅌ'], 'ㄿ': ['ㄹ', 'ㅍ'], 'ㅀ': ['ㄹ', 'ㅎ'], 'ㅄ': ['ㅂ', 'ㅅ'],
};

/// 모음은 '획'을 쌓아 만든다 — 획 묶음(ㅣ·—) → 모음 글자
///   보기: ㅣ+· = ㅏ · ·+ㅣ = ㅓ · ·+— = ㅗ · —+· = ㅜ · ㅣ+·+· = ㅑ
const Map<String, String> _vowel = {
  'ㅣ': 'ㅣ', 'ㅡ': 'ㅡ',
  'ㅣ·': 'ㅏ', 'ㅣ··': 'ㅑ', '·ㅣ': 'ㅓ', '··ㅣ': 'ㅕ',
  '·ㅡ': 'ㅗ', '··ㅡ': 'ㅛ', 'ㅡ·': 'ㅜ', 'ㅡ··': 'ㅠ',
  'ㅣ·ㅣ': 'ㅐ', 'ㅣ··ㅣ': 'ㅒ', '·ㅣㅣ': 'ㅔ', '··ㅣㅣ': 'ㅖ',
  '·ㅡㅣ': 'ㅚ', '·ㅡㅣ·': 'ㅘ', '·ㅡㅣ·ㅣ': 'ㅙ',
  'ㅡ·ㅣ': 'ㅟ', 'ㅡ··ㅣ': 'ㅝ', 'ㅡ··ㅣㅣ': 'ㅞ',   // ㅜ+ㅓ = ㅝ
  'ㅡㅣ': 'ㅢ',
};

/// 같은 키를 거듭 눌러 글자를 바꾸는 시간(밀리초) — 이 시간이 지나 다시 누르면 새 글자로 본다.
///   삼성 천지인과 같은 셈(안 → (바로) 알 · 안 → (쉬고) 안ㄴ…). 설정에서 바꿀 수 있게 둔다.
const int cjCycleMs = 900;

String _sym(CjKey k) => k == CjKey.ii ? 'ㅣ' : (k == CjKey.dot ? '·' : 'ㅡ');

/// 조합 한 글자의 상태 — 초성·중성(획 묶음)·종성
class CjState {
  String cho = '';
  String strokes = '';   // 중성 획 묶음(위 표의 열쇠)
  String jong = '';
  CjKey? lastKey;        // 같은 자음 키를 거듭 눌렀는지
  int lastMs = 0;        // 그 키를 누른 때(밀리초) — 거듭 누르기는 이 안에서만
  int cycleAt = 0;       // 그 키의 몇 번째 글자인지
  bool jongFromCycle = false;   // 지금 종성이 거듭 누르기로 바뀌는 중인가

  bool get empty => cho.isEmpty && strokes.isEmpty && jong.isEmpty;
  String get jung => _vowel[strokes] ?? '';

  CjState copy() => CjState()
    ..cho = cho
    ..strokes = strokes
    ..jong = jong
    ..lastKey = lastKey
    ..lastMs = lastMs
    ..cycleAt = cycleAt
    ..jongFromCycle = jongFromCycle;
}

/// 조합 중 글자를 보이는 글자로 — 아직 모자라면 자모 그대로 보여 준다
String cjCompose(CjState s) {
  if (s.cho.isNotEmpty && s.jung.isNotEmpty) {
    final ci = _cho.indexOf(s.cho), vi = _jung.indexOf(s.jung), ti = _jong.indexOf(s.jong);
    if (ci >= 0 && vi >= 0 && ti >= 0) {
      return String.fromCharCode(0xAC00 + (ci * 21 + vi) * 28 + ti);
    }
  }
  if (s.cho.isNotEmpty) return s.cho + (s.jung.isNotEmpty ? s.jung : '');
  if (s.jung.isNotEmpty) return s.jung;
  if (s.strokes.isNotEmpty) return s.strokes;   // 아직 모음이 안 된 획(· 하나 등)
  return '';
}

/// 글쇠 하나를 눌렀을 때 — 돌려줌 @{ commit: 굳힌 글자(앞으로 보낼 것), state: 아직 조합 중인 것 }
class CjOut {
  final String commit;      // 더는 안 바뀌는 글자(원격에 그대로 보냄)
  final CjState state;      // 조합 중(노란 바탕으로 보여 줄 글자)
  final bool handled;       // 우리가 처리했나(아니면 바깥이 알아서)
  CjOut(this.commit, this.state, {this.handled = true});
  String get preview => cjCompose(state);
}

bool _isCons(CjKey k) => _cycle.containsKey(k);

CjOut cjPress(CjState cur, CjKey k, {int nowMs = 0, int cycleMs = cjCycleMs}) {
  final s = cur.copy();

  if (k == CjKey.space || k == CjKey.enter) {
    final done = cjCompose(s) + (k == CjKey.space ? ' ' : '\n');
    return CjOut(done, CjState());
  }

  if (k == CjKey.back) return _back(s);

  // ── 모음 획
  if (k == CjKey.ii || k == CjKey.dot || k == CjKey.eu) {
    s.lastKey = null;
    final sym = _sym(k);
    // 받침이 있는데 모음이 오면, 받침이 다음 글자의 초성이 된다(보기: 한 + ㅣ → 하 + 니)
    if (s.jong.isNotEmpty) {
      final moved = _jongSplit[s.jong];
      final give = moved != null ? moved[1] : s.jong;
      final keep = moved != null ? moved[0] : '';
      final head = s.copy()..jong = keep;
      final next = CjState()..cho = give..strokes = sym;
      if (_vowel.containsKey(sym)) return CjOut(cjCompose(head), next);
      return CjOut(cjCompose(head), next);
    }
    final tryStrokes = s.strokes + sym;
    if (_vowel.containsKey(tryStrokes)) { s.strokes = tryStrokes; return CjOut('', s); }
    // 더 못 쌓으면 지금 글자를 굳히고 새 글자의 모음으로
    if (s.strokes.isEmpty) { s.strokes = sym; return CjOut('', s); }
    final done = cjCompose(s);
    return CjOut(done, CjState()..strokes = sym);
  }

  // ── 자음
  if (_isCons(k)) {
    final list = _cycle[k]!;
    // 같은 키 거듭 누르기(초성 자리 · 종성 자리 둘 다)
    final soon = nowMs == 0 || (nowMs - s.lastMs) <= cycleMs;   // 때를 안 주면(시험) 늘 거듭 누르기로 본다
    if (s.lastKey == k && soon) {
      if (s.jung.isEmpty && s.cho.isNotEmpty) {          // 초성 자리에서 바꿈
        s.cycleAt = (s.cycleAt + 1) % list.length;
        s.cho = list[s.cycleAt];
        s.lastMs = nowMs;
        return CjOut('', s);
      }
      if (s.jong.isNotEmpty && s.jongFromCycle) {        // 종성 자리에서 바꿈
        final nextAt = (s.cycleAt + 1) % list.length;
        final cand = list[nextAt];
        if (_jong.contains(cand)) { s.cycleAt = nextAt; s.jong = cand; s.lastMs = nowMs; return CjOut('', s); }
      }
    }
    final first = list[0];
    // 초성이 빈 자리
    if (s.cho.isEmpty && s.strokes.isEmpty) {
      s.cho = first; s.lastKey = k; s.lastMs = nowMs; s.cycleAt = 0; s.jongFromCycle = false;
      return CjOut('', s);
    }
    // 중성이 있으면 종성으로
    if (s.jung.isNotEmpty) {
      if (s.jong.isEmpty) {
        if (_jong.contains(first)) {
          s.jong = first; s.lastKey = k; s.lastMs = nowMs; s.cycleAt = 0; s.jongFromCycle = true;
          return CjOut('', s);
        }
      } else {
        final pair = _jongPair[s.jong + first];
        if (pair != null) {
          s.jong = pair; s.lastKey = k; s.lastMs = nowMs; s.cycleAt = 0; s.jongFromCycle = false;
          return CjOut('', s);
        }
      }
      // 종성을 더 못 붙이면 이 글자를 굳히고 새 글자 초성으로
      final done = cjCompose(s);
      return CjOut(done, CjState()..cho = first..lastKey = k..lastMs = nowMs);
    }
    // 초성만 있고 모음이 아직 없는데 다른 자음 → 앞 자음을 굳힘
    final done = cjCompose(s);
    return CjOut(done, CjState()..cho = first..lastKey = k..lastMs = nowMs);
  }

  return CjOut('', s, handled: false);
}

/// ⌫ — 한 획씩 되돌린다(조합 중일 때만 · 조합이 비면 바깥이 지우기를 보낸다)
CjOut _back(CjState s) {
  s.lastKey = null;
  if (s.jong.isNotEmpty) {
    final sp = _jongSplit[s.jong];
    s.jong = sp != null ? sp[0] : '';
    s.jongFromCycle = false;
    return CjOut('', s);
  }
  if (s.strokes.isNotEmpty) {
    s.strokes = s.strokes.substring(0, s.strokes.length - 1);
    return CjOut('', s);
  }
  if (s.cho.isNotEmpty) { s.cho = ''; return CjOut('', s); }
  return CjOut('', s, handled: false);   // 조합이 비었음 = 원격에 ⌫ 를 그대로 보냄
}


/// 길게 누르면 나오는 숫자 — 삼성 천지인과 같은 자리(ㅣ=1 · =2 ㅡ=3 ㄱ=4 ㄴ=5 ㄷ=6 ㅂ=7 ㅅ=8 ㅈ=9 ㅇ=0)
const Map<CjKey, String> cjDigit = {
  CjKey.ii: '1', CjKey.dot: '2', CjKey.eu: '3',
  CjKey.gk: '4', CjKey.nr: '5', CjKey.dt: '6',
  CjKey.bp: '7', CjKey.sh: '8', CjKey.jc: '9',
  CjKey.om: '0',
};

/// 길게 눌러 숫자 — 조합 중이던 글자는 굳히고 숫자를 뒤에 붙인다(돌려줌 = 굳힌 글자 + 숫자)
CjOut cjLongPress(CjState cur, CjKey k) {
  final d = cjDigit[k];
  if (d == null) return CjOut('', cur.copy(), handled: false);
  return CjOut(cjCompose(cur) + d, CjState());
}

/// 글쇠 줄을 한 번에 — 시험·흉내용(돌려줌 = 굳힌 글자 + 아직 조합 중인 글자)
String cjType(List<CjKey> keys, {List<int>? atMs}) {
  var st = CjState();
  final sb = StringBuffer();
  for (var i = 0; i < keys.length; i++) {
    final k = keys[i];
    final o = cjPress(st, k, nowMs: atMs != null ? atMs[i] : 0);
    sb.write(o.commit);
    st = o.state;
  }
  sb.write(cjCompose(st));
  return sb.toString();
}
