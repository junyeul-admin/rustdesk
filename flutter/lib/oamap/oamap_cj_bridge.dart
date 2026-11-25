// OAMap 천지인 — 자판이 셈한 거리(지우기 수 · 글자)를 원격으로 보내는 다리
//   보내는 길은 RustDesk 가 쓰던 것 그대로: 지우기 = inputKey('VK_BACK') · 글자 = sessionInputString
//   이 파일만 원격에 기댄다(규칙·셈·화면은 기대지 않음) — 그래야 시험이 저 셋을 떼어 돌릴 수 있다.
library;

import '../common.dart';
import '../models/input_model.dart';
import '../models/platform_model.dart'; // bind.sessionInputString

/// 천지인 자판의 onSend 에 그대로 꽂는다.
///   back 번 지우고 text 를 친다(한 글자여도 sessionInputString 으로 — 조합 중 글자는 한 글자가 많다)
void oamapCjSendToRemote({
  required InputModel inputModel,
  required SessionID sessionId,
  required int back,
  required String text,
}) {
  for (var i = 0; i < back; i++) {
    inputModel.inputKey('VK_BACK');
  }
  if (text.isNotEmpty) {
    bind.sessionInputString(sessionId: sessionId, value: text);
  }
}
