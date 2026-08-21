#include "include/ktv2/ktv2_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ktv2_plugin.h"

void Ktv2PluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ktv2::Ktv2Plugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
