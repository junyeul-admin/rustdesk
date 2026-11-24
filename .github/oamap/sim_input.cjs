// sim2.cjs — 안드로이드 화면 자판 입력 흉내 시험 (RustDesk 1.5.3 mobile remote_page.dart)
// 실행: node sim2.cjs        (자세히: node sim2.cjs -v)
//
// 세 함수를 Dart 원문에서 줄 그대로 옮김(손으로 다시 짜지 않음 · 줄 번호 대응은 각 함수 주석).
//   OLD = 원본\remote_page.dart  _handleNonIOSSoftKeyboardInput (1.5.3 원문 373~416줄)
//   FIX = remote_page.dart       _handleNonIOSSoftKeyboardInput (고친 판 373~445줄)
//   V2  = remote_page_v2.dart    _handleNonIOSSoftKeyboardInput (이 시험에서 나온 보강안)
// Dart String 과 JS String 은 둘 다 UTF-16 코드 단위라 s[i] · length · substring 이 같은 뜻.
//
// 손님 PC 칸 모형: text + caret(코드 단위 위치).
//   inputModel.inputKey('VK_BACK')  -> caret 앞 '글자 하나(코드 포인트)' 지움 (윈도 메모장·워드처럼 서로게이트 쌍은 한 번에)
//   inputModel.inputKey('VK_RETURN')-> '\n' 넣음 · 'VK_SPACE' -> ' ' · 'VK_LEFT/RIGHT' -> caret 이동 · 그 밖 한 글자 -> 그 글자
//   bind.sessionInputString(value)  -> 글을 caret 자리에 넣음
//   inputChar(c) = 원문 459~469줄 ('\n'->VK_RETURN, ' '->VK_SPACE, 그 밖 inputKey(c))
// 폰 글 칸 모형: _textController 초기값 initText = '1' * 1024 (원문 29줄) · 자판(IME)이 바꾼 '전체 글'로 onChanged 호출
//   (onChanged 는 글이 바뀔 때만 불림 · 조합 중 글자도 글 안에 들어 있음 = Flutter 안드로이드 동작)
//   빈 칸에서 지우기: 글이 안 바뀌어 onChanged 없음 -> 원문 776~783줄 주석대로 키 이벤트 길(RawKeyFocusScope)로 VK_BACK 이 감 = 함수 밖 '키길'로 따로 셈.

'use strict';
const VERBOSE = process.argv.includes('-v');
const INIT = '1'.repeat(1024); // remote_page.dart:29 final initText = '1' * 1024;

// ---------------------------------------------------------------- 손님 PC 칸
function makeRemote(text) {
  const r = { text, caret: text.length, back: 0, chars: 0, strings: 0, strChars: 0, keys: 0, log: [] };
  const cpBefore = (s, i) => (i >= 2 && /[\uDC00-\uDFFF]/.test(s[i - 1]) && /[\uD800-\uDBFF]/.test(s[i - 2]) ? 2 : 1);
  r.insert = (s) => { r.text = r.text.slice(0, r.caret) + s + r.text.slice(r.caret); r.caret += s.length; };
  r.inputKey = (name) => {
    r.keys++;
    if (VERBOSE) r.log.push(name);
    if (name === 'VK_BACK') {
      r.back++;
      if (r.caret > 0) { const n = cpBefore(r.text, r.caret); r.text = r.text.slice(0, r.caret - n) + r.text.slice(r.caret); r.caret -= n; }
    } else if (name === 'VK_RETURN') { r.chars++; r.insert('\n'); }
    else if (name === 'VK_SPACE') { r.chars++; r.insert(' '); }
    else if (name === 'VK_LEFT') { if (r.caret > 0) r.caret -= cpBefore(r.text, r.caret); }
    else if (name === 'VK_RIGHT') { if (r.caret < r.text.length) r.caret += /[\uD800-\uDBFF]/.test(r.text[r.caret]) ? 2 : 1; }
    else { r.chars++; r.insert(name); }
  };
  r.sessionInputString = (value) => { r.strings++; r.strChars += value.length; if (VERBOSE) r.log.push('STR(' + JSON.stringify(value) + ')'); r.insert(value); };
  return r;
}

