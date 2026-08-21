#include "ktv2_plugin.h"

#include <windows.h>

#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>

#include <flutter/event_stream_handler_functions.h>

namespace ktv2 {

namespace {

constexpr int kAudioChannelStereo = 1;
constexpr int kAudioChannelLeft = 3;
constexpr int kAudioChannelRight = 4;
constexpr wchar_t kVideoHostWindowClassName[] = L"Ktv2VlcVideoHostWindow";

LRESULT CALLBACK VideoHostWindowProc(HWND hwnd,
                                     UINT message,
                                     WPARAM wparam,
                                     LPARAM lparam) {
  return DefWindowProc(hwnd, message, wparam, lparam);
}

struct libvlc_instance_t;
struct libvlc_media_player_t;
struct libvlc_media_t;
struct libvlc_track_description_t {
  int i_id;
  char* psz_name;
  libvlc_track_description_t* p_next;
};

}  // namespace

struct Ktv2Plugin::LibVlcFunctions {
  HMODULE module = nullptr;
  libvlc_instance_t* instance = nullptr;
  libvlc_media_player_t* player = nullptr;

  libvlc_instance_t* (*libvlc_new)(int, const char* const*) = nullptr;
  void (*libvlc_release)(libvlc_instance_t*) = nullptr;
  libvlc_media_t* (*libvlc_media_new_path)(libvlc_instance_t*, const char*) =
      nullptr;
  void (*libvlc_media_release)(libvlc_media_t*) = nullptr;
  libvlc_media_player_t* (*libvlc_media_player_new_from_media)(
      libvlc_media_t*) = nullptr;
  void (*libvlc_media_player_release)(libvlc_media_player_t*) = nullptr;
  int (*libvlc_media_player_play)(libvlc_media_player_t*) = nullptr;
  void (*libvlc_media_player_pause)(libvlc_media_player_t*) = nullptr;
  void (*libvlc_media_player_stop)(libvlc_media_player_t*) = nullptr;
  int (*libvlc_media_player_is_playing)(libvlc_media_player_t*) = nullptr;
  int64_t (*libvlc_media_player_get_length)(libvlc_media_player_t*) = nullptr;
  int64_t (*libvlc_media_player_get_time)(libvlc_media_player_t*) = nullptr;
  void (*libvlc_media_player_set_time)(libvlc_media_player_t*, int64_t) =
      nullptr;
  unsigned (*libvlc_media_player_has_vout)(libvlc_media_player_t*) = nullptr;
  void (*libvlc_media_player_set_hwnd)(libvlc_media_player_t*, void*) = nullptr;
  int (*libvlc_audio_get_track_count)(libvlc_media_player_t*) = nullptr;
  libvlc_track_description_t* (*libvlc_audio_get_track_description)(
      libvlc_media_player_t*) = nullptr;
  void (*libvlc_track_description_list_release)(
      libvlc_track_description_t*) = nullptr;
  int (*libvlc_audio_set_track)(libvlc_media_player_t*, int) = nullptr;
  int (*libvlc_audio_set_channel)(libvlc_media_player_t*, int) = nullptr;
  int (*libvlc_video_get_track_count)(libvlc_media_player_t*) = nullptr;
  const char* (*libvlc_errmsg)() = nullptr;
};

void Ktv2Plugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<Ktv2Plugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

Ktv2Plugin::Ktv2Plugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  if (auto* view = registrar_->GetView()) {
    window_handle_ = view->GetNativeWindow();
  }

  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar_->messenger(), "ktv/native_player",
          &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar_->messenger(), "ktv/native_player_events",
          &flutter::StandardMethodCodec::GetInstance());
  event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     events) {
            std::lock_guard<std::mutex> lock(mutex_);
            event_sink_ = std::move(events);
            SendSnapshotLocked();
            StartPollingLocked();
            return nullptr;
          },
          [this](const flutter::EncodableValue* arguments) {
            std::lock_guard<std::mutex> lock(mutex_);
            event_sink_.reset();
            return nullptr;
          }));
}

