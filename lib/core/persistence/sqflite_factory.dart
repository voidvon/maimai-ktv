import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _didConfigureSqfliteFactory = false;

void configureSqfliteFactoryForPlatform() {
  if (_didConfigureSqfliteFactory ||
      kIsWeb ||
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isFuchsia) {
    return;
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _didConfigureSqfliteFactory = true;
}
