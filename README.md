# syphon_server

A macOS Flutter plugin that publishes Flutter widget frames as a Syphon Metal server for real-time sharing with Syphon clients (for example VJ or recording apps).

## Platform support

| Platform | Supported |
| --- | --- |
| macOS | ✅ |
| iOS / Android / Windows / Linux / Web | ❌ |

## Features

- Start and stop a Syphon Metal server
- Capture a dedicated offscreen widget via `RepaintBoundary`
- Convert frames to RGBA and publish them through a Metal texture
- Automatically publish the first frame after a successful `start()`

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  syphon_server:
    path: ../syphon_server # or your package source
```

Then run:

```bash
flutter pub get
```

## Important: disable App Sandbox

Syphon relies on distributed notifications and cross-process IOSurface / Metal sharing.  
**App Sandbox must be disabled**, or the server will fail to start.

In your macOS app entitlements (Debug and Release):

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

Rebuild the app completely after changing entitlements.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:syphon_server/syphon_server.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final controller = SyphonServerController();

  @override
  void dispose() {
    controller.stop();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SyphonServer(
      controller: controller,
      // Frame published to Syphon clients (fixed size recommended)
      syphonView: Container(
        width: 1920,
        height: 1080,
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'Syphon Output',
          style: TextStyle(color: Colors.white),
        ),
      ),
      // Local UI
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => controller.start(name: 'My Syphon Server'),
              child: const Text('Start'),
            ),
            FilledButton(
              onPressed: controller.stop,
              child: const Text('Stop'),
            ),
            FilledButton(
              onPressed: controller.publishWidget,
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }
}
```

When the published content changes, wait for the next frame and call `publishWidget()` again:

```dart
setState(() { /* update syphonView content */ });
await WidgetsBinding.instance.endOfFrame;
await controller.publishWidget();
```

## API overview

### `SyphonServer`

Wraps the local `child` and mounts an offscreen `syphonView` while the server is running.

| Parameter | Description |
| --- | --- |
| `controller` | A `SyphonServerController` |
| `syphonView` | Widget to publish (fixed width/height recommended) |
| `child` | Local on-screen UI |

### `SyphonServerController`

| Member | Description |
| --- | --- |
| `start({name})` | Starts the native server, mounts the offscreen view, and publishes the first frame |
| `stop()` | Stops the server and unmounts the offscreen view |
| `isRunning()` | Returns whether the native server is running |
| `publishWidget()` | Captures the current `syphonView` and publishes it |
| `showSyphonView` | `ValueNotifier<bool>` for whether the offscreen view is mounted |
| `dispose()` | Releases controller resources |

## Example

See [`example/`](example/):

```bash
cd example
flutter run -d macos
```