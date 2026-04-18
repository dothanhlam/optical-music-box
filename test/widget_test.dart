import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optical_music_box/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OpticalMusicBoxApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
