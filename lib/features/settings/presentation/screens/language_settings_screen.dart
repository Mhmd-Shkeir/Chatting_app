import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(currentUserProfileProvider).value?.preferredLanguage ??
        AppLanguage.english;

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: RadioGroup<AppLanguage>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) {
            ref
                .read(profileControllerProvider.notifier)
                .updatePreferredLanguage(value);
          }
        },
        child: Column(
          children: [
            for (final language in AppLanguage.values)
              RadioListTile<AppLanguage>(
                title: Text(language.label),
                value: language,
              ),
          ],
        ),
      ),
    );
  }
}