// ---------------------------------------------------------------- 세 함수 (줄 그대로)
// st = State 흉내 { _value, remote, resetField() } — resetField 는 _openKeyboardUnlocked() 의 '_value = initText; _textController.text = _value;' (원문 496~498줄)
function inputChar(st, char) {                     // 459 void inputChar(String char) {
  /* 460~462 keyboardInputAllowed: 늘 true 로 봄 */
  if (char === '\n') {                             // 463
    char = 'VK_RETURN';                            // 464
  } else if (char === ' ') {                       // 465
    char = 'VK_SPACE';                             // 466
  }
  st.remote.inputKey(char);                        // 468 inputModel.inputKey(char);
}
const PAIRS = ['""', '()', '[]', '<>', '{}', '”“', '《》', '（）', '【】'];

function OLD(st, newValue) {                       // 원본 373 void _handleNonIOSSoftKeyboardInput(String newValue) {
  let oldValue = st._value;                        // 374
  st._value = newValue;                            // 375
  if (oldValue.length > 0 && newValue.length > 0 && oldValue[0] === '1' && newValue[0] !== '1') { // 376~379
    oldValue = '';                                 // 381 // clipboard
  }
  if (newValue.length === oldValue.length) {       // 387
    // ?                                           // 388
  } else if (newValue.length < oldValue.length) {  // 389
    st.remote.inputKey('VK_BACK');                 // 390~391
  } else {                                         // 392
    const content = newValue.substring(oldValue.length); // 393
    if (content.length > 1) {                      // 394
      if (oldValue !== '' && content.length === 2 && PAIRS.includes(content)) { // 395~405
        st.remote.sessionInputString(content);     // 407
        st.resetField();                           // 408 _openKeyboardUnlocked();
        return;                                    // 409
      }
      st.remote.sessionInputString(content);       // 411
    } else {
      inputChar(st, content);                      // 413
    }
  }
}

function FIX(st, newValue) {                       // 고친 판 373
  let oldValue = st._value;                        // 374
  st._value = newValue;                            // 375
  if (oldValue.length > 0 && newValue.length > 0 && oldValue[0] === '1' && newValue[0] !== '1') { // 376~379
    oldValue = '';                                 // 381
  }
  let common = 0;                                  // 389
  for (; common < oldValue.length && common < newValue.length && oldValue[common] === newValue[common]; ++common) {} // 390~394
  const removed = oldValue.length - common;        // 395
  const added = newValue.length - common;          // 396
  if (removed > 0 && (added > 0 || removed > 1)) { // 397
    for (let k = 0; k < removed; ++k) {            // 399
      st.remote.inputKey('VK_BACK');               // 400
    }
    if (added > 0) {                               // 402
      const tail = newValue.substring(common);     // 403
      if (tail.length > 1) {                       // 404
        st.remote.sessionInputString(tail);        // 405
      } else {
        inputChar(st, tail);                       // 407
      }
    }
    return;                                        // 410
  }
  if (newValue.length === oldValue.length) {       // 416
  } else if (newValue.length < oldValue.length) {  // 418
    st.remote.inputKey('VK_BACK');                 // 419~420
  } else {
    const content = newValue.substring(oldValue.length); // 422
    if (content.length > 1) {                      // 423
      if (oldValue !== '' && content.length === 2 && PAIRS.includes(content)) { // 424~434
        st.remote.sessionInputString(content);     // 436
        st.resetField();                           // 437 _openKeyboardUnlocked();
        return;                                    // 438
      }
      st.remote.sessionInputString(content);       // 440
    } else {
      inputChar(st, content);                      // 442
    }
  }
}

