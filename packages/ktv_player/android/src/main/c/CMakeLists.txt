cmake_minimum_required(VERSION 3.22.1)

project(ktv_vlc_bridge C)

add_library(ktv_vlc_bridge SHARED native_vlc_bridge.c)

find_library(log-lib log)
find_library(dl-lib dl)

target_link_libraries(
    ktv_vlc_bridge
    ${log-lib}
    ${dl-lib}
)
