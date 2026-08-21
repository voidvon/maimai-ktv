# Windows VLC runtime

`vlc-3.0.23/` is a trimmed VLC runtime used by the embedded Windows player.
The application loads `libvlc.dll` directly and does not use the standalone VLC
application, graphical interfaces, browser controls, localization, streaming
output, service discovery, visualizations, skins, or Lua web interfaces.

The runtime intentionally keeps local media access, codecs, demuxers,
packetizers, audio/video output, subtitles, and audio/video filters. Keep
`COPYING.txt` with distributed builds. When changing this set, verify at least:

- MKV and MP4 playback
- H.264 and H.265 video
- AAC audio
- multiple audio tracks
- left/right channel switching