// ADDON = 덧붙임 묶음 0001 의 flutter/lib/oamap/oamap_input.dart oamapSoftKeyboardDiff (줄 그대로) + remote_page 연결 줄
//   remote_page 연결: final oldValue = _value; _value = newValue; oamapSoftKeyboardDiff(oldValue, newValue, back: VK_BACK, char: inputChar, string: sessionInputString)
function ADDON(st, newValue) {
  const oldValue0 = st._value;                     // remote_page: var oldValue = _value;
  st._value = newValue;                            //              _value = newValue;
  let oldValue = oldValue0;                        // oamap_input.dart:
  if (oldValue.length > 0 && newValue.length > 0 && oldValue[0] === '1' && newValue[0] !== '1') {
    oldValue = '';                                 //   clipboard heuristic
  }
  let common = 0;
  for (; common < oldValue.length && common < newValue.length && oldValue[common] === newValue[common]; ++common) {}
  if (common > 0 && (common < oldValue.length || common < newValue.length) && (oldValue.charCodeAt(common - 1) & 0xFC00) === 0xD800) {
    --common;                                      //   never split a surrogate pair
  }
  const removed = [...oldValue.substring(common)].length; // oldValue.substring(common).runes.length
  const tail = newValue.substring(common);
  for (let k = 0; k < removed; ++k) st.remote.inputKey('VK_BACK'); // back()
  if (tail.length === 0) return;
  if (tail.length > 1) st.remote.sessionInputString(tail); // string(tail)
  else inputChar(st, tail);                        // char(tail)
}

// V2 = FIX + (가) 서로게이트 쌍을 가르지 않고 지울 개수를 '글자(코드 포인트)'로 셈  (나) 괄호 쌍 뒤 글 칸 되돌림(_openKeyboardUnlocked) 없앰
//   remote_page_v2.dart 의 줄 번호는 그 파일 주석 'V2-a' 'V2-b' 자리.
function V2(st, newValue) {
  let oldValue = st._value;
  st._value = newValue;
  if (oldValue.length > 0 && newValue.length > 0 && oldValue[0] === '1' && newValue[0] !== '1') {
    oldValue = '';
  }
  let common = 0;
  for (; common < oldValue.length && common < newValue.length && oldValue[common] === newValue[common]; ++common) {}
  // V2-a: if (common > 0 && (common < oldValue.length || common < newValue.length) && (oldValue.codeUnitAt(common - 1) & 0xFC00) == 0xD800) --common;
  if (common > 0 && (common < oldValue.length || common < newValue.length) && (oldValue.charCodeAt(common - 1) & 0xFC00) === 0xD800) --common;
  // V2-a: final removed = oldValue.substring(common).runes.length;
  const removed = [...oldValue.substring(common)].length;
  const added = newValue.length - common;
  if (removed > 0 && (added > 0 || removed > 1)) {
    for (let k = 0; k < removed; ++k) st.remote.inputKey('VK_BACK');
    if (added > 0) {
      const tail = newValue.substring(common);
      if (tail.length > 1) st.remote.sessionInputString(tail); else inputChar(st, tail);
    }
    return;
  }
  if (newValue.length === oldValue.length) {
  } else if (newValue.length < oldValue.length) {
    st.remote.inputKey('VK_BACK');
  } else {
    const content = newValue.substring(oldValue.length);
    if (content.length > 1) {
      // V2-b: the prefix diff above already handles a caret left inside the pair, so the field is no longer reset here.
      st.remote.sessionInputString(content);
    } else {
      inputChar(st, content);
    }
  }
}

