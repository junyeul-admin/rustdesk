// OAMap add-on 0012 test: OamapComposeSender holds back the composing syllable.
//   cd flutter && flutter test test/oamap_compose_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_hbb/oamap/oamap_input.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue v(String t, int cs, int ce) => TextEditingValue(
    text: t, composing: cs < 0 ? TextRange.empty : TextRange(start: cs, end: ce));

void main() {
  const seed = '11	';
  test('Cheonjiin 세: intermediate jamo never sent', () {
    final out = <String>[];
    final s = OamapComposeSender(seed, idle: const Duration(hours: 1));
    void go(String t, int cs) =>
        s.handle(v(t, cs, t.length), t, true, (o, n) => out.add(n));
    go('${seed}하', seed.length); // composing 하
    go('${seed}핫', seed.length);
    go('${seed}하ㅅᆞ', seed.length + 1); // 하 committed, ㅅᆞ composing
    go('${seed}하서', seed.length + 1);
    go('${seed}하세', seed.length + 1);
    go('${seed}하세ㅇ', seed.length + 2);
    go('${seed}하세요', seed.length + 2);
    s.flush();
    expect(out, ['${seed}하', '${seed}하세', '${seed}하세요']);
    expect(out.any((x) => x.contains('ㅅ') || x.contains('ᆞ') || x.contains('8')), false);
  });
  test('commitOnly off = every change sent', () {
    final out = <String>[];
    final s = OamapComposeSender(seed, idle: const Duration(hours: 1));
    s.handle(v('${seed}ㄱ', 3, 4), '${seed}ㄱ', false, (o, n) => out.add(n));
    s.handle(v('${seed}가', 3, 4), '${seed}가', false, (o, n) => out.add(n));
    expect(out, ['${seed}ㄱ', '${seed}가']);
  });
  test('no composing range (English) = sent at once', () {
    final out = <String>[];
    final s = OamapComposeSender(seed, idle: const Duration(hours: 1));
    s.handle(v('${seed}a', -1, -1), '${seed}a', true, (o, n) => out.add(n));
    expect(out, ['${seed}a']);
  });
  test('idle flush sends the held syllable', () async {
    final out = <String>[];
    final s = OamapComposeSender(seed, idle: const Duration(milliseconds: 10));
    s.handle(v('${seed}요', 3, 4), '${seed}요', true, (o, n) => out.add(n));
    expect(out, isEmpty);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(out, ['${seed}요']);
  });
  test('reset clears without sending', () {
    final out = <String>[];
    final s = OamapComposeSender(seed, idle: const Duration(hours: 1));
    s.handle(v('${seed}가', 3, 4), '${seed}가', true, (o, n) => out.add(n));
    s.reset(seed);
    s.flush();
    expect(out, isEmpty);
  });
}
