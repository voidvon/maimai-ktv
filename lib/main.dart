import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/localization/locale_controller.dart';
import 'core/localization/locale_preference_store.dart';
export 'app/app.dart' show KtvApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final LocaleController localeController = LocaleController(
    preferenceStore: SharedPreferencesLocalePreferenceStore(),
  );
  await localeController.initialize();
  runApp(KtvApp(localeController: localeController));
}
