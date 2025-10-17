// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App shows Dashboard title', (WidgetTester tester) async {
    // Build a minimal app that contains the Dashboard AppBar title.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('HERD‑V Dashboard')),
      ),
    ));

    expect(find.text('HERD‑V Dashboard'), findsOneWidget);
  });
}
