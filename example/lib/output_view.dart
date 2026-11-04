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
