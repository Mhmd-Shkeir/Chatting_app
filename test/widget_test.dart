// Basic smoke test: the app shell builds and shows its root screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatting_app_flu/app/app.dart';

void main() {
  testWidgets('App shell builds and shows Lumina Chat', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LuminaChatApp()),
    );

    expect(find.text('Lumina Chat'), findsOneWidget);
  });
}
