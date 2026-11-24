// OAMap add-on 0014 test: stray specks removed from the pointer picture.
import 'dart:typed_data';
import 'package:flutter_hbb/oamap/oamap_cursor.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List pic(int w, int h, List<List<int>> on) {
  final b = Uint8List(w * h * 4);
  for (final p in on) {
    final i = (p[1] * w + p[0]) * 4;
    b[i] = 255; b[i + 1] = 255; b[i + 2] = 255; b[i + 3] = p.length > 2 ? p[2] : 255;
  }
  return b;
}
int alphaAt(Uint8List b, int w, int x, int y) => b[(y * w + x) * 4 + 3];

void main() {
  test('I-beam kept, two specks removed', () {
    final on = <List<int>>[];
    for (var y = 0; y < 12; y++) { on.add([2, y]); on.add([3, y]); }
    on.add([8, 2]); on.add([8, 8]);
    final out = oamapCleanRgba(pic(10, 12, on), 10, 12);
    expect(alphaAt(out, 10, 2, 5), 255);
    expect(alphaAt(out, 10, 8, 2), 0);
    expect(alphaAt(out, 10, 8, 8), 0);
  });
  test('faint pixels dropped', () {
    final on = <List<int>>[[0, 0], [1, 0], [2, 0], [3, 0], [5, 5, 10]];
    final out = oamapCleanRgba(pic(6, 6, on), 6, 6);
    expect(alphaAt(out, 6, 5, 5), 0);
    expect(alphaAt(out, 6, 1, 0), 255);
  });
  test('arrow with two big parts keeps both', () {
    final on = <List<int>>[];
    for (var i = 0; i < 10; i++) { on.add([0, i]); }
    for (var i = 0; i < 6; i++) { on.add([5, i]); }
    final out = oamapCleanRgba(pic(8, 10, on), 8, 10);
    expect(alphaAt(out, 8, 5, 3), 255);
  });
}
