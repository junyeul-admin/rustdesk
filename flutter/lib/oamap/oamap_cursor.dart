// OAMap add-on 0011: the remote mouse pointer on the phone is bigger and has a
// yellow outline (owner's pick "C"), so it is easy to find on white documents
// and dark screens alike. Only the picture on the phone changes; the remote
// PC's pointer is untouched. Whatever shape the PC sends (arrow, I-beam,
// hand) gets the same outline. The hotspot stays exactly where upstream puts
// it: the picture grows around the hotspot.
//
// Settings > OAMap: pointer size 1x / 1.5x / 2x (default 1.5x).
// Turn off at build time: --dart-define=OAMAP_CURSOR_PLUS=false

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
