import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/data/models/app_user.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).watchUser(uid);
});

class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateDisplayName(String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).updateDisplayName(displayName);
    });
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, void>(
  ProfileController.new,
);
