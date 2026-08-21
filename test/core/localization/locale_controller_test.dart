import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maimai_ktv/core/localization/locale_controller.dart';
import 'package:maimai_ktv/core/localization/locale_preference_store.dart';

void main() {
  test('follows the system when no language preference exists', () async {
    final _MemoryLocalePreferenceStore store = _MemoryLocalePreferenceStore();
    final LocaleController controller = LocaleController(
      preferenceStore: store,
    );

    await controller.initialize();

    expect(controller.locale, isNull);
    expect(controller.followsSystem, isTrue);
  });

  test('restores a saved language preference', () async {
    final _MemoryLocalePreferenceStore store = _MemoryLocalePreferenceStore(
      languageTag: 'zh-Hant',
    );
    final LocaleController controller = LocaleController(
      preferenceStore: store,
    );

    await controller.initialize();

    expect(controller.locale, LocaleController.traditionalChinese);
  });

  test('recognizes traditional Chinese region tags', () async {
    final _MemoryLocalePreferenceStore store = _MemoryLocalePreferenceStore(
      languageTag: 'zh-TW',
    );
    final LocaleController controller = LocaleController(
      preferenceStore: store,
    );

    await controller.initialize();

    expect(controller.locale, LocaleController.traditionalChinese);
  });

  test('ignores unsupported stored language tags', () async {
    final _MemoryLocalePreferenceStore store = _MemoryLocalePreferenceStore(
      languageTag: 'fr-FR',
    );
    final LocaleController controller = LocaleController(
      preferenceStore: store,
    );

    await controller.initialize();

    expect(controller.locale, isNull);
    expect(store.languageTag, isNull);
  });

  test('persists manual selection and clears it for system mode', () async {
    final _MemoryLocalePreferenceStore store = _MemoryLocalePreferenceStore();
    final LocaleController controller = LocaleController(
      preferenceStore: store,
    );

    await controller.setLocale(LocaleController.english);

    expect(controller.locale, const Locale('en'));
    expect(store.languageTag, 'en');

    await controller.setLocale(null);

    expect(controller.locale, isNull);
    expect(store.languageTag, isNull);
  });
}

class _MemoryLocalePreferenceStore implements LocalePreferenceStore {
  _MemoryLocalePreferenceStore({this.languageTag});

  String? languageTag;

  @override
  Future<String?> readLanguageTag() async => languageTag;

  @override
  Future<void> writeLanguageTag(String? languageTag) async {
    this.languageTag = languageTag;
  }
}
