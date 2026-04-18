import '../platform/app_platform.dart';
import 'android_native_player_controller.dart';
import 'macos_native_player_controller_stub.dart'
    if (dart.library.io) 'macos_native_player_controller.dart';
import 'player_controller.dart';
import 'unsupported_player_controller.dart';
import 'windows_media_kit_player_controller_stub.dart'
    if (dart.library.io) 'windows_media_kit_player_controller.dart';

PlayerController createPlayerController() {
  if (isAndroid) {
    return AndroidNativePlayerController();
  }
  if (isMacOS) {
    return MacOSNativePlayerController();
  }
  if (isWindows) {
    return WindowsMediaKitPlayerController();
  }
  return UnsupportedPlayerController();
}
