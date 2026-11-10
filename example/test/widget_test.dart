import 'package:flutter_test/flutter_test.dart';
import 'package:syphon_server_example/main.dart';

void main() {
  testWidgets('Example app shows Syphon controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Syphon Server Example'), findsOneWidget);
    expect(find.text('Start Syphon Server'), findsOneWidget);
    expect(find.text('Stop Syphon Server'), findsOneWidget);
    expect(find.text('change output text'), findsOneWidget);
  });
}