Ktv2Plugin::~Ktv2Plugin() {
  StopPolling();
  std::lock_guard<std::mutex> lock(mutex_);
  DisposePlayerLocked();
  DestroyVideoWindowLocked();
}

void Ktv2Plugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  const std::string& method = method_call.method_name();

  bool ok = false;
  if (method == "open") {
    if (arguments == nullptr) {
      result->Error("invalid_args", "open requires arguments");
      return;
    }
    const auto path = GetStringArgument(*arguments, "path");
    const std::string mode =
        GetStringArgument(*arguments, "audioOutputMode").value_or("original");
    if (!path.has_value()) {
      result->Error("invalid_args", "open requires path");
      return;
    }
    ok = OpenMediaLocked(*path, mode);
  } else if (method == "play") {
    ok = PlayLocked();
  } else if (method == "pause") {
    ok = PauseLocked();
  } else if (method == "seekToProgress") {
    if (arguments == nullptr) {
      result->Error("invalid_args", "seekToProgress requires arguments");
      return;
    }
    const auto progress = GetDoubleArgument(*arguments, "progress");
    if (!progress.has_value()) {
      result->Error("invalid_args", "seekToProgress requires progress");
      return;
    }
    ok = SeekToProgressLocked(*progress);
  } else if (method == "setAudioOutputMode") {
    if (arguments == nullptr) {
      result->Error("invalid_args", "setAudioOutputMode requires arguments");
      return;
    }
    ok = SetAudioOutputModeLocked(
        GetStringArgument(*arguments, "mode").value_or("original"));
  } else if (method == "attachVideoView") {
    if (arguments == nullptr) {
      result->Error("invalid_args", "attachVideoView requires arguments");
      return;
    }
    const auto left = GetDoubleArgument(*arguments, "left");
    const auto top = GetDoubleArgument(*arguments, "top");
    const auto width = GetDoubleArgument(*arguments, "width");
    const auto height = GetDoubleArgument(*arguments, "height");
    if (!left.has_value() || !top.has_value() || !width.has_value() ||
        !height.has_value()) {
      result->Error("invalid_args", "attachVideoView requires bounds");
      return;
    }
    ok = AttachVideoViewLocked(static_cast<int>(*left),
                               static_cast<int>(*top),
                               static_cast<int>(*width),
                               static_cast<int>(*height));
  } else if (method == "detachVideoView") {
    ok = DetachVideoViewLocked();
  } else if (method == "clearMedia") {
    ok = ClearMediaLocked();
  } else if (method == "dispose") {
    DisposePlayerLocked();
    ok = true;
  } else {
    result->NotImplemented();
    return;
  }

  if (!ok && playback_error_.empty()) {
    playback_error_ = "Windows 原生 VLC 操作失败。";
  }
  result->Success(flutter::EncodableValue(CurrentSnapshotLocked()));
  SendSnapshotLocked();
}

std::optional<std::string> Ktv2Plugin::GetStringArgument(
    const flutter::EncodableMap& arguments,
    const char* key) const {
  const auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return std::nullopt;
  }
  const auto* value = std::get_if<std::string>(&it->second);
  return value == nullptr ? std::nullopt : std::optional<std::string>(*value);
}

std::optional<double> Ktv2Plugin::GetDoubleArgument(
    const flutter::EncodableMap& arguments,
    const char* key) const {
  const auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  return std::nullopt;
}

