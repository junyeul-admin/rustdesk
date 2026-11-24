// OAMap add-on 0005: the remote screen no longer shakes while the mouse
// cursor moves (mobile, mouse mode, picture larger than the phone screen).
//
// Why it shook (models/model.dart CursorModel.updatePan): when the picture is
// larger than the visible area (zoomed in, 'original' scale, or 'adaptive'
// with a different aspect ratio), the canvas is panned as soon as the cursor
// passes the CENTRE of the visible rect (`_x + dx > cx`, cx = r.center.dx).
// From then on every finger move pans the whole picture by the same amount,
// so the screen moves with every small cursor move.
//
// Fix: pan only when the cursor reaches an edge band (15 % of the visible
// width / height). Inside the band-free middle the cursor moves and the
// picture stays still; at the edge the picture follows smoothly (same per-
// move amount as upstream, so no jumps).
//
// Second cause: a false orientation flip re-fitted the picture when the soft
// keyboard opened (see oamap_view.dart). [oamapIsRealRotation] keeps the
// re-fit for real device rotations only, even if add-on 0004 is turned off.
//
// Turn off at build time: --dart-define=OAMAP_NO_SHAKE=false

import 'package:flutter/widgets.dart';

const bool kOamapNoShake =
    bool.fromEnvironment('OAMAP_NO_SHAKE', defaultValue: true);

const double _kEdgeBand = 0.15;

/// Replaces `r.center.dx` in CursorModel.updatePan: the x the cursor must
/// pass (moving by [dx], remote coordinates) before the canvas pans.
double oamapPanEdgeX(Rect r, double dx) {
  if (!kOamapNoShake || dx == 0) return r.center.dx;
  final band = r.width * _kEdgeBand;
  return dx > 0 ? r.right - band : r.left + band;
}

/// Same for y.
double oamapPanEdgeY(Rect r, double dy) {
  if (!kOamapNoShake || dy == 0) return r.center.dy;
  final band = r.height * _kEdgeBand;
  return dy > 0 ? r.bottom - band : r.top + band;
}

/// remote_page OrientationBuilder: re-fit only when the device really
/// rotated (MediaQuery size), not when the body got shorter than wide.
bool oamapIsRealRotation(BuildContext context, Orientation builderOrientation) {
  if (!kOamapNoShake) return true;
  final size = MediaQuery.of(context).size;
  final device =
      size.width > size.height ? Orientation.landscape : Orientation.portrait;
  return device == builderOrientation;
}
