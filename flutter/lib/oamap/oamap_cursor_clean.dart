// OAMap add-on 0014 (pure part, no app imports so the Dart test can run
// before the Rust bridge is generated): drop faint pixels (alpha < 24) and
// parts smaller than 25 % of the biggest connected part of a pointer picture.
import 'dart:typed_data';

const int _kCleanAlpha = 24;
const double _kCleanKeep = 0.25;

/// Pure part (tested): rgba bytes of a w x h picture -> cleaned copy.
Uint8List oamapCleanRgba(Uint8List rgba, int w, int h) {
  final n = w * h;
  final label = Int32List(n);
  final sizes = <int>[0];
  final stack = <int>[];
  for (var i = 0; i < n; i++) {
    if (label[i] != 0 || rgba[i * 4 + 3] < _kCleanAlpha) continue;
    final id = sizes.length;
    var size = 0;
    label[i] = id;
    stack.add(i);
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      size++;
      final px = p % w, py = p ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = px + dx, ny = py + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final q = ny * w + nx;
          if (label[q] != 0 || rgba[q * 4 + 3] < _kCleanAlpha) continue;
          label[q] = id;
          stack.add(q);
        }
      }
    }
    sizes.add(size);
  }
  var biggest = 0;
  for (final s in sizes) {
    if (s > biggest) biggest = s;
  }
  final out = Uint8List.fromList(rgba);
  for (var i = 0; i < n; i++) {
    final l = label[i];
    if (l == 0 || sizes[l] < biggest * _kCleanKeep) {
      out[i * 4] = 0;
      out[i * 4 + 1] = 0;
      out[i * 4 + 2] = 0;
      out[i * 4 + 3] = 0;
    }
  }
  return out;
}