bool Ktv2Plugin::EnsureLibVlcLoaded() {
  if (vlc_ != nullptr && vlc_->instance != nullptr) {
    return true;
  }

  auto vlc = std::make_unique<LibVlcFunctions>();
  wchar_t module_path[MAX_PATH];
  const DWORD path_length = GetModuleFileNameW(nullptr, module_path, MAX_PATH);
  if (path_length == 0 || path_length >= MAX_PATH) {
    SetPlaybackErrorLocked("无法解析 Windows 可执行文件路径。");
    return false;
  }

  std::filesystem::path root(module_path);
  root = root.parent_path();
  const std::filesystem::path runtime_dir = root / "vlc";
  const std::filesystem::path dll_path = runtime_dir / "libvlc.dll";
  const std::filesystem::path plugins_dir = runtime_dir / "plugins";

  SetDllDirectoryW(runtime_dir.wstring().c_str());
  SetEnvironmentVariableW(L"VLC_PLUGIN_PATH", plugins_dir.wstring().c_str());
  LogLineLocked("exe_dir=" + WideToUtf8(root.wstring()));
  LogLineLocked("vlc_runtime_dir=" + WideToUtf8(runtime_dir.wstring()));

  vlc->module = LoadLibraryW(dll_path.wstring().c_str());
  if (vlc->module == nullptr) {
    SetPlaybackErrorLocked("未找到打包后的 libvlc.dll。");
    LogLineLocked("LoadLibraryW(libvlc.dll) failed");
    return false;
  }

  auto load_symbol = [&](auto& target, const char* name) -> bool {
    target = reinterpret_cast<std::decay_t<decltype(target)>>(
        GetProcAddress(vlc->module, name));
    if (target == nullptr) {
      SetPlaybackErrorLocked(std::string("libVLC 缺少导出符号：") + name);
      return false;
    }
    return true;
  };

  if (!load_symbol(vlc->libvlc_new, "libvlc_new") ||
      !load_symbol(vlc->libvlc_release, "libvlc_release") ||
      !load_symbol(vlc->libvlc_media_new_path, "libvlc_media_new_path") ||
      !load_symbol(vlc->libvlc_media_release, "libvlc_media_release") ||
      !load_symbol(vlc->libvlc_media_player_new_from_media,
                   "libvlc_media_player_new_from_media") ||
      !load_symbol(vlc->libvlc_media_player_release,
                   "libvlc_media_player_release") ||
      !load_symbol(vlc->libvlc_media_player_play, "libvlc_media_player_play") ||
      !load_symbol(vlc->libvlc_media_player_pause,
                   "libvlc_media_player_pause") ||
      !load_symbol(vlc->libvlc_media_player_stop, "libvlc_media_player_stop") ||
      !load_symbol(vlc->libvlc_media_player_is_playing,
                   "libvlc_media_player_is_playing") ||
      !load_symbol(vlc->libvlc_media_player_get_length,
                   "libvlc_media_player_get_length") ||
      !load_symbol(vlc->libvlc_media_player_get_time,
                   "libvlc_media_player_get_time") ||
      !load_symbol(vlc->libvlc_media_player_set_time,
                   "libvlc_media_player_set_time") ||
      !load_symbol(vlc->libvlc_media_player_has_vout,
                   "libvlc_media_player_has_vout") ||
      !load_symbol(vlc->libvlc_media_player_set_hwnd,
                   "libvlc_media_player_set_hwnd") ||
      !load_symbol(vlc->libvlc_audio_get_track_count,
                   "libvlc_audio_get_track_count") ||
      !load_symbol(vlc->libvlc_audio_get_track_description,
                   "libvlc_audio_get_track_description") ||
      !load_symbol(vlc->libvlc_track_description_list_release,
                   "libvlc_track_description_list_release") ||
      !load_symbol(vlc->libvlc_audio_set_track, "libvlc_audio_set_track") ||
      !load_symbol(vlc->libvlc_audio_set_channel,
                   "libvlc_audio_set_channel") ||
      !load_symbol(vlc->libvlc_video_get_track_count,
                   "libvlc_video_get_track_count") ||
      !load_symbol(vlc->libvlc_errmsg, "libvlc_errmsg")) {
    if (vlc->module != nullptr) {
      FreeLibrary(vlc->module);
    }
    return false;
  }

  const std::string plugin_path_arg =
      "--plugin-path=" + WideToUtf8(plugins_dir.wstring());
  const char* argv[] = {"--quiet", "--intf=dummy", "--no-video-title-show",
                        plugin_path_arg.c_str()};
  vlc->instance = vlc->libvlc_new(4, argv);
  if (vlc->instance == nullptr) {
    CaptureLibVlcErrorLocked("libVLC 初始化失败。");
    LogLineLocked("libvlc_new failed: " + playback_error_);
    FreeLibrary(vlc->module);
    return false;
  }

  LogLineLocked("libvlc_new ok");
  vlc_ = std::move(vlc);
  playback_error_.clear();
  return true;
}

