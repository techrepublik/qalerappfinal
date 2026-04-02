import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Q-ALERT')),
      ),
    );
    expect(find.text('Q-ALERT'), findsOneWidget);
  });
}
