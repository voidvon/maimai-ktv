import '../platform/app_platform.dart';
import 'android_native_player_controller.dart';
import 'ios_native_player_controller_stub.dart'
    if (dart.library.io) 'ios_native_player_controller.dart';
import 'macos_native_player_controller_stub.dart'
    if (dart.library.io) 'macos_native_player_controller.dart';
import 'player_controller.dart';
import 'unsupported_player_controller.dart';
import 'windows_vlc_player_controller_stub.dart'
    if (dart.library.io) 'windows_vlc_player_controller.dart';

PlayerController createPlayerController() {
  if (isAndroid) {
    return AndroidNativePlayerController();
  }
  if (isIOS) {
    return IosNativePlayerController();
  }
  if (isMacOS) {
    return MacOSNativePlayerController();
  }
  if (isWindows) {
    return WindowsVlcPlayerController();
  }
  return UnsupportedPlayerController();
}