bool Ktv2Plugin::OpenMediaLocked(const std::string& path,
                                 const std::string& mode) {
  requested_audio_output_mode_ =
      mode == "accompaniment" ? "accompaniment" : "original";
  playback_error_.clear();
  is_playback_completed_ = false;

  DisposePlayerLocked();
  if (!EnsureLibVlcLoaded()) {
    return false;
  }
  if (!EnsureVideoWindowLocked()) {
    return false;
  }

  LogLineLocked("open path=" + path);
  libvlc_media_t* media = vlc_->libvlc_media_new_path(vlc_->instance, path.c_str());
  if (media == nullptr) {
    CaptureLibVlcErrorLocked("libVLC 无法打开当前文件。");
    LogLineLocked("libvlc_media_new_path failed: " + playback_error_);
    return false;
  }

  vlc_->player = vlc_->libvlc_media_player_new_from_media(media);
  vlc_->libvlc_media_release(media);
  if (vlc_->player == nullptr) {
    CaptureLibVlcErrorLocked("libVLC 无法创建播放器实例。");
    return false;
  }

  vlc_->libvlc_media_player_set_hwnd(vlc_->player, video_window_handle_);

  current_media_path_ = path;
  const bool play_ok = vlc_->libvlc_media_player_play(vlc_->player) == 0;
  if (!play_ok) {
    CaptureLibVlcErrorLocked("libVLC 无法开始播放当前文件。");
    LogLineLocked("libvlc_media_player_play failed: " + playback_error_);
  }
  LogLineLocked(std::string("libvlc_media_player_play result=") +
                (play_ok ? "ok" : "fail"));
  std::this_thread::sleep_for(std::chrono::milliseconds(350));
  RefreshTrackMetadataLocked();
  ApplyAudioOutputModeLocked();
  return play_ok;
}

bool Ktv2Plugin::PlayLocked() {
  playback_error_.clear();
  if (vlc_ == nullptr || vlc_->player == nullptr) {
    return false;
  }
  const bool ok = vlc_->libvlc_media_player_play(vlc_->player) == 0;
  if (!ok) {
    CaptureLibVlcErrorLocked("libVLC 无法恢复播放。");
  }
  return ok;
}

bool Ktv2Plugin::PauseLocked() {
  playback_error_.clear();
  if (vlc_ == nullptr || vlc_->player == nullptr) {
    return false;
  }
  vlc_->libvlc_media_player_pause(vlc_->player);
  return true;
}

bool Ktv2Plugin::SeekToProgressLocked(double progress) {
  playback_error_.clear();
  if (vlc_ == nullptr || vlc_->player == nullptr) {
    return false;
  }
  const int64_t length = vlc_->libvlc_media_player_get_length(vlc_->player);
  if (length <= 0) {
    return false;
  }
  const double normalized =
      progress < 0.0 ? 0.0 : (progress > 1.0 ? 1.0 : progress);
  vlc_->libvlc_media_player_set_time(
      vlc_->player, static_cast<int64_t>(length * normalized));
  is_playback_completed_ = false;
  return true;
}

bool Ktv2Plugin::SetAudioOutputModeLocked(const std::string& mode) {
  requested_audio_output_mode_ =
      mode == "accompaniment" ? "accompaniment" : "original";
  playback_error_.clear();
  if (vlc_ == nullptr || vlc_->player == nullptr) {
    return false;
  }
  RefreshTrackMetadataLocked();
  return ApplyAudioOutputModeLocked();
}

