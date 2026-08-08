import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in bootstrap() with the resolved instance before runApp —
/// SharedPreferences.getInstance() is async, so it can't be created lazily
/// inside a provider the way most repositories are.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap()',
  );
});
