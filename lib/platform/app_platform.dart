import 'package:flutter/foundation.dart';

bool get isWeb => kIsWeb;

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