bool Ktv2Plugin::ClearMediaLocked() {
  playback_error_.clear();
  DisposePlayerLocked();
  DetachVideoViewLocked();
  current_media_path_.clear();
  selected_audio_track_title_.clear();
  selected_audio_channel_count_ = 0;
  audio_track_count_ = 0;
  video_track_count_ = 0;
  is_playback_completed_ = false;
  return true;
}

void Ktv2Plugin::DisposePlayerLocked() {
  if (vlc_ == nullptr) {
    return;
  }
  if (vlc_->player != nullptr) {
    vlc_->libvlc_media_player_stop(vlc_->player);
    vlc_->libvlc_media_player_release(vlc_->player);
    vlc_->player = nullptr;
  }
  if (vlc_->instance != nullptr) {
    vlc_->libvlc_release(vlc_->instance);
    vlc_->instance = nullptr;
  }
  if (vlc_->module != nullptr) {
    FreeLibrary(vlc_->module);
    vlc_->module = nullptr;
  }
  vlc_.reset();
}

bool Ktv2Plugin::AttachVideoViewLocked(int left,
                                       int top,
                                       int width,
                                       int height) {
  playback_error_.clear();
  video_window_bounds_.left = left;
  video_window_bounds_.top = top;
  video_window_bounds_.right = left + (width > 0 ? width : 0);
  video_window_bounds_.bottom = top + (height > 0 ? height : 0);

  if (!EnsureVideoWindowLocked()) {
    return false;
  }

  UpdateVideoWindowBoundsLocked();
  if (vlc_ != nullptr && vlc_->player != nullptr && video_window_handle_ != nullptr) {
    vlc_->libvlc_media_player_set_hwnd(vlc_->player, video_window_handle_);
  }
  return true;
}

bool Ktv2Plugin::DetachVideoViewLocked() {
  if (video_window_handle_ == nullptr) {
    return true;
  }
  ShowWindow(video_window_handle_, SW_HIDE);
  return true;
}

bool Ktv2Plugin::EnsureVideoWindowLocked() {
  if (video_window_handle_ != nullptr) {
    return true;
  }
  if (window_handle_ == nullptr) {
    SetPlaybackErrorLocked("Windows 预览窗口尚未初始化。");
    return false;
  }

  WNDCLASSW window_class{};
  window_class.lpfnWndProc = VideoHostWindowProc;
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.lpszClassName = kVideoHostWindowClassName;
  RegisterClassW(&window_class);

  video_window_handle_ = CreateWindowExW(
      0, kVideoHostWindowClassName, L"", WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
      0, 0, 1, 1, window_handle_, nullptr, window_class.hInstance, nullptr);
  if (video_window_handle_ == nullptr) {
    SetPlaybackErrorLocked("Windows VLC 预览子窗口创建失败。");
    return false;
  }
  UpdateVideoWindowBoundsLocked();
  return true;
}

void Ktv2Plugin::UpdateVideoWindowBoundsLocked() {
  if (video_window_handle_ == nullptr) {
    return;
  }
  int width = static_cast<int>(video_window_bounds_.right - video_window_bounds_.left);
  int height =
      static_cast<int>(video_window_bounds_.bottom - video_window_bounds_.top);
  if (width < 0) {
    width = 0;
  }
  if (height < 0) {
    height = 0;
  }
  SetWindowPos(video_window_handle_, HWND_TOP, video_window_bounds_.left,
               video_window_bounds_.top, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void Ktv2Plugin::DestroyVideoWindowLocked() {
  if (video_window_handle_ == nullptr) {
    return;
  }
  DestroyWindow(video_window_handle_);
  video_window_handle_ = nullptr;
}

void Ktv2Plugin::StartPollingLocked() {
  if (polling_thread_.joinable()) {
    return;
  }
  stop_polling_ = false;
  polling_thread_ = std::thread([this]() { PollLoop(); });
}

void Ktv2Plugin::StopPolling() {
  stop_polling_ = true;
  if (polling_thread_.joinable()) {
    polling_thread_.join();
  }
}

void Ktv2Plugin::PollLoop() {
  while (!stop_polling_) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (vlc_ != nullptr && vlc_->player != nullptr) {
        RefreshTrackMetadataLocked();
        const int64_t length = vlc_->libvlc_media_player_get_length(vlc_->player);
        const int64_t time = vlc_->libvlc_media_player_get_time(vlc_->player);
        if (length > 0 && time >= length - 1500) {
          is_playback_completed_ = true;
        }
        SendSnapshotLocked();
      }
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(300));
  }
}