// ---------------------------------------------------------------- 폰 자판(IME) 흉내
// 폰 글 칸 = '1'*sent + user. caret·wordStart 는 user 안의 위치. ideal = 손님 칸에 '있어야 할' 글 = base + user.
function run(fn, ops, R0) {
  const remote = makeRemote(R0);
  const ph = { sent: 1024, user: '', caret: 0, wordStart: 0, base: R0, keyRoute: 0, changes: 0 };
  const st = { _value: INIT, remote, resetField: null };
  const field = () => '1'.repeat(ph.sent) + ph.user;
  st.resetField = () => { // _openKeyboardUnlocked: 폰 칸만 새로(손님 칸은 그대로) -> 지금까지 친 글은 base 로 넘어감
    ph.base += ph.user; ph.user = ''; ph.caret = 0; ph.wordStart = 0; ph.sent = 1024; st._value = INIT;
  };
  let prev = field();
  const emit = () => { const f = field(); if (f !== prev) { ph.changes++; fn(st, f); prev = field(); } };
  const cpLenBefore = (s, i) => (i >= 2 && /[\uDC00-\uDFFF]/.test(s[i - 1]) && /[\uD800-\uDBFF]/.test(s[i - 2]) ? 2 : 1);
  const A = {
    // 조합 중인 낱말(wordStart~caret)을 s 로 바꿈 = 한글 자판이 '이'->'인'->'이주' 처럼 보내는 값
    w(s) { ph.user = ph.user.slice(0, ph.wordStart) + s + ph.user.slice(ph.caret); ph.caret = ph.wordStart + s.length; emit(); },
    // Gboard 일부 판처럼 조합 글자를 먼저 빼고(빈 값) 새로 넣는 두 번 호출
    w2(s) { ph.user = ph.user.slice(0, ph.wordStart) + ph.user.slice(ph.caret); ph.caret = ph.wordStart; emit(); A.w(s); },
    // 확정 글/기호/공백 넣기 (한 번 호출) -> 다음 낱말 시작
    ins(s) { ph.user = ph.user.slice(0, ph.caret) + s + ph.user.slice(ph.caret); ph.caret += s.length; ph.wordStart = ph.caret; emit(); },
    // 확정 상태에서 지우기 한 번(글자=그래핌 하나 · 여기선 코드 포인트, 결합 이모지는 g 로)
    bs(g = 0) {
      if (ph.caret > 0) {
        let n = g || cpLenBefore(ph.user, ph.caret);
        ph.user = ph.user.slice(0, ph.caret - n) + ph.user.slice(ph.caret); ph.caret -= n; ph.wordStart = Math.min(ph.wordStart, ph.caret); emit();
      } else if (ph.sent > 0) { // 앞의 '1' 을 지움 -> 손님 칸 기존 글이 지워져야 맞음
        ph.sent--; ph.base = ph.base.slice(0, ph.base.length - cpLenBefore(ph.base, ph.base.length)); emit();
      } else { // 빈 칸: onChanged 없음 -> 키 이벤트 길
        ph.keyRoute++; remote.inputKey('VK_BACK'); ph.base = ph.base.slice(0, ph.base.length - cpLenBefore(ph.base, ph.base.length));
      }
    },
    // caret 앞 n 코드 단위를 s 로 한 번에 바꿈(자동 고침·예측 단어·낱말 지우기)
    repl(n, s) { ph.user = ph.user.slice(0, ph.caret - n) + s + ph.user.slice(ph.caret); ph.caret = ph.caret - n + s.length; ph.wordStart = ph.caret; emit(); },
    // 자판이 setSelection 으로 caret 만 옮김(글 안 바뀜 -> onChanged 없음 · 손님 칸 caret 은 그대로)
    caretTo(i) { ph.caret = i; ph.wordStart = i; },
    // 자판이 화살표 키 이벤트를 보냄 -> 손님 칸 caret 이 움직이고 폰 칸은 그대로(키를 앱이 받아 처리했다고 가정)
    dpad(dir, n) { for (let k = 0; k < n; k++) remote.inputKey(dir); },
    // 자판 도구줄 '전체 선택 + 붙여넣기' -> 글 전체가 s 로
    selectAllPaste(s) { ph.sent = 0; ph.user = s; ph.caret = s.length; ph.wordStart = ph.caret; emit(); },
    // 자판을 닫았다 다시 엶(_openKeyboardUnlocked)
    reopen() { st.resetField(); prev = field(); },
    // 괄호 자동 짝: '(' 를 치면 '()' 가 한 번에 들어오고 caret 은 가운데
    pair(p) { ph.user = ph.user.slice(0, ph.caret) + p + ph.user.slice(ph.caret); ph.caret += 1; ph.wordStart = ph.caret; emit(); },
    // 닫는 괄호 덮어쓰기(글 안 바뀜 · caret 만 한 칸)
    overtype() { ph.caret += 1; ph.wordStart = ph.caret; },
  };
  ops(A);
  return { remote, ideal: ph.base + ph.user, phone: ph.user, ph };
}

