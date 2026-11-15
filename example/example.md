## [lib/main.dart](lib/main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:syphon_server/syphon_server.dart';
import 'output_view.dart';

final SyphonServerController syphonServerController = SyphonServerController();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return SyphonServer(
          syphonView: const OutputView(),
          controller: syphonServerController,
          child: const Home(),
        );
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  void onSyphonServerStatusChange(bool running) {
    debugPrint('Syphon server status: ${running ? 'started' : 'stopped'}');
  }

  @override
  void initState() {
    super.initState();
    syphonServerController.addStatusListener(onSyphonServerStatusChange);
  }

  @override
  void dispose() {
    // stop 內會先同步關掉離屏 view；原生 stop 不阻塞 dispose。
    syphonServerController.stop();
    syphonServerController.removeStatusListener(onSyphonServerStatusChange);
    syphonServerController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await syphonServerController.start(name: 'Syphon Server Example');
    } catch (error) {
      debugPrint('Start Syphon Server failed: $error');
    }
  }

  Future<void> _stop() async {
    try {
      await syphonServerController.stop();
    } catch (error) {
      debugPrint('Stop Syphon Server failed: $error');
    }
  }

  Future<void> _changeOutputText() async {
    changeOutputText('Change output text');
    if (!syphonServerController.showSyphonView.value) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    try {
      await syphonServerController.publishWidget();
    } catch (error) {
      debugPrint('Publish after text change failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syphon Server Example'),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: _start,
                child: const Text('Start Syphon Server'),
              ),
            ),
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: _stop,
                child: const Text('Stop Syphon Server'),
              ),
            ),
            Container(
              height: 70,
              alignment: Alignment.center,
              child: TextButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: _changeOutputText,
                child: const Text('change output text'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## [lib/output_view.dart](lib/output_view.dart)

```dart
import 'package:flutter/material.dart';

typedef OutputTextSetter = void Function(String text);

/// 僅在 [OutputView] 掛載期間有效；dispose 後會還原成 no-op。
OutputTextSetter changeOutputText = _noopChangeOutputText;

void _noopChangeOutputText(String text) {}

class OutputView extends StatefulWidget {
  const OutputView({super.key, this.routeName});
  final String? routeName;

  @override
  State<OutputView> createState() => _OutputViewState();
}

class _OutputViewState extends State<OutputView> {
  String outputText = 'This is Syphon Output View';

  void _updateOutputText(String text) {
    setState(() {
      outputText = text;
    });
  }

  @override
  void initState() {
    super.initState();
    changeOutputText = _updateOutputText;
  }

  @override
  void dispose() {
    if (identical(changeOutputText, _updateOutputText)) {
      changeOutputText = _noopChangeOutputText;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1920,
      height: 1080,
      color: Colors.transparent,
      child: Text(
        outputText,
        style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
      ),
    );
  }
}
```
