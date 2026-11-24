// OAMap add-on 0011: the remote mouse pointer on the phone is bigger and has a
// yellow outline (owner's pick "C"), so it is easy to find on white documents
// and dark screens alike. Only the picture on the phone changes; the remote
// PC's pointer is untouched. Whatever shape the PC sends (arrow, I-beam,
// hand) gets the same outline. The hotspot stays exactly where upstream puts
// it: the picture grows around the hotspot.
//
// Settings > OAMap: pointer size 1x / 1.5x / 2x (default 1.5x).
// Turn off at build time: --dart-define=OAMAP_CURSOR_PLUS=false

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/platform_model.dart';

const bool kOamapCursorPlus =
    bool.fromEnvironment('OAMAP_CURSOR_PLUS', defaultValue: true);

const String kOamapCursorScaleKey = 'oamap-cursor-scale';
const List<double> kOamapCursorScales = [1.0, 1.5, 2.0];

double get oamapCursorScale {
  if (!kOamapCursorPlus) return 1.0;
  final v = double.tryParse(bind.mainGetLocalOption(key: kOamapCursorScaleKey));
  return (v != null && kOamapCursorScales.contains(v)) ? v : 1.5;
}

/// Same inputs as utils/image.dart ImagePainter (x, y = top-left in picture
/// units, scale = canvas scale) plus the hotspot, so the caller only swaps the
/// painter.
class OamapCursorPainter extends CustomPainter {
  OamapCursorPainter({
    required this.image,
    required this.x,
    required this.y,
    required this.scale,
    required this.hotx,
    required this.hoty,
    required this.k,
  });

  final ui.Image image;
  final double x;
  final double y;
  final double scale;
  final double hotx;
  final double hoty;
  final double k;

  static const _yellow = Color(0xFFEF9F27);
  static const _black = Color(0xFF000000);

  @override
  void paint(Canvas canvas, Size size) {
    if (x.isNaN || y.isNaN || scale <= 0) return;
    // Hotspot on screen (logical px), as upstream would draw it.
    final hx = (x.toInt().toDouble() + hotx) * scale;
    final hy = (y.toInt().toDouble() + hoty) * scale;
    final s = scale * k;
    final left = hx - hotx * s;
    final top = hy - hoty * s;
    final dst = Rect.fromLTWH(
        left, top, image.width * s, image.height * s);
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final q = FilterQuality.medium;
    // Outline = the pointer's own shape, tinted and shifted around it.
    void ring(Color c, double r) {
      final p = Paint()
        ..filterQuality = q
        ..colorFilter = ColorFilter.mode(c, BlendMode.srcIn);
      const dirs = [
        [1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0],
        [0.7, 0.7], [-0.7, 0.7], [0.7, -0.7], [-0.7, -0.7],
      ];
      for (final d in dirs) {
        canvas.drawImageRect(image, src, dst.shift(Offset(d[0] * r, d[1] * r)), p);
      }
    }

    ring(_yellow, 3.0);
    ring(_black, 1.0);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = q);
  }

  @override
  bool shouldRepaint(OamapCursorPainter old) =>
      old.image != image ||
      old.x != x ||
      old.y != y ||
      old.scale != scale ||
      old.hotx != hotx ||
      old.hoty != hoty ||
      old.k != k;
}

// OAMap add-on 0014: only the pointer itself, no stray specks.
//
// Field report: with the yellow outline, the text pointer (I-beam) showed two
// small "0" shapes beside it. They are faint / white specks inside the
// pointer picture the PC sends (invisible on white before); the outline made
// them stand out. The picture is cleaned once per pointer shape: pixels with
// alpha < 24 dropped, then only connected parts at least 25 % the size of the
// biggest part are kept. Until the cleaned copy is ready (one frame) the
// original is drawn. Cleaning never moves the hotspot (same size picture).
const int _kCleanAlpha = 24;
const double _kCleanKeep = 0.25;

final ValueNotifier<int> oamapCursorTick = ValueNotifier<int>(0);
final Map<ui.Image, ui.Image> _oamapClean = <ui.Image, ui.Image>{};
final Set<ui.Image> _oamapCleanBusy = <ui.Image>{};

ui.Image oamapCleanCursor(ui.Image img) {
  final done = _oamapClean[img];
  if (done != null) return done;
  if (_oamapCleanBusy.add(img)) {
    _oamapMakeClean(img).then((r) {
      _oamapClean[img] = r;
    }, onError: (_) {
      _oamapClean[img] = img;
    }).whenComplete(() {
      _oamapCleanBusy.remove(img);
      while (_oamapClean.length > 24) {
        _oamapClean.remove(_oamapClean.keys.first);
      }
      oamapCursorTick.value++;
    });
  }
  return img;
}

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

Future<ui.Image> _oamapMakeClean(ui.Image img) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) return img;
  final w = img.width, h = img.height;
  final out = oamapCleanRgba(bd.buffer.asUint8List(), w, h);
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}