// ---------------------------------------------------------------- 낱말 흉내 도우미
const W = (A, list) => list.forEach((s) => A.w(s));
const R0 = '메모:'; // 손님 PC 칸에 원래 있던 글
const LONG = '가나다라마바사아자차카타파하'.repeat(15) + '끝'; // 211자
const cases = [];
const C = (group, name, ops, opt = {}) => cases.push({ group, name, ops, ...opt });

// ── 삼성 천지인 (ㅣ·ㆍ·ㅡ 조합, 같은 자음 키 거듭 누름)
C('천지인', '이준열', (A) => W(A, ['ㅇ', '이', '잊', '이즈', '이주', '이준', '이준ㅇ', '이준ㅇᆞ', '이준ㅇᆢ', '이준여', '이준연', '이준열']));
C('천지인', '안녕하세요', (A) => W(A, ['ㅇ', '이', '아', '안', '안ㄴ', '안ㄴᆞ', '안ㄴᆢ', '안녀', '안녕', '안녕ㅅ', '안녕ㅎ', '안녕히', '안녕하', '안녕핫', '안녕하ㅅᆞ', '안녕하서', '안녕하세', '안녕하셍', '안녕하세ㅇᆞ', '안녕하세ㅇᆢ', '안녕하세요']));
C('천지인', '획 추가 이→아→야', (A) => W(A, ['ㅇ', '이', '아', '야']));
C('천지인', '으→우→유', (A) => W(A, ['ㅇ', '으', '우', '유']));
C('천지인', '아→애', (A) => W(A, ['ㅇ', '이', '아', '애']));
C('천지인', '된소리 ㄱ→ㅋ→ㄲ 받침', (A) => W(A, ['ㄱ', '기', '가', '각', '갘', '갂']));
C('천지인', '된소리 받침 넘김 가끼', (A) => W(A, ['ㄱ', '기', '가', '각', '갘', '갂', '가끼']));
C('천지인', '받침이 다음 글자로 이준→이주녀', (A) => W(A, ['ㅇ', '이', '잊', '이즈', '이주', '이준', '이준ᆞ', '이준ᆢ', '이주녀']));
C('천지인', 'ㄴㄹ 키 두 번 단→달', (A) => W(A, ['ㄷ', '디', '다', '단', '달']));
C('천지인', '겹받침 값→갑시', (A) => W(A, ['ㄱ', '기', '가', '갑', '값', '갑시']));
C('천지인', '띄어쓰기 안녕 하세요', (A) => { W(A, ['ㅇ', '이', '아', '안', '안ㄴ', '안ㄴᆞ', '안ㄴᆢ', '안녀', '안녕']); A.ins(' '); W(A, ['ㅅ', 'ㅎ', '히', '하', '핫', '하ㅅᆞ', '하서', '하세', '하셍', '하세ㅇᆞ', '하세ㅇᆢ', '하세요']); });
C('천지인', '조합 중 지우기 인→이→ㅇ→아', (A) => W(A, ['ㅇ', '이', '인', '이', 'ㅇ', '이', '아']));
C('천지인', '조합 중 다 지움(빈 낱말)', (A) => W(A, ['ㅇ', '이', 'ㅇ', '']));

// ── 쿼티 2벌식
C('쿼티', '이준열', (A) => W(A, ['ㅇ', '이', '잊', '이주', '이준', '이준ㅇ', '이준여', '이준열']));
C('쿼티', '닭+ㅏ→달가', (A) => W(A, ['ㄷ', '다', '달', '닭', '달가']));
C('쿼티', '겹받침 넋→넋이', (A) => W(A, ['ㄴ', '너', '넉', '넋', '넋ㅇ', '넋이']));
C('쿼티', '겹받침 넋+ㅏ→넉사', (A) => W(A, ['ㄴ', '너', '넉', '넋', '넉사']));
C('쿼티', 'ㄺ 읽고', (A) => W(A, ['ㅇ', '이', '일', '읽', '읽ㄱ', '읽고']));
C('쿼티', '조합 중 지우기 인→이', (A) => W(A, ['ㅇ', '이', '인', '이']));
C('쿼티', '확정 뒤 지우기 한글→한', (A) => { W(A, ['ㅎ', '하', '한', '한ㄱ', '한그', '한글']); A.ins(' '); A.bs(); A.bs(); });
C('쿼티', '자음만 ㅋㅋㅋ', (A) => W(A, ['ㅋ', 'ㅋㅋ', 'ㅋㅋㅋ']));
C('쿼티', 'Gboard 빈 값 거침 이준열', (A) => ['ㅇ', '이', '잊', '이주', '이준', '이준ㅇ', '이준여', '이준열'].forEach((s) => A.w2(s)));
C('쿼티', '조합 중 엔터 한\\n', (A) => { W(A, ['ㅎ', '하', '한']); A.ins('\n'); });