void Ktv2Plugin::RefreshTrackMetadataLocked() {
  if (vlc_ == nullptr || vlc_->player == nullptr) {
    audio_track_count_ = 0;
    video_track_count_ = 0;
    selected_audio_channel_count_ = 0;
    selected_audio_track_title_.clear();
    return;
  }
  const int raw_audio_track_count =
      vlc_->libvlc_audio_get_track_count(vlc_->player);
  const int raw_video_track_count =
      vlc_->libvlc_video_get_track_count(vlc_->player);
  audio_track_count_ = raw_audio_track_count > 0 ? raw_audio_track_count : 0;
  video_track_count_ = raw_video_track_count > 0 ? raw_video_track_count : 0;
  if (audio_track_count_ == 1) {
    selected_audio_track_title_ = "单音轨";
    selected_audio_channel_count_ = 2;
  } else if (audio_track_count_ > 1) {
    const auto tracks = QueryAudioTracksLocked();
    const size_t index = requested_audio_output_mode_ == "accompaniment" &&
                                 tracks.size() > 1
                             ? 1
                             : 0;
    selected_audio_track_title_ =
        tracks.empty() ? "音轨 1" : tracks[index].name;
    selected_audio_channel_count_ = 2;
  }
}

bool Ktv2Plugin::ApplyAudioOutputModeLocked() {
  if (vlc_ == nullptr || vlc_->player == nullptr || audio_track_count_ <= 0) {
    return false;
  }
  if (audio_track_count_ == 1) {
    const int channel = requested_audio_output_mode_ == "accompaniment"
                            ? kAudioChannelLeft
                            : kAudioChannelRight;
    if (vlc_->libvlc_audio_set_channel(vlc_->player, channel) != 0) {
      CaptureLibVlcErrorLocked("Windows libVLC 不支持当前文件的左右声道切换。");
      return false;
    }
    selected_audio_track_title_ =
        requested_audio_output_mode_ == "accompaniment" ? "左声道" : "右声道";
    selected_audio_channel_count_ = 2;
    return true;
  }

  const auto tracks = QueryAudioTracksLocked();
  if (tracks.empty()) {
    return false;
  }
  const size_t target_index =
      requested_audio_output_mode_ == "accompaniment" && tracks.size() > 1 ? 1 : 0;
  if (vlc_->libvlc_audio_set_track(vlc_->player, tracks[target_index].id) != 0) {
    CaptureLibVlcErrorLocked("Windows libVLC 音轨切换失败。");
    return false;
  }
  selected_audio_track_title_ = tracks[target_index].name;
  selected_audio_channel_count_ = 2;
  return true;
}

std::vector<Ktv2Plugin::AudioTrackInfo> Ktv2Plugin::QueryAudioTracksLocked() const {
  std::vector<AudioTrackInfo> tracks;
  if (vlc_ == nullptr || vlc_->player == nullptr) {
    return tracks;
  }
  libvlc_track_description_t* head =
      vlc_->libvlc_audio_get_track_description(vlc_->player);
  for (auto* item = head; item != nullptr; item = item->p_next) {
    if (item->i_id < 0) {
      continue;
    }
    tracks.push_back(AudioTrackInfo{
        item->i_id, item->psz_name == nullptr ? "音轨" : item->psz_name});
  }
  if (head != nullptr) {
    vlc_->libvlc_track_description_list_release(head);
  }
  return tracks;
}

