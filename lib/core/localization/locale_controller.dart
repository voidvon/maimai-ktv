import 'package:flutter/widgets.dart';

import 'locale_preference_store.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({required LocalePreferenceStore preferenceStore})
    : _preferenceStore = preferenceStore;

  static const Locale simplifiedChinese = Locale('zh');
  static const Locale traditionalChinese = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
  );
  static const Locale english = Locale('en');
  static const List<Locale> supportedLocales = <Locale>[
    simplifiedChinese,
    traditionalChinese,
    english,
  ];

  final LocalePreferenceStore _preferenceStore;
  Locale? _locale;

  Locale? get locale => _locale;
  bool get followsSystem => _locale == null;

  Future<void> initialize() async {
    final String? languageTag = await _preferenceStore.readLanguageTag();
    _locale = _localeFromLanguageTag(languageTag);
    if (languageTag != null && _locale == null) {
      await _preferenceStore.writeLanguageTag(null);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    final Locale? normalized = locale == null ? null : _normalize(locale);
    if (_locale == normalized) {
      return;
    }
    _locale = normalized;
    notifyListeners();
    await _preferenceStore.writeLanguageTag(normalized?.toLanguageTag());
  }

  static Locale? _localeFromLanguageTag(String? languageTag) {
    if (languageTag == null || languageTag.isEmpty) {
      return null;
    }
    final List<String> parts = languageTag.split(RegExp('[-_]'));
    final String languageCode = parts.first.toLowerCase();
    final String? scriptCode = parts
        .where((String part) => part.length == 4)
        .firstOrNull;
    final String? countryCode = parts
        .where((String part) => part.length == 2 && part != parts.first)
        .firstOrNull;
    if (languageCode != 'zh' && languageCode != 'en') {
      return null;
    }
    return _normalize(
      Locale.fromSubtags(
        languageCode: languageCode,
        scriptCode: scriptCode,
        countryCode: countryCode,
      ),
    );
  }

  static Locale _normalize(Locale locale) {
    if (locale.languageCode == 'en') {
      return english;
    }
    if (locale.languageCode == 'zh' &&
        (locale.scriptCode == 'Hant' ||
            const <String>{'HK', 'MO', 'TW'}.contains(locale.countryCode))) {
      return traditionalChinese;
    }
    return simplifiedChinese;
  }
}
