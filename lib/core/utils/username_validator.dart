final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

String? validateUsername(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Choose a username';
  if (!usernamePattern.hasMatch(trimmed)) {
    return '3-20 letters, numbers, or underscores';
  }
  return null;
}
