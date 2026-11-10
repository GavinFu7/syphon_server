import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Called when the Syphon server starts (`true`) or stops (`false`),
/// including stops caused by errors during [SyphonServerController.start].
typedef SyphonServerStatusListener = void Function(bool running);

class SyphonServerController {
  /// Must match Swift [SyphonServerPlugin.channelName].
  static const String channelName = 'syphon_server';

  final MethodChannel _channel = const MethodChannel(channelName);
  final GlobalKey _syphonBoundaryKey = GlobalKey();
  final List<SyphonServerStatusListener> _statusListeners =
      <SyphonServerStatusListener>[];

  /// Controls whether the offscreen [SyphonServer.syphonView] is mounted.
  final ValueNotifier<bool> showSyphonView = ValueNotifier(false);

  bool _disposed = false;
  bool _running = false;

  /// Whether this controller considers the server started.
  bool get isStarted => _running;

  /// Adds a listener for start / stop status changes.
  void addStatusListener(SyphonServerStatusListener listener) {
    _statusListeners.add(listener);
  }

  /// Removes a previously registered status listener.
  void removeStatusListener(SyphonServerStatusListener listener) {
    _statusListeners.remove(listener);
  }

  /// Starts the Syphon server. [name] appears in other Syphon clients.
  /// On success, mounts the offscreen view, publishes the first frame, and
  /// notifies status listeners with `true`.
  /// On failure, cleans up, notifies listeners with `false`, then rethrows.
  Future<void> start({String name = 'Syphon Server'}) async {
    _ensureNotDisposed();
    try {
      await _channel.invokeMethod<void>('start', <String, dynamic>{'name': name});
      if (_disposed) {
        await _channel.invokeMethod<void>('stop');
        return;
      }
      showSyphonView.value = true;
      await publishWidget();
      if (_disposed) {
        return;
      }
      _notifyStatus(true);
    } catch (error) {
      await _stopInternal(forceNotifyStopped: true);
      rethrow;
    }
  }

  /// Stops the Syphon server and releases native resources.
  /// Notifies status listeners with `false`.
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await _stopInternal();
  }

  /// Returns whether the native server is still running.
  Future<bool> isRunning() async {
    _ensureNotDisposed();
    final running = await _channel.invokeMethod<bool>('isRunning');
    return running ?? false;
  }

  Future<void> publishWidget() async {
    _ensureNotDisposed();
    Object? lastError;

    // Retry: child widgets (e.g. async setState) can dirty paint between
    // readiness checks and toImage().
    for (var attempt = 0; attempt < 10; attempt++) {
      if (_disposed) {
        throw StateError('SyphonServerController has been disposed');
      }

      final boundary = await _waitUntilBoundaryReady();
      if (boundary == null) {
        lastError = StateError('RepaintBoundary is not ready to capture');
        await _waitForNextFrame();
        continue;
      }

      try {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        try {
          final ByteData? byteData =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (byteData == null) {
            throw StateError('Failed to encode frame pixels');
          }

          final pixels = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );

          await _channel.invokeMethod<void>('publish', <String, dynamic>{
            'width': image.width,
            'height': image.height,
            'pixels': pixels,
          });
          return;
        } finally {
          image.dispose();
        }
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('Syphon publishWidget attempt ${attempt + 1} failed: $error');
        }
        await _waitForNextFrame();
      }
    }

    throw lastError ?? StateError('publishWidget failed');
  }

  Future<void> _stopInternal({bool forceNotifyStopped = false}) async {
    if (!_disposed) {
      showSyphonView.value = false;
    }
    try {
      await _channel.invokeMethod<void>('stop');
    } finally {
      if (!_disposed) {
        _notifyStatus(false, force: forceNotifyStopped);
      } else {
        _running = false;
      }
    }
  }

  void _notifyStatus(bool running, {bool force = false}) {
    if (_disposed) {
      return;
    }
    if (!force && _running == running) {
      return;
    }
    _running = running;
    final listeners = List<SyphonServerStatusListener>.of(_statusListeners);
    for (final listener in listeners) {
      listener(running);
    }
  }

  /// Waits until the offscreen boundary is laid out and painted.
  ///
  /// In debug builds, also waits until [RenderObject.debugNeedsPaint] is false.
  /// In release/profile builds that flag is always false, so after the first
  /// ready layout we wait one extra frame to allow paint to complete.
  Future<RenderRepaintBoundary?> _waitUntilBoundaryReady() async {
    var sawReadyLayout = false;

    for (var attempt = 0; attempt < 60; attempt++) {
      final context = _syphonBoundaryKey.currentContext;
      final boundary = context?.findRenderObject() as RenderRepaintBoundary?;
      final hasLayout =
          boundary != null && boundary.hasSize && !boundary.size.isEmpty;

      if (!hasLayout) {
        sawReadyLayout = false;
        await _waitForNextFrame();
        continue;
      }

      if (kDebugMode && boundary.debugNeedsPaint) {
        sawReadyLayout = false;
        await _waitForNextFrame();
        continue;
      }

      if (!sawReadyLayout) {
        sawReadyLayout = true;
        await _waitForNextFrame();
        continue;
      }

      return boundary;
    }
    return null;
  }

  Future<void> _waitForNextFrame() async {
    final frame = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!frame.isCompleted) {
        frame.complete();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
    await frame.future;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('SyphonServerController has been disposed');
    }
  }

  /// Stops the native server (best-effort) and releases controller resources.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _running = false;
    _statusListeners.clear();
    // Example apps often call stop() without awaiting before dispose().
    if (showSyphonView.value) {
      showSyphonView.value = false;
    }
    unawaited(() async {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {
        // Best-effort cleanup during dispose.
      }
    }());
    showSyphonView.dispose();
  }
}

class SyphonServer extends StatefulWidget {
  const SyphonServer({
    super.key,
    required this.child,
    required this.syphonView,
    required this.controller,
  });

  final Widget child;
  final Widget syphonView;
  final SyphonServerController controller;

  @override
  State<SyphonServer> createState() => _SyphonServerState();
}

class _SyphonServerState extends State<SyphonServer> {
  @override
  Widget build(BuildContext context) {
    // Mount the offscreen view only while the server is started.
    // Do not use Offstage: it skips paint and breaks [RepaintBoundary.toImage].
    // Pass [child] through ValueListenableBuilder so toggling does not remount it.
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.showSyphonView,
      builder: (context, show, child) {
        return Stack(
          children: [
            if (show)
              Positioned(
                left: -10000,
                top: -10000,
                child: RepaintBoundary(
                  key: widget.controller._syphonBoundaryKey,
                  child: widget.syphonView,
                ),
              ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
