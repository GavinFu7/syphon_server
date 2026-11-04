import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class SyphonServerController {
  /// 必須與 Swift 端 [SyphonServerPlugin.channelName] 相同。
  static const String channelName = 'syphon_server';

  final MethodChannel _channel = const MethodChannel(channelName);
  final GlobalKey _syphonBoundaryKey = GlobalKey();

  /// 控制是否掛載離屏 [SyphonServer.syphonView]（供 [SyphonServer] 監聽）。
  final ValueNotifier<bool> showSyphonView = ValueNotifier(false);

  /// 啟動 Syphon Server，[name] 會顯示在其他 Syphon Client 的伺服器列表中。
  /// 成功後會掛載離屏 view，並在 layout 完成後自動 [publishWidget]。
  Future<void> start({String name = 'Syphon Server'}) async {
    await _channel.invokeMethod<void>('start', <String, dynamic>{'name': name});
    showSyphonView.value = true;
    await _waitUntilBoundaryReady();
    await publishWidget();
  }

  bool _disposed = false;

  /// 停止 Syphon Server 並釋放原生資源。
  Future<void> stop() async {
    if (!_disposed) {
      showSyphonView.value = false;
    }
    await _channel.invokeMethod<void>('stop');
  }

  /// 查詢原生端 Server 是否仍在運行。
  Future<bool> isRunning() async {
    final running = await _channel.invokeMethod<bool>('isRunning');
    return running ?? false;
  }

  Future<void> publishWidget() async {
    final context = _syphonBoundaryKey.currentContext;
    if (context == null) {
      throw StateError('RepaintBoundary 尚未掛載到 Widget tree');
    }
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('找不到 RenderRepaintBoundary');
    }
    if (!boundary.hasSize || boundary.size.isEmpty) {
      throw StateError('RepaintBoundary 尚未完成 layout');
    }

    // 將 Widget 繪製結果轉成影像（pixelRatio: 1.0 = 邏輯像素 = 實體像素）
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    try {
      // rawRgba：每個像素 4 bytes（R,G,B,A），原生端可直接寫入 MTLTexture
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        throw StateError('無法編碼畫面資料');
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
        // Positioned 不參與 Stack 尺寸計算，避免 1920x1080 離屏 view 撐爆 layout。
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
