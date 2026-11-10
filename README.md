# syphon_server

A macOS Flutter plugin that publishes Flutter widget frames as a [Syphon](https://github.com/Syphon/Syphon-Framework) Metal server for real-time sharing with Syphon clients (for example VJ or recording apps).

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
- Status listeners for start / stop, including stops caused by start errors

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  syphon_server: ^0.0.3
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

  void _onStatus(bool running) {
    debugPrint('Syphon server ${running ? 'started' : 'stopped'}');
  }

  @override
  void initState() {
    super.initState();
    controller.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    controller.stop();
    controller.removeStatusListener(_onStatus);
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

## Status listeners

```dart
void onStatus(bool running) {
  // true  -> start succeeded
  // false -> stop(), or start() failed and was cleaned up
}

controller.addStatusListener(onStatus);
controller.removeStatusListener(onStatus);
```

- `start()` success → notifies `true`
- `stop()` → notifies `false`
- `start()` failure → cleans up native resources, notifies `false`, then rethrows

## API overview

### `SyphonServer`

Wraps the local `child` and keeps an offscreen `syphonView` in a stable `Stack` (shown via `Offstage` while the server is running), so toggling Syphon does not remount `child`.

| Parameter | Description |
| --- | --- |
| `controller` | A `SyphonServerController` |
| `syphonView` | Widget to publish (fixed width/height recommended) |
| `child` | Local on-screen UI |

### `SyphonServerController`

| Member | Description |
| --- | --- |
| `start({name})` | Starts the native server, shows the offscreen view, publishes the first frame, notifies `true` |
| `stop()` | Stops the server, hides the offscreen view, notifies `false` |
| `isRunning()` | Returns whether the native server is running |
| `isStarted` | Whether this controller currently considers the server started |
| `publishWidget()` | Waits until the offscreen boundary is laid out and painted, then captures and publishes it |
| `addStatusListener(listener)` | Adds a start / stop status listener |
| `removeStatusListener(listener)` | Removes a status listener |
| `showSyphonView` | `ValueNotifier<bool>` for whether the offscreen view is shown |
| `dispose()` | Releases controller resources and clears listeners |

## Example

See [`example/`](example/):

```bash
cd example
flutter run -d macos
```

After starting the server, use a Syphon client (for example Syphon Recorder) and select `Syphon Server Example`.

## License and dependencies

- This plugin: see the repository license
- Bundled [Syphon.xcframework](https://github.com/Syphon/Syphon-Framework) (Metal server)
