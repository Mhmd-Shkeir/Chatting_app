// Basic smoke test: with no signed-in user, the app routes to the login screen.
// The auth stream is overridden so this never touches real Firebase.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatting_app_flu/app/app.dart';
import 'package:chatting_app_flu/features/authentication/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('Shows the login screen when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const LuminaChatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
  });
}
