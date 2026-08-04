import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/data/models/app_user.dart';
import '../../data/repositories/user_search_repository.dart';

final userSearchRepositoryProvider = Provider<UserSearchRepository>((ref) {
  return UserSearchRepository();
});

final userSearchResultsProvider = FutureProvider.family<List<AppUser>, String>((ref, query) {
  if (query.trim().isEmpty) return Future.value(const <AppUser>[]);
  return ref.watch(userSearchRepositoryProvider).search(query);
});