// ── 섞기 · 띄어쓰기 · 엔터
C('섞기', '한글+영문+숫자', (A) => { W(A, ['ㄱ', '가']); A.ins('a'); A.ins('b'); A.ins('1'); A.ins('2'); W(A, ['ㄴ', '나']); });
C('섞기', '기호 가!?@#', (A) => { W(A, ['ㄱ', '가']); ['!', '?', '@', '#'].forEach((c) => A.ins(c)); });
C('섞기', '숫자 123 (앞 1 과 같은 글자)', (A) => { A.ins('1'); A.ins('2'); A.ins('3'); });
C('섞기', '1 치고 지우기', (A) => { A.ins('1'); A.bs(); A.ins('1'); A.ins('1'); A.bs(); });
C('섞기', '띄어쓰기·엔터', (A) => { W(A, ['ㅇ', '아', '안']); A.ins(' '); A.ins('a'); A.ins('\n'); A.ins('b'); A.ins(' '); A.ins(' '); });
C('섞기', '엔터 연속', (A) => { A.ins('a'); A.ins('\n'); A.ins('\n'); A.ins('\n'); });
C('섞기', '주소창 www.naver.com', (A) => { 'www.naver.com'.split('').forEach((c) => A.ins(c)); });
C('섞기', '안녕2개', (A) => { W(A, ['ㅇ', '아', '안', '안ㄴ', '안녀', '안녕']); A.ins('2'); W(A, ['ㄱ', '개']); });

// ── 자동 고침 · 자동 띄어쓰기 · 예측
C('고침', '자동 고침 teh␣→the␣', (A) => { A.ins('t'); A.ins('e'); A.ins('h'); A.repl(3, 'the '); });
C('고침', '앞 낱말 고침 I lvoe you→love', (A) => { 'I lvoe you'.split('').forEach((c) => A.ins(c)); A.repl(8, 'love you'); });
C('고침', '자동 띄어쓰기 마침표 뒤', (A) => { W(A, ['ㄴ', '네']); A.ins('.'); A.ins(' '); W(A, ['ㄴ', '네']); });
C('고침', '자동 띄어쓰기(마침표+공백 한 번에)', (A) => { W(A, ['ㄴ', '네']); A.ins('. '); A.ins('O'); A.ins('K'); });
C('고침', '예측 고르기 안녕ㅎ→안녕하세요␣', (A) => { W(A, ['ㅇ', '아', '안', '안ㄴ', '안녀', '안녕', '안녕ㅎ']); A.repl(3, '안녕하세요 '); });
C('고침', '예측 고르기 hel→hello␣', (A) => { A.ins('h'); A.ins('e'); A.ins('l'); A.repl(3, 'hello '); });
C('고침', '긴 문장 앞부분 교정(200자 뒤)', (A) => { A.ins(LONG); A.caretTo(LONG.length); A.repl(LONG.length, '고침' + LONG.slice(2)); });
C('고침', '대문자 자동 i→I', (A) => { A.ins('i'); A.repl(1, 'I'); A.ins(' '); });

