import 'package:flutter/widgets.dart';

import 'app/app.dart';
export 'app/app.dart' show KtvDemoApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KtvDemoApp());
}
