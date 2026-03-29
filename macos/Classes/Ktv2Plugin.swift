import Cocoa
import FlutterMacOS
import VLCKit

public final class Ktv2Plugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = NativeKtvPlayerBridge(messenger: registrar.messenger)
    let factory = NativeVideoViewFactory(bridge: bridge)
    registrar.register(factory, withId: "ktv/native_video_view")
  }
}

private final class NativeVideoViewFactory: NSObject, FlutterPlatformViewFactory {
  private let bridge: NativeKtvPlayerBridge

  init(bridge: NativeKtvPlayerBridge) {
    self.bridge = bridge
    super.init()
  }

  func create(
    withViewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> NSView {
    let view = NativeVideoView()
    bridge.attachVideoView(view)
    return view
  }
}

private final class NativeVideoView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
  }
}

private final class NativeKtvPlayerBridge: NSObject, FlutterStreamHandler, VLCMediaPlayerDelegate {
  private let vlcAudioChannelStereo = 1
  private let vlcAudioChannelLeft = 3
  private let vlcAudioChannelRight = 4

  private var player: VLCMediaPlayer
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel

  private weak var videoView: NSView?
  private var eventSink: FlutterEventSink?
  private var requestedAudioOutputMode = "original"
  private var currentSourceMediaPath: String?
  private var currentPlaybackMediaPath: String?
  private var playbackCompleted = false
  private var playbackError: String?
  private var lastKnownPositionMs = 0
  private var lastKnownDurationMs = 0

  init(messenger: FlutterBinaryMessenger) {
    player = VLCMediaPlayer()
    methodChannel = FlutterMethodChannel(name: "ktv/native_player", binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "ktv/native_player_events", binaryMessenger: messenger)

    super.init()

    configurePlayer(player)
    eventChannel.setStreamHandler(self)
    methodChannel.setMethodCallHandler(handleMethodCall)
  }

  private func configurePlayer(_ player: VLCMediaPlayer) {
    player.delegate = self
    player.drawable = videoView
    player.audioChannel = Int32(vlcAudioChannelStereo)
  }

  private func buildPlayer() -> VLCMediaPlayer {
    let player = VLCMediaPlayer()
    configurePlayer(player)
    return player
  }

  private func audioChannel(for mode: String) -> Int32 {
    mode == "accompaniment" ? Int32(vlcAudioChannelLeft) : Int32(vlcAudioChannelRight)
  }

  private func resetSingleTrackRoutingToSourceIfNeeded() {
    guard let sourceMediaPath = currentSourceMediaPath else {
      return
    }
    if currentPlaybackMediaPath == sourceMediaPath {
      return
    }
    let progress = player.position
    let shouldResume = player.isPlaying
    reopenPlayer(with: sourceMediaPath, preserve: progress, shouldResume: shouldResume)
  }

  private func applySingleTrackAudioChannelRouting() {
    resetSingleTrackRoutingToSourceIfNeeded()
    player.audioChannel = audioChannel(for: requestedAudioOutputMode)
    currentPlaybackMediaPath = currentSourceMediaPath
    playbackError = nil
  }

  private func reopenPlayer(
    with mediaPath: String,
    preserve progress: Float,
    shouldResume: Bool
  ) {
    let oldPlayer = player
    player = buildPlayer()
    playbackCompleted = false
    playbackError = nil
    lastKnownPositionMs = 0
    lastKnownDurationMs = 0
    player.media = VLCMedia(path: mediaPath)
    if let videoView {
      player.drawable = videoView
    }
    player.play()
    if progress > 0 {
      player.position = progress
    }
    if !shouldResume {
      player.pause()
    }

    oldPlayer.delegate = nil
    oldPlayer.stop()
    currentPlaybackMediaPath = mediaPath
  }