// ── 붙여 넣기
C('붙여넣기', '짧은 글 abc', (A) => { A.ins('abc'); });
C('붙여넣기', '긴 글 2000자', (A) => { A.ins('긴글'.repeat(1000)); });
C('붙여넣기', '글 뒤에 붙여넣기', (A) => { W(A, ['ㄱ', '가']); A.ins(' 붙인 글'); });
C('붙여넣기', '전체 선택+붙여넣기(clipboard 갈래)', (A) => { A.ins('abc'); A.selectAllPaste('NEW'); }, { expect: (r) => R0 + 'abcNEW', note: '원래 설계(클립보드 갈래)대로 기존 글 뒤에 붙음 · 폰 화면과는 다름(정보)' });

// ── 커서 이동
C('커서', 'setSelection 가운데 입력 abc→axbc', (A) => { A.ins('a'); A.ins('b'); A.ins('c'); A.caretTo(1); A.ins('x'); });
C('커서', 'setSelection 가운데 한글 조합', (A) => { A.ins('a'); A.ins('b'); A.caretTo(1); W(A, ['ㄱ', '가', '각']); });
C('커서', 'setSelection 맨 앞(211자) 입력', (A) => { A.ins(LONG); A.caretTo(0); A.ins('x'); A.ins('y'); });
C('커서', 'setSelection 가운데 지우기', (A) => { A.ins('abcd'); A.caretTo(2); A.bs(); });
C('커서', '화살표 키 이벤트(손님 caret 도 같이)', (A) => { A.ins('a'); A.ins('b'); A.ins('c'); A.dpad('VK_LEFT', 2); A.ins('x'); }, { expect: () => R0 + 'axbc', note: '폰 칸은 끝에 x · 손님 칸은 a 뒤에 x — 둘이 달라도 손님 칸이 맞음' });

// ── 지우기 끝자리
C('지우기', '빈 칸에서 지우기 3번(기존 글 지움)', (A) => { A.bs(); A.bs(); A.bs(); });
C('지우기', '1024 넘어 지우기(1030번)', (A) => { for (let i = 0; i < 1030; i++) A.bs(); }, { r0: 'x'.repeat(2000) });
C('지우기', '다 지운 뒤 다시 입력', (A) => { for (let i = 0; i < 1024; i++) A.bs(); W(A, ['ㄱ', '가']); A.ins('1'); }, { r0: 'y'.repeat(1100) });
C('지우기', '다 지운 뒤 1a 치고 앞 1 지움(알려진 한계)', (A) => { for (let i = 0; i < 1024; i++) A.bs(); A.ins('1'); A.ins('a'); A.caretTo(1); A.bs(); }, { r0: 'z'.repeat(1100), known: true, note: '1024번 다 지운 뒤에만 · 클립보드 갈래 오판 · 세 판 같음' });
C('지우기', '낱말 통째 지우기 hello world→hello ', (A) => { 'hello world'.split('').forEach((c) => A.ins(c)); A.repl(5, ''); });
C('지우기', '길게 눌러 20번', (A) => { A.ins('abcdefghijklmnopqrstuvwxyz'); for (let i = 0; i < 20; i++) A.bs(); });

// ── 이모지
C('이모지', '이모지 넣기 😀', (A) => { A.ins('a'); A.ins('😀'); });
C('이모지', '이모지 지우기 a😀→a', (A) => { A.ins('a'); A.ins('😀'); A.bs(); });
C('이모지', '이모지 바꿈 😀→😁(예측)', (A) => { A.ins('😀'); A.repl(2, '😁'); });
C('이모지', '결합 이모지 👍🏽 지우기', (A) => { A.ins('a'); A.ins('👍🏽'); A.bs(4); });

// ── 괄호 쌍
C('괄호', '자동 짝 ( → () → (a) → ) 덮어씀', (A) => { A.pair('()'); A.ins('a'); A.overtype(); A.ins('b'); }, { expect: () => R0 + '(a)b' });
C('괄호', '따로 들어온 ( ) 사이에 a', (A) => { A.ins('('); A.ins(')'); A.caretTo(1); A.ins('a'); });
C('괄호', '자동 짝 따옴표 ""', (A) => { A.ins('x'); A.pair('""'); A.ins('y'); A.overtype(); }, { expect: () => R0 + 'x"y"' });
C('괄호', '자동 짝 《》 + 한글', (A) => { A.ins('x'); A.pair('《》'); W(A, ['ㅊ', '채', '책']); A.overtype(); }, { expect: () => R0 + 'x《책》' });