flutter::EncodableMap Ktv2Plugin::CurrentSnapshotLocked() const {
  flutter::EncodableMap snapshot;
  const bool is_playing =
      vlc_ != nullptr && vlc_->player != nullptr &&
      vlc_->libvlc_media_player_is_playing(vlc_->player) != 0;
  const int64_t position_ms =
      vlc_ != nullptr && vlc_->player != nullptr
          ? vlc_->libvlc_media_player_get_time(vlc_->player)
          : 0;
  const int64_t duration_ms =
      vlc_ != nullptr && vlc_->player != nullptr
          ? vlc_->libvlc_media_player_get_length(vlc_->player)
          : 0;
  const bool has_video_output =
      vlc_ != nullptr && vlc_->player != nullptr &&
      vlc_->libvlc_media_player_has_vout(vlc_->player) > 0;

  snapshot[flutter::EncodableValue("isPlaying")] = flutter::EncodableValue(is_playing);
  snapshot[flutter::EncodableValue("isPlaybackCompleted")] =
      flutter::EncodableValue(is_playback_completed_);
  snapshot[flutter::EncodableValue("hasVideoOutput")] =
      flutter::EncodableValue(has_video_output);
  snapshot[flutter::EncodableValue("playbackPositionMs")] =
      flutter::EncodableValue(static_cast<int64_t>(position_ms > 0 ? position_ms : 0));
  snapshot[flutter::EncodableValue("playbackDurationMs")] =
      flutter::EncodableValue(static_cast<int64_t>(duration_ms > 0 ? duration_ms : 0));
  snapshot[flutter::EncodableValue("videoTrackCount")] =
      flutter::EncodableValue(video_track_count_);
  snapshot[flutter::EncodableValue("audioTrackCount")] =
      flutter::EncodableValue(audio_track_count_);
  snapshot[flutter::EncodableValue("selectedAudioTrackTitle")] =
      selected_audio_track_title_.empty() ? flutter::EncodableValue()
                                          : flutter::EncodableValue(selected_audio_track_title_);
  snapshot[flutter::EncodableValue("selectedAudioChannelCount")] =
      selected_audio_channel_count_ > 0
          ? flutter::EncodableValue(selected_audio_channel_count_)
          : flutter::EncodableValue();
  snapshot[flutter::EncodableValue("playbackError")] =
      playback_error_.empty() ? flutter::EncodableValue()
                              : flutter::EncodableValue(playback_error_);
  return snapshot;
}

void Ktv2Plugin::SendSnapshotLocked() {
  if (!event_sink_) {
    return;
  }
  event_sink_->Success(flutter::EncodableValue(CurrentSnapshotLocked()));
}

void Ktv2Plugin::SetPlaybackErrorLocked(const std::string& message) {
  playback_error_ = message;
}

void Ktv2Plugin::CaptureLibVlcErrorLocked(const std::string& fallback_message) {
  if (vlc_ != nullptr && vlc_->libvlc_errmsg != nullptr) {
    const char* error = vlc_->libvlc_errmsg();
    if (error != nullptr && error[0] != '\0') {
      playback_error_ = error;
      return;
    }
  }
  playback_error_ = fallback_message;
}

void Ktv2Plugin::LogLineLocked(const std::string& message) const {
  wchar_t temp_path[MAX_PATH];
  const DWORD path_length = GetTempPathW(MAX_PATH, temp_path);
  if (path_length == 0 || path_length >= MAX_PATH) {
    return;
  }
  const std::filesystem::path log_path =
      std::filesystem::path(temp_path) / "ktv2_windows_vlc.log";
  std::ofstream stream(log_path, std::ios::app);
  if (!stream.is_open()) {
    return;
  }
  stream << message << '\n';
}

std::string Ktv2Plugin::WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  std::string output(size_needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      output.data(), size_needed, nullptr, nullptr);
  return output;
}

}  // namespace ktv2
