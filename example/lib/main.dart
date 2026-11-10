import 'package:flutter/material.dart';
import 'package:syphon_server/syphon_server.dart';
import 'output_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final SyphonServerController syphonServerController = SyphonServerController();


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
      body: SyphonServer(
        syphonView: const OutputView(),
        controller: syphonServerController,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: 70,
                alignment: Alignment.center,
                child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
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
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
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
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: _changeOutputText,
                  child: const Text('change output text'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}