#ifndef FLUTTER_PLUGIN_KTV2_PLUGIN_H_
#define FLUTTER_PLUGIN_KTV2_PLUGIN_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

namespace ktv2 {

class Ktv2Plugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit Ktv2Plugin(flutter::PluginRegistrarWindows* registrar);
  ~Ktv2Plugin() override;

  Ktv2Plugin(const Ktv2Plugin&) = delete;
  Ktv2Plugin& operator=(const Ktv2Plugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  struct AudioTrackInfo {
    int id = -1;
    std::string name;
  };

  struct LibVlcFunctions;

  std::optional<std::string> GetStringArgument(
      const flutter::EncodableMap& arguments,
      const char* key) const;
  std::optional<double> GetDoubleArgument(
      const flutter::EncodableMap& arguments,
      const char* key) const;

  bool EnsureLibVlcLoaded();
  void DisposePlayerLocked();
  bool OpenMediaLocked(const std::string& path,
                       const std::string& mode,
                       int pitch_shift_semitones);
  bool PlayLocked();
  bool PauseLocked();
  bool SeekToProgressLocked(double progress);
  bool SetAudioOutputModeLocked(const std::string& mode);
  bool SetPitchShiftLocked(int semitones);
  bool AttachVideoViewLocked(int left, int top, int width, int height);
  bool DetachVideoViewLocked();
  bool ClearMediaLocked();
  bool EnsureVideoWindowLocked();
  void UpdateVideoWindowBoundsLocked();
  void DestroyVideoWindowLocked();

  void StartPollingLocked();
  void StopPolling();
  void PollLoop();
  void RefreshTrackMetadataLocked();
  bool ApplyAudioOutputModeLocked();
  std::vector<AudioTrackInfo> QueryAudioTracksLocked() const;
  flutter::EncodableMap CurrentSnapshotLocked() const;
  void SendSnapshotLocked();
  void SetPlaybackErrorLocked(const std::string& message);
  void CaptureLibVlcErrorLocked(const std::string& fallback_message);
  void LogLineLocked(const std::string& message) const;

  static std::string WideToUtf8(const std::wstring& value);

  flutter::PluginRegistrarWindows* registrar_;
  HWND window_handle_ = nullptr;
  HWND video_window_handle_ = nullptr;
  RECT video_window_bounds_{};
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  std::mutex mutex_;
  std::unique_ptr<LibVlcFunctions> vlc_;
  std::string requested_audio_output_mode_ = "original";
  int pitch_shift_semitones_ = 0;
  std::string current_media_path_;
  std::string playback_error_;
  std::string selected_audio_track_title_;
  int selected_audio_channel_count_ = 0;
  int audio_track_count_ = 0;
  int video_track_count_ = 0;
  bool is_playback_completed_ = false;

  std::atomic<bool> stop_polling_{false};
  std::thread polling_thread_;
};

}  // namespace ktv2

#endif  // FLUTTER_PLUGIN_KTV2_PLUGIN_H_
