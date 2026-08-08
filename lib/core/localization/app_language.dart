/// A language Lumina Chat can translate messages into. Also the substrate
/// for future app-wide UI localization — adding a language later is just
/// adding a value here.
enum AppLanguage {
  english('en', 'English'),
  arabic('ar', 'العربية'),
  french('fr', 'Français');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}
