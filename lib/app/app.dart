import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_providers.dart';
import '../core/utils/root_scaffold_messenger_key.dart';
import '../features/authentication/presentation/providers/presence_providers.dart';
import '../features/chat/presentation/providers/e2ee_providers.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';
import 'router.dart';

class LuminaChatApp extends ConsumerWidget {
  const LuminaChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(presenceTrackerProvider);
    ref.watch(notificationTrackerProvider);
    ref.watch(e2eeKeyTrackerProvider);

    return MaterialApp.router(
      title: 'Lumina Chat',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
