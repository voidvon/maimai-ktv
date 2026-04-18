package com.ktv.player.ktv2

import io.flutter.embedding.engine.plugins.FlutterPlugin

class Ktv2Plugin : FlutterPlugin {
    private var nativePlayerHost: NativeKtvPlayerHost? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        nativePlayerHost =
            NativeKtvPlayerHost(
                binding.applicationContext,
                binding.binaryMessenger,
                binding.platformViewRegistry,
            )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        nativePlayerHost?.dispose()
        nativePlayerHost = null
    }
}
