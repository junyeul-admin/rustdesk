// OAMap 천지인 — 조합 중 글자를 원격 화면에 '미리' 보여 주는 셈(보내는 길과 떼어 둠)
//   화면이 바뀔 때마다 무엇을 보낼지만 정한다(지우기 몇 번 + 새로 칠 글자). 실제 전송은 부르는 쪽이 한다.
//   이렇게 떼어 두면 시험이 이 파일만 보고 돌 수 있다(원격 연결 0).
library;

/// 한 번 보낼 거리 — 지우기 back 번 + 글자 text(둘 다 0 일 수 있음)
class CjSend {
  final int back;     // ⌫ 를 몇 번 보낼지
  final String text;  // 그 뒤에 칠 글자
  const CjSend(this.back, this.text);

  bool get isEmpty => back == 0 && text.isEmpty;

  @override
  bool operator ==(Object o) => o is CjSend && o.back == back && o.text == text;
  @override
  int get hashCode => back * 131 + text.hashCode;
  @override
  String toString() => 'CjSend(back: $back, text: "$text")';
}

/// 원격에 지금까지 보낸 '조합 중 글자'를 기억해 두고, 새 모양과 견줘 보낼 거리를 셈한다.
///   보기: 'ㅎ' 보냄 → '히' 가 되면 (지우기 1, '히') → '하' 가 되면 (지우기 1, '하')
///   굳힌 글자(commit)는 지우지 않는다 — 앞에 붙여 그대로 보낸다.
class CjEcho {
  String _shown = '';   // 원격에 떠 있는 '조합 중' 글자
  bool preview;         // 미리 보여 주기(끄면 굳힌 글자만 보냄 — 명령 창처럼 되돌리기가 어색한 곳)

  CjEcho({this.preview = true});

  String get shown => _shown;

  /// 글쇠 하나를 쳤을 때 — commit = 굳힌 글자, next = 지금 조합 중 글자
  CjSend step(String commit, String next) {
    if (!preview) {
      // 미리보기 끔: 조합 중인 것은 안 보냄. 굳힌 글자만 그대로.
      final b = _shown.length;
      _shown = '';
      return CjSend(b, commit);
    }
    // 보이는 글자가 그대로면 아무것도 보내지 않는다(점을 쌓는 중처럼 겉모양이 안 바뀌는 때)
    //   헛되게 지우고 같은 글자를 다시 치면 느려 보이고, 느린 연결에서는 깜빡인다.
    if (commit.isEmpty && next == _shown) return const CjSend(0, '');
    // 조합 중이던 글자를 지우고 → 굳힌 글자 + 새 조합 중 글자
    final back = _shown.length;
    final text = commit + next;
    _shown = next;
    if (back == 0 && text.isEmpty) return const CjSend(0, '');
    return CjSend(back, text);
  }

  /// 조합을 끝낼 때(다른 곳을 누름·창이 닫힘 등) — 조합 중이던 글자를 그대로 굳힌다(지우기 0)
  CjSend finish() {
    _shown = '';
    return const CjSend(0, '');
  }

  /// 원격 쪽을 우리가 모르게 된 때(접속이 끊겼다 붙음 등) — 기억만 비운다
  void forget() { _shown = ''; }
}
