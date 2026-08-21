import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalePreferenceStore {
  Future<String?> readLanguageTag();

  Future<void> writeLanguageTag(String? languageTag);
}

class SharedPreferencesLocalePreferenceStore implements LocalePreferenceStore {
  SharedPreferencesLocalePreferenceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _languageTagKey = 'preferred_language_tag';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readLanguageTag() {
    return _preferences.getString(_languageTagKey);
  }

  @override
  Future<void> writeLanguageTag(String? languageTag) async {
    if (languageTag == null) {
      await _preferences.remove(_languageTagKey);
      return;
    }
    await _preferences.setString(_languageTagKey, languageTag);
  }
}
