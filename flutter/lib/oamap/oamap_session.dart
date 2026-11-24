// OAMap add-on 0003: keep an outgoing session alive while the phone is in
// another app, and recover fast when it was dropped anyway.
//
// 1. While the remote page is open, a foreground service
//    (android ClientSessionService.kt, "client_session_fgs" method call in
//    MainActivity.kt) keeps the process from being frozen / network
//    restricted. Without it the peer hears nothing for 30 s
//    (src/server/connection.rs SEC30) and closes the session.
// 2. Back from the background after >= 25 s: ask the peer for a fresh frame
//    (sessionRefresh). Only if no frame arrives within 5 s, reconnect. A live
//    session is never torn down (FfiModel.reconnect closes a connected
//    session, and a click-to-accept host would have to accept again).
//
// Turn off at build time: --dart-define=OAMAP_KEEP_ALIVE=false

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../common.dart';
import '../models/model.dart';

const bool kOamapKeepAlive =
    bool.fromEnvironment('OAMAP_KEEP_ALIVE', defaultValue: true);

const _kAwayBeforeProbe = Duration(seconds: 25);
const _kProbeWait = Duration(seconds: 5);

class OamapSessionKeeper {
  final FFI ffi;
  DateTime? _pausedAt;
  Timer? _probeTimer;
  VoidCallback? _imageListener;

  OamapSessionKeeper(this.ffi);

  /// remote_page initState.
  void open() {
    if (!kOamapKeepAlive || !isAndroid) return;
    ffi.invokeMethod("client_session_fgs", true);
  }

  /// remote_page dispose (call before any await).
  void close() {
    _cancelProbe();
    if (!kOamapKeepAlive || !isAndroid) return;
    unawaited(ffi.invokeMethod("client_session_fgs", false));
  }

  /// remote_page didChangeAppLifecycleState.
  void onLifecycle(AppLifecycleState state) {
    if (!kOamapKeepAlive || !isAndroid) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      _cancelProbe();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= _kAwayBeforeProbe) {
        _probe();
      }
    }
  }

  void _probe() {
    _cancelProbe();
    if (ffi.closed) return;
    var gotFrame = false;
    _imageListener = () => gotFrame = true;
    ffi.imageModel.addListener(_imageListener!);
    // common.dart sessionRefreshVideo: asks the peer for a key frame.
    unawaited(sessionRefreshVideo(ffi.sessionId, ffi.ffiModel.pi));
    _probeTimer = Timer(_kProbeWait, () {
      _removeListener();
      if (!gotFrame && !ffi.closed) {
        ffi.ffiModel.reconnect(ffi.dialogManager, ffi.sessionId, false);
      }
    });
  }

  void _removeListener() {
    final l = _imageListener;
    if (l != null) {
      try {
        ffi.imageModel.removeListener(l);
      } catch (_) {}
    }
    _imageListener = null;
  }

  void _cancelProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _removeListener();
  }
}
