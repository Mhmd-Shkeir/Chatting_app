import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/splash_screen.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/register_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/conversations/presentation/screens/home_screen.dart';
import '../features/profile/presentation/providers/profile_providers.dart';
import '../features/profile/presentation/screens/choose_username_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/search/presentation/screens/user_search_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authStateChangesProvider, (previous, next) {
    refreshNotifier.notify();
  });
  ref.listen(currentUserProfileProvider, (previous, next) {
    refreshNotifier.notify();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      final path = state.matchedLocation;

      if (authState.isLoading) {
        return path == '/splash' ? null : '/splash';
      }

      final isLoggedIn = authState.value != null;
      final isAuthRoute = path == '/login' || path == '/register';

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // Accounts created before the username system existed have no
      // username yet — hold them on a one-time onboarding screen until
      // they claim one, same idea as the splash gate above but keyed off
      // the Firestore profile doc instead of the auth state.
      final profileState = ref.read(currentUserProfileProvider);
      if (!profileState.hasValue) {
        return path == '/splash' ? null : '/splash';
      }

      final hasUsername = profileState.value?.hasUsername ?? false;
      final isOnboardingRoute = path == '/choose-username';

      if (!hasUsername) {
        return isOnboardingRoute ? null : '/choose-username';
      }

      return (isAuthRoute || path == '/splash' || isOnboardingRoute) ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/choose-username', builder: (context, state) => const ChooseUsernameScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/search', builder: (context, state) => const UserSearchScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
