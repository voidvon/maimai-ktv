cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "ktv2")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "ktv2_plugin")

list(APPEND PLUGIN_SOURCES
  "ktv2_plugin.cpp"
  "ktv2_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/ktv2/ktv2_plugin_c_api.h"
  "ktv2_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(vlc_runtime_dir "${CMAKE_CURRENT_SOURCE_DIR}/third_party/vlc/vlc-3.0.23")
set(vlc_required_runtime_paths
  "libvlc.dll"
  "libvlccore.dll"
  "plugins/access"
  "plugins/audio_output"
  "plugins/codec"
  "plugins/control/libdummy_plugin.dll"
  "plugins/demux"
  "plugins/video_output"
)

foreach(vlc_required_path IN LISTS vlc_required_runtime_paths)
  if(NOT EXISTS "${vlc_runtime_dir}/${vlc_required_path}")
    message(FATAL_ERROR "Missing required VLC runtime path: ${vlc_required_path}")
  endif()
endforeach()

add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
  "${vlc_runtime_dir}"
  "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/vlc"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
  "${vlc_runtime_dir}"
  "${CMAKE_BINARY_DIR}/runner/$<CONFIG>/vlc"
)

set(ktv2_bundled_libraries
  ""
  PARENT_SCOPE
)