  func attachVideoView(_ view: NSView) {
    videoView = view
    player.drawable = view
    sendSnapshot()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(currentSnapshot())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func mediaPlayerStateChanged(_ aNotification: Notification) {
    let newState = player.state
    switch newState {
    case .opening, .buffering:
      playbackCompleted = false
      playbackError = nil
    case .playing:
      playbackCompleted = false
      playbackError = nil
      applyRequestedAudioOutputModeIfPossible()
    case .ended:
      playbackCompleted = true
      playbackError = nil
    case .error:
      playbackError = "macOS 原生播放器无法识别当前文件。"
    case .stopped:
      playbackCompleted = isNearMediaEnd
    case .paused:
      break
    default:
      break
    }

    applyRequestedAudioOutputModeIfPossible()
    sendSnapshot()
  }

  func mediaPlayerTimeChanged(_ aNotification: Notification) {
    lastKnownPositionMs = currentPositionMs
    lastKnownDurationMs = currentDurationMs
    sendSnapshot()
  }

  private var isNearMediaEnd: Bool {
    let durationMs = max(currentDurationMs, lastKnownDurationMs)
    guard durationMs > 0 else {
      return false
    }
    let positionMs = max(currentPositionMs, lastKnownPositionMs)
    return positionMs >= max(durationMs - 1500, 0)
  }

  private var currentPositionMs: Int {
    Int(player.time.intValue)
  }

  private var currentDurationMs: Int {
    if let media = player.media {
      return Int(media.length.intValue)
    }
    return 0
  }

  private var availableAudioTracks: [(id: Int, name: String)] {
    let names = (player.audioTrackNames as? [String]) ?? []
    let indexes = (player.audioTrackIndexes as? [NSNumber]) ?? []
    let pairs = zip(indexes, names).compactMap { rawIndex, rawName -> (Int, String)? in
      let trackId = rawIndex.intValue
      if trackId < 0 {
        return nil
      }
      return (trackId, rawName)
    }
    return Array(pairs)
  }

  private var availableVideoTracks: [(id: Int, name: String)] {
    let names = (player.videoTrackNames as? [String]) ?? []
    let indexes = (player.videoTrackIndexes as? [NSNumber]) ?? []
    let pairs = zip(indexes, names).compactMap { rawIndex, rawName -> (Int, String)? in
      let trackId = rawIndex.intValue
      if trackId < 0 {
        return nil
      }
      return (trackId, rawName)
    }
    return Array(pairs)
  }

  private func preferredAudioTrackId(for mode: String) -> Int? {
    let tracks = availableAudioTracks
    guard !tracks.isEmpty else {
      return nil
    }

    func containsKeyword(_ name: String, keywords: [String]) -> Bool {
      let lowercased = name.lowercased()
      return keywords.contains { lowercased.contains($0) }
    }

    if mode == "original" {
      if let matched = tracks.first(where: {
        containsKeyword($0.name, keywords: ["原唱", "人声", "vocal", "original", "lead"])
      }) {
        return matched.id
      }
      return tracks.first?.id
    }

    if let matched = tracks.first(where: {
      containsKeyword($0.name, keywords: ["伴唱", "伴奏", "karaoke", "instrumental", "music", "bgm"])
    }) {
      return matched.id
    }
    return tracks.count > 1 ? tracks[1].id : tracks.first?.id
  }

  private func currentSnapshot() -> [String: Any] {
    let audioTracks = availableAudioTracks
    let videoTracks = availableVideoTracks
    let positionMs = max(currentPositionMs, lastKnownPositionMs)
    let durationMs = max(currentDurationMs, lastKnownDurationMs)
    return [
      "isPlaying": player.isPlaying,
      "isPlaybackCompleted": playbackCompleted,
      "hasVideoOutput": player.hasVideoOut,
      "playbackPositionMs": positionMs,
      "playbackDurationMs": durationMs,
      "videoTrackCount": videoTracks.count,
      "audioTrackCount": audioTracks.count,
      "playbackError": playbackError as Any
    ]
  }

  private func sendSnapshot() {
    eventSink?(currentSnapshot())
  }

  private func applyRequestedAudioOutputModeIfPossible() {
    let audioTracks = availableAudioTracks
    let audioTrackCount = audioTracks.count
    guard audioTrackCount > 0 else {
      return
    }

    if audioTrackCount > 1 {
      if let trackId = preferredAudioTrackId(for: requestedAudioOutputMode) {
        player.currentAudioTrackIndex = Int32(trackId)
      }
      player.audioChannel = Int32(vlcAudioChannelStereo)
      return
    }

    guard currentSourceMediaPath != nil else {
      return
    }
    applySingleTrackAudioChannelRouting()
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Missing media path.",
            details: nil
          )
        )
        return
      }

      if let mode = arguments["audioOutputMode"] as? String {
        requestedAudioOutputMode = mode
      }

      guard FileManager.default.fileExists(atPath: path) else {
        result(
          FlutterError(
            code: "FILE_NOT_FOUND",
            message: "本地视频文件不存在。",
            details: path
          )
        )
        return
      }

      playbackCompleted = false
      playbackError = nil
      lastKnownPositionMs = 0
      lastKnownDurationMs = 0
      currentSourceMediaPath = path
      currentPlaybackMediaPath = path
      player.stop()
      player.media = VLCMedia(path: path)
      if let videoView {
        player.drawable = videoView
      }
      player.play()
      applyRequestedAudioOutputModeIfPossible()
      result(currentSnapshot())
    case "play":
      playbackCompleted = false
      player.play()
      result(currentSnapshot())
    case "pause":
      player.pause()
      result(currentSnapshot())
    case "seekToProgress":
      guard
        let arguments = call.arguments as? [String: Any],
        let rawProgress = arguments["progress"] as? Double
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Missing playback progress.",
            details: nil
          )
        )
        return
      }

      let clampedProgress = min(max(Float(rawProgress), 0), 1)
      playbackCompleted = false
      playbackError = nil
      player.position = clampedProgress
      let durationMs = max(currentDurationMs, lastKnownDurationMs)
      lastKnownPositionMs = Int(Float(durationMs) * clampedProgress)
      result(currentSnapshot())
    case "setAudioOutputMode":
      guard
        let arguments = call.arguments as? [String: Any],
        let mode = arguments["mode"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Missing audio output mode.",
            details: nil
          )
        )
        return
      }

      requestedAudioOutputMode = mode
      applyRequestedAudioOutputModeIfPossible()
      result(currentSnapshot())
    case "dispose":
      currentSourceMediaPath = nil
      currentPlaybackMediaPath = nil
      player.stop()
      player.drawable = nil
      playbackCompleted = false
      playbackError = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
