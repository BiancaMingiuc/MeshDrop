// test/widget_test.dart
// Smoke test: verifies the MeshDrop HomeScreen renders without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshdrop/ui/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('MeshDrop'), findsOneWidget);
  });
}
