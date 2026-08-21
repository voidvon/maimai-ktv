import 'package:flutter/services.dart';

class NativePlayerChannels {
  const NativePlayerChannels({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? _defaultMethodChannel,
       _eventChannel = eventChannel ?? _defaultEventChannel;

  static const MethodChannel _defaultMethodChannel = MethodChannel(
    'ktv/native_player',
  );
  static const EventChannel _defaultEventChannel = EventChannel(
    'ktv/native_player_events',
  );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<dynamic> receiveEvents() {
    return _eventChannel.receiveBroadcastStream();
  }

  Future<Map<Object?, Object?>?> invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final result = await _methodChannel.invokeMethod<dynamic>(
      method,
      arguments,
    );
    if (result is Map) {
      return Map<Object?, Object?>.from(result);
    }
    return null;
  }

  Future<void> disposePlayer() {
    return _methodChannel.invokeMethod<void>('dispose');
  }
}
