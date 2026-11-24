// OAMap add-on 0004: the remote screen keeps its size when the soft keyboard
// opens; the keyboard covers the lower part and the canvas is moved so the
// remote cursor stays visible above the keyboard.
//
// Why it shrank (mobile/pages/remote_page.dart): Scaffold resizes its body
// for the keyboard (resizeToAvoidBottomInset defaults to true). In portrait
// the shorter body becomes wider than tall, OrientationBuilder reports
// "landscape" and calls canvasModel.updateViewStyle(), which recomputes the
// adaptive scale with a height that already excludes the keyboard
// (CanvasModel.getSize subtracts viewInsets.bottom) -> smaller picture.
//
// Fix: resizeToAvoidBottomInset: false (body keeps full size, no false
// orientation flip, scale unchanged). Moving the canvas is upstream's own
// code: CursorModel.keyHelpToolsVisibilityChanged saves the offset and calls
// CanvasModel.mobileFocusCanvasCursor() (centre the cursor inside the area
// above the keyboard), and restores it when the keyboard closes. We call
// mobileFocusCanvasCursor() once more after the keyboard animation settles
// (same pattern as mobile/pages/view_camera_page.dart didChangeMetrics), and
// keep the floating button above the keyboard ourselves.
//
// Turn off at build time: --dart-define=OAMAP_KEYBOARD_OVERLAY=false

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/model.dart';

const bool kOamapKeyboardOverlay =
    bool.fromEnvironment('OAMAP_KEYBOARD_OVERLAY', defaultValue: true);

/// Scaffold.resizeToAvoidBottomInset for the remote page.
bool get oamapResizeToAvoidBottomInset => !kOamapKeyboardOverlay;

/// Keeps [inner] (the page's FAB location) above the soft keyboard when the
/// Scaffold no longer does it (resizeToAvoidBottomInset: false).
FloatingActionButtonLocation oamapFabLocation(
    FloatingActionButtonLocation inner, BuildContext context) {
  if (!kOamapKeyboardOverlay) return inner;
  final inset = MediaQuery.of(context).viewInsets.bottom;
  if (inset <= 0) return inner;
  return _AboveKeyboardFabLocation(inner, inset);
}

class _AboveKeyboardFabLocation extends FloatingActionButtonLocation {
  final FloatingActionButtonLocation inner;
  final double keyboardInset;
  const _AboveKeyboardFabLocation(this.inner, this.keyboardInset);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) {
    final o = inner.getOffset(g);
    final maxDy = g.scaffoldSize.height -
        keyboardInset -
        g.floatingActionButtonSize.height -
        kFloatingActionButtonMargin;
    return Offset(o.dx, o.dy > maxDy ? maxDy : o.dy);
  }

  // Scaffold compares locations to decide whether to animate the FAB.
  @override
  bool operator ==(Object other) =>
      other is _AboveKeyboardFabLocation &&
      other.inner.runtimeType == inner.runtimeType &&
      other.keyboardInset == keyboardInset;

  @override
  int get hashCode => Object.hash(inner.runtimeType, keyboardInset);
}

/// remote_page didChangeMetrics -> re-centre the cursor above the keyboard
/// once the keyboard has finished opening.
class OamapKeyboardCanvas {
  final FFI ffi;
  double _lastBottom = 0;
  Timer? _timer;

  OamapKeyboardCanvas(this.ffi);

  void onMetricsChanged(bool keyboardVisible) {
    if (!kOamapKeyboardOverlay) return;
    final bottom = MediaQueryData.fromView(ui.window).viewInsets.bottom;
    _timer?.cancel();
    if (bottom <= 0 || !keyboardVisible) {
      // Closing: upstream restores the saved offset; just remember the state.
      _lastBottom = bottom;
      return;
    }
    // The user panned / zoomed while the keyboard is open: leave it alone.
    if (ffi.cursorModel.lastKeyboardIsVisible &&
        ffi.canvasModel.isMobileCanvasChanged) {
      return;
    }
    _timer = Timer(const Duration(milliseconds: 150), () {
      final now = MediaQueryData.fromView(ui.window).viewInsets.bottom;
      if (now > 0 && now != _lastBottom) {
        _lastBottom = now;
        ffi.canvasModel.mobileFocusCanvasCursor();
      }
    });
  }

  void dispose() => _timer?.cancel();
}