// ── 자판 다시 열기
C('다시열기', '안녕 / 자판 닫고 열기 / 하세요', (A) => { W(A, ['ㅇ', '아', '안', '안ㄴ', '안녀', '안녕']); A.reopen(); W(A, ['ㅎ', '하', '핫', '하세', '하셍', '하세요']); });

// ---------------------------------------------------------------- 돌리기
const fns = { OLD, FIX, V2, ADDON };
const rows = [];
let pass = { OLD: 0, FIX: 0, V2: 0, ADDON: 0 };
for (const c of cases) {
  const r0 = c.r0 ?? R0;
  const row = { c };
  for (const [k, fn] of Object.entries(fns)) {
    const res = run(fn, c.ops, r0);
    const want = c.expect ? c.expect(res) : res.ideal;
    const ok = res.remote.text === want;
    if (ok) pass[k]++;
    row[k] = { ok, got: res.remote.text, want, back: res.remote.back, keys: res.remote.keys, strings: res.remote.strings, strChars: res.remote.strChars, keyRoute: res.ph.keyRoute, changes: res.ph.changes, log: res.remote.log };
  }
  rows.push(row);
}
const short = (s) => { const t = s.length > 26 ? s.slice(0, 11) + '…' + s.slice(-11) + `(${s.length})` : s; return JSON.stringify(t); };
console.log('번호 | 묶음 | 경우 | 옛(OLD) | 고침(FIX) | V2 | FIX 키: VK_BACK/전체키/글묶음(글자) | 키길');
rows.forEach((row, i) => {
  const f = row.FIX;
  const mark = (x) => (x.ok ? 'OK ' : 'FAIL ' + short(x.got));
  console.log(`${String(i + 1).padStart(2)} | ${row.c.group} | ${row.c.name} | ${mark(row.OLD)} | ${mark(row.FIX)} | ${mark(row.V2)} | ${f.back}/${f.keys}/${f.strings}(${f.strChars}) | ${f.keyRoute}${row.c.note ? '  ※' + row.c.note : ''}`);
  if (VERBOSE) { console.log('     want', short(row.FIX.want)); console.log('     FIX keys', row.FIX.log.slice(0, 40).join(' ')); }
});
console.log(`\n합계 ${cases.length}가지 — OLD 통과 ${pass.OLD} · FIX 통과 ${pass.FIX} · V2 통과 ${pass.V2} · ADDON(덧붙임 0001) 통과 ${pass.ADDON}`);
const failFix = rows.filter((r) => !r.FIX.ok).map((r) => r.c.name);
const failV2 = rows.filter((r) => (!r.V2.ok || !r.ADDON.ok) && !r.c.known).map((r) => r.c.name);
const sameKeys = rows.every((r) => r.V2.got === r.ADDON.got && r.V2.keys === r.ADDON.keys && r.V2.strings === r.ADDON.strings);
console.log('V2 와 ADDON 보내는 키·글 똑같음:', sameKeys ? '예' : '아니오');
if (!sameKeys) process.exitCode = 1;
console.log('FIX 실패:', failFix.join(' / ') || '없음');
console.log('V2·ADDON 실패:', failV2.join(' / ') || '없음');
const heavy = rows.filter((r) => r.FIX.back >= 50 && r.c.group !== '지우기').map((r) => `${r.c.name}(VK_BACK ${r.FIX.back} · V2 ${r.V2.back})`);
console.log('VK_BACK 50개 넘는 경우(지우기 묶음 밖):', heavy.join(' / ') || '없음');
if (process.argv.includes('--json')) require('fs').writeFileSync(__dirname + '/sim2_결과.json', JSON.stringify(rows.map((r) => ({ group: r.c.group, name: r.c.name, OLD: r.OLD.ok, FIX: r.FIX.ok, V2: r.V2.ok, back: r.FIX.back, keys: r.FIX.keys, strings: r.FIX.strings })), null, 1));
if (failV2.length) process.exitCode = 1;
