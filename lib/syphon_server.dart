import 'dart:async';
import 'dart:ui' as ui;

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

  /// Registers a listener for start / stop status changes.
  void onStatusListener(SyphonServerStatusListener listener) {
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
    try {
      await _channel.invokeMethod<void>('start', <String, dynamic>{'name': name});
      showSyphonView.value = true;
      await _waitUntilBoundaryReady();
      await publishWidget();
      _notifyStatus(true);
    } catch (error) {
      await _stopInternal(forceNotifyStopped: true);
      rethrow;
    }
  }

  /// Stops the Syphon server and releases native resources.
  /// Notifies status listeners with `false`.
  Future<void> stop() async {
    await _stopInternal();
  }

  /// Returns whether the native server is still running.
  Future<bool> isRunning() async {
    final running = await _channel.invokeMethod<bool>('isRunning');
    return running ?? false;
  }

  Future<void> publishWidget() async {
    final context = _syphonBoundaryKey.currentContext;
    if (context == null) {
      throw StateError('RepaintBoundary is not mounted in the widget tree');
    }
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('RenderRepaintBoundary not found');
    }
    if (!boundary.hasSize || boundary.size.isEmpty) {
      throw StateError('RepaintBoundary has not completed layout');
    }

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
    } finally {
      image.dispose();
    }
  }

  Future<void> _stopInternal({bool forceNotifyStopped = false}) async {
    if (!_disposed) {
      showSyphonView.value = false;
    }
    try {
      await _channel.invokeMethod<void>('stop');
    } finally {
      _notifyStatus(false, force: forceNotifyStopped);
    }
  }

  void _notifyStatus(bool running, {bool force = false}) {
    if (!force && _running == running) {
      return;
    }
    _running = running;
    final listeners = List<SyphonServerStatusListener>.of(_statusListeners);
    for (final listener in listeners) {
      listener(running);
    }
  }

  Future<void> _waitUntilBoundaryReady() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final context = _syphonBoundaryKey.currentContext;
      final boundary = context?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null && boundary.hasSize && !boundary.size.isEmpty) {
        return;
      }
      final frame = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!frame.isCompleted) {
          frame.complete();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
      await frame.future;
    }
  }

  void dispose() {
    _disposed = true;
    _statusListeners.clear();
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
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.showSyphonView,
      builder: (context, showSyphonView, _) {
        if (!showSyphonView) {
          return widget.child;
        }
        // Positioned does not affect Stack size, so a large offscreen view
        // will not expand the local layout.
        return Stack(
          children: [
            Positioned(
              left: -10000,
              top: -10000,
              child: RepaintBoundary(
                key: widget.controller._syphonBoundaryKey,
                child: widget.syphonView,
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
