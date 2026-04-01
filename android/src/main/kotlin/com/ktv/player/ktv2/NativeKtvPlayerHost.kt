package com.ktv.player.ktv2

import android.content.Context
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformViewRegistry
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.interfaces.IMedia
import org.videolan.libvlc.util.VLCVideoLayout
import java.io.File
import java.io.FileOutputStream

class NativeKtvPlayerHost(
    context: Context,
    messenger: BinaryMessenger,
    platformViewRegistry: PlatformViewRegistry,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, MediaPlayer.EventListener {
    private companion object {
        const val tag = "KtvNative"
        const val singleTrackAudioRoutingRetryDelayMs = 180L
        const val initialAudioRoutingReapplyDelayMs = 420L
        const val maxSingleTrackAudioRoutingRetries = 6
        const val libVlcAudioChannelStereo = 1
        const val libVlcAudioChannelLeft = 3
        const val libVlcAudioChannelRight = 4
        const val nativeSingleTrackRoutingEnabled = true

        val libVlcBridgeLoaded =
            if (!nativeSingleTrackRoutingEnabled) {
                false
            } else {
                runCatching { System.loadLibrary("ktv_vlc_bridge") }
                    .onFailure {
                        Log.w(
                            tag,
                            "Unable to load ktv_vlc_bridge, single-track audio routing is unavailable.",
                            it,
                        )
                    }.isSuccess
            }
    }

    private enum class AudioOutputMode {
        ORIGINAL,
        ACCOMPANIMENT,
    }

    private data class AudioTrackCandidate(
        val id: Int,
        val title: String,
        val channelCount: Int?,
    )

    private data class PendingPlaybackRequest(
        val path: String,
        val preservePositionMs: Long,
        val shouldResume: Boolean,
    )

    private data class MediaTrackCounts(
        val video: Int,
        val audio: Int,
    )

    private val applicationContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(messenger, "ktv/native_player")
    private val eventChannel = EventChannel(messenger, "ktv/native_player_events")

    private var libVlcInstance: LibVLC? = null
    private var mediaPlayer: MediaPlayer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var videoLayout: VLCVideoLayout? = null
    private var currentMediaPath: String? = null
    private var currentPlaybackPath: String? = null
    private var playbackCompleted = false
    private var playbackError: String? = null
    private var requestedAudioOutputMode = AudioOutputMode.ORIGINAL
    private var selectedAudioTrackTitle: String? = null
    private var selectedAudioChannelCount: Int? = null
    private var lastKnownPositionMs = 0L
    private var lastKnownDurationMs = 0L
    private var lastKnownVoutCount = 0
    private var isApplyingAudioOutputMode = false
    private var appliedSingleTrackAudioOutputMode: AudioOutputMode? = null
    private var singleTrackAudioRoutingRetryCount = 0
    private var pendingPlaybackRequest: PendingPlaybackRequest? = null
    private var pendingAttachStateListener: View.OnAttachStateChangeListener? = null
    private var pendingLayoutChangeListener: View.OnLayoutChangeListener? = null
    private var pendingInitialAudioRoutingReapplyRunnable: Runnable? = null
    private var lastAttachedLayoutWidth = 0
    private var lastAttachedLayoutHeight = 0
    private var keepScreenOnRequested = false
    private var singleTrackNativeChannelRoutingAvailable: Boolean? =
        if (libVlcBridgeLoaded) {
            null
        } else {
            false
        }

    private val positionUpdateRunnable =
        object : Runnable {
            override fun run() {
                pushSnapshot()
                mainHandler.postDelayed(this, 300L)
            }
        }

    private val singleTrackAudioRoutingRetryRunnable =
        Runnable {
            applyRequestedAudioOutputModeIfPossible()
        }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        platformViewRegistry.registerViewFactory(
            "ktv/native_video_view",
            NativeKtvVideoViewFactory(this),
        )
        mainHandler.post(positionUpdateRunnable)
    }

    private val libVlc: LibVLC
        get() =
            libVlcInstance ?: LibVLC(applicationContext, arrayListOf("--verbose=2")).also {
                libVlcInstance = it
            }

    private val player: MediaPlayer
        get() =
            mediaPlayer ?: MediaPlayer(libVlc).also {
                it.setEventListener(this)
                mediaPlayer = it
            }

    private val playerOrNull: MediaPlayer?
        get() = mediaPlayer

    private external fun nativeSetAudioChannel(
        playerInstance: Long,
        channel: Int,
    ): Boolean

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    val path =
                        call.argument<String>("path")
                            ?: throw IllegalArgumentException("Missing media path")
                    val mode = parseAudioOutputMode(call.argument("audioOutputMode"))
                    result.success(open(path, mode))
                }
                "play" -> {
                    playbackCompleted = false
                    flushPendingPlaybackRequestIfPossible()
                    if (pendingPlaybackRequest == null) {
                        player.play()
                        setKeepScreenOnRequested(true)
                    }
                    result.success(snapshot())
                }
                "pause" -> {
                    player.pause()
                    setKeepScreenOnRequested(false)
                    result.success(snapshot())
                }
                "seekToProgress" -> {
                    val progress = (call.argument<Double>("progress") ?: 0.0).coerceIn(0.0, 1.0)
                    seekToProgress(progress)
                    result.success(snapshot())
                }
                "setAudioOutputMode" -> {
                    requestedAudioOutputMode = parseAudioOutputMode(call.argument("mode"))
                    playbackError = null
                    applyRequestedAudioOutputModeIfPossible()
                    result.success(snapshot())
                }
                "dispose" -> {
                    dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("native_player_error", handlePlaybackFailure(error), null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        pushSnapshot()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onEvent(event: MediaPlayer.Event) {
        val eventType = event.type
        val timeChanged = event.timeChanged
        val lengthChanged = event.lengthChanged
        val voutCount = event.voutCount
        mainHandler.post {
            when (eventType) {
                MediaPlayer.Event.Opening -> {
                    playbackCompleted = false
                    playbackError = null
                }
                MediaPlayer.Event.Buffering -> {
                    playbackCompleted = false
                }
                MediaPlayer.Event.Playing -> {
                    playbackCompleted = false
                    playbackError = null
                    updateSelectedAudioTrackInfo()
                    applyRequestedAudioOutputModeIfPossible()
                    videoLayout?.let { attachPlayerViews(it, reason = "event:Playing") }
                }
                MediaPlayer.Event.Paused -> {
                    keepScreenOnRequested = false
                    updateSelectedAudioTrackInfo()
                }
                MediaPlayer.Event.Stopped -> {
                    keepScreenOnRequested = false
                    playbackCompleted = isNearMediaEnd
                }
                MediaPlayer.Event.EndReached -> {
                    keepScreenOnRequested = false
                    playbackCompleted = true
                    lastKnownPositionMs = currentDurationMs
                }
                MediaPlayer.Event.EncounteredError -> {
                    keepScreenOnRequested = false
                    playbackError = "Android libVLC 无法识别当前文件。"
                }
                MediaPlayer.Event.TimeChanged -> {
                    lastKnownPositionMs = timeChanged.coerceAtLeast(0L)
                }
                MediaPlayer.Event.LengthChanged -> {
                    lastKnownDurationMs = lengthChanged.coerceAtLeast(0L)
                }
                MediaPlayer.Event.Vout -> {
                    lastKnownVoutCount = voutCount
                    videoLayout?.let { attachPlayerViews(it, reason = "event:Vout") }
                }
                MediaPlayer.Event.ESAdded,
                MediaPlayer.Event.ESDeleted,
                MediaPlayer.Event.ESSelected,
                MediaPlayer.Event.MediaChanged,
                -> {
                    updateSelectedAudioTrackInfo()
                    applyRequestedAudioOutputModeIfPossible()
                }
            }
            if (
                eventType == MediaPlayer.Event.Opening ||
                eventType == MediaPlayer.Event.Playing ||
                eventType == MediaPlayer.Event.Buffering ||
                eventType == MediaPlayer.Event.Vout ||
                eventType == MediaPlayer.Event.EncounteredError ||
                eventType == MediaPlayer.Event.ESAdded ||
                eventType == MediaPlayer.Event.ESSelected ||
                eventType == MediaPlayer.Event.LengthChanged
            ) {
                Log.i(
                    tag,
                    "event type=${eventName(eventType)} time=$timeChanged length=$lengthChanged vout=$voutCount error=$playbackError playbackPath=$currentPlaybackPath",
                )
            }
            syncKeepScreenOnState()
            pushSnapshot()
        }
    }

    fun dispose() {
        mainHandler.removeCallbacks(positionUpdateRunnable)
        mainHandler.removeCallbacks(singleTrackAudioRoutingRetryRunnable)
        clearPendingInitialAudioRoutingReapply()
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        clearPendingAttachStateListener()
        clearPendingLayoutChangeListener()
        keepScreenOnRequested = false
        videoLayout?.let { applyKeepScreenOnState(it, false) }
        val player = playerOrNull
        if (player?.getVLCVout()?.areViewsAttached() == true) {
            player.detachViews()
        }
        lastAttachedLayoutWidth = 0
        lastAttachedLayoutHeight = 0
        videoLayout = null
        player?.stop()
        player?.release()
        mediaPlayer = null
        libVlcInstance?.release()
        libVlcInstance = null
    }

    private fun createVideoLayout(context: Context): VLCVideoLayout {
        return VLCVideoLayout(context).also(::attachVideoLayout)
    }

    private fun detachVideoLayout(layout: VLCVideoLayout) {
        if (videoLayout !== layout) {
            return
        }
        clearPendingAttachStateListener()
        clearPendingLayoutChangeListener()
        applyKeepScreenOnState(layout, false)
        val player = playerOrNull
        if (player?.getVLCVout()?.areViewsAttached() == true) {
            player.detachViews()
        }
        lastAttachedLayoutWidth = 0
        lastAttachedLayoutHeight = 0
        videoLayout = null
        pushSnapshot()
    }

    private fun attachVideoLayout(layout: VLCVideoLayout) {
        clearPendingAttachStateListener()
        clearPendingLayoutChangeListener()
        val player = playerOrNull
        if (player?.getVLCVout()?.areViewsAttached() == true) {
            player.detachViews()
        }
        lastAttachedLayoutWidth = 0
        lastAttachedLayoutHeight = 0
        videoLayout = layout
        syncKeepScreenOnState()
        installLayoutChangeListener(layout)
        if (layout.isAttachedToWindow) {
            attachPlayerViews(layout, reason = "layout:attached")
        } else {
            val listener =
                object : View.OnAttachStateChangeListener {
                    override fun onViewAttachedToWindow(view: View) {
                        layout.removeOnAttachStateChangeListener(this)
                        if (pendingAttachStateListener === this) {
                            pendingAttachStateListener = null
                        }
                        attachPlayerViews(layout, reason = "layout:onAttachedToWindow")
                    }

                    override fun onViewDetachedFromWindow(view: View) = Unit
                }
            pendingAttachStateListener = listener
            layout.addOnAttachStateChangeListener(listener)
        }
        pushSnapshot()
    }

    private fun installLayoutChangeListener(layout: VLCVideoLayout) {
        val listener =
            View.OnLayoutChangeListener { _, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
                val width = right - left
                val height = bottom - top
                val oldWidth = oldRight - oldLeft
                val oldHeight = oldBottom - oldTop
                if (width <= 0 || height <= 0) {
                    return@OnLayoutChangeListener
                }
                if (width == oldWidth && height == oldHeight) {
                    return@OnLayoutChangeListener
                }
                attachPlayerViews(
                    layout,
                    reason = "layout:${oldWidth}x${oldHeight}->${width}x${height}",
                    forceReattach = false,
                )
            }
        pendingLayoutChangeListener = listener
        layout.addOnLayoutChangeListener(listener)
    }

    private fun attachPlayerViews(
        layout: VLCVideoLayout,
        reason: String,
        forceReattach: Boolean = false,
    ) {
        if (videoLayout !== layout || !layout.isAttachedToWindow) {
            return
        }

        mainHandler.post {
            try {
                if (videoLayout !== layout || !layout.isAttachedToWindow) {
                    return@post
                }
                val width = layout.width
                val height = layout.height
                if (width <= 0 || height <= 0) {
                    Log.i(
                        tag,
                        "attachPlayerViews skipped reason=$reason width=$width height=$height attached=${layout.isAttachedToWindow}",
                    )
                    return@post
                }
                val player = player
                val vout = player.getVLCVout()
                if (forceReattach && vout.areViewsAttached()) {
                    player.detachViews()
                }
                if (!vout.areViewsAttached()) {
                    player.attachViews(layout, null, false, true)
                }
                configureVideoSurfaceOverlay(layout)
                applyDefaultVideoScale(player)
                vout.setWindowSize(width, height)
                player.updateVideoSurfaces()
                lastAttachedLayoutWidth = width
                lastAttachedLayoutHeight = height
                Log.i(
                    tag,
                    "attachPlayerViews reason=$reason width=$width height=$height forceReattach=$forceReattach viewsAttached=${vout.areViewsAttached()}",
                )
                flushPendingPlaybackRequestIfPossible()
                pushSnapshot()
            } catch (error: Throwable) {
                handlePlaybackFailure(error, "Android libVLC 视图初始化失败。")
            }
        }
    }

    private fun clearPendingAttachStateListener() {
        pendingAttachStateListener?.let { listener ->
            videoLayout?.removeOnAttachStateChangeListener(listener)
            pendingAttachStateListener = null
        }
    }

    private fun clearPendingLayoutChangeListener() {
        pendingLayoutChangeListener?.let { listener ->
            videoLayout?.removeOnLayoutChangeListener(listener)
            pendingLayoutChangeListener = null
        }
    }

    private fun setKeepScreenOnRequested(keepScreenOn: Boolean) {
        keepScreenOnRequested = keepScreenOn
        syncKeepScreenOnState()
    }

    private fun syncKeepScreenOnState() {
        videoLayout?.let { applyKeepScreenOnState(it, keepScreenOnRequested) }
    }

    private fun applyKeepScreenOnState(
        layout: VLCVideoLayout,
        keepScreenOn: Boolean = keepScreenOnRequested,
    ) {
        layout.keepScreenOn = keepScreenOn
        layout.findViewById<SurfaceView?>(org.videolan.R.id.surface_video)?.keepScreenOn =
            keepScreenOn
    }

    private fun configureVideoSurfaceOverlay(layout: VLCVideoLayout) {
        val surfaceView = layout.findViewById<SurfaceView?>(org.videolan.R.id.surface_video) ?: return
        surfaceView.setZOrderOnTop(true)
        surfaceView.holder.setFormat(PixelFormat.TRANSLUCENT)
        applyKeepScreenOnState(layout)
    }

    private fun applyDefaultVideoScale(player: MediaPlayer) {
        // Keep libVLC in aspect-preserving mode during container resizes.
        player.setAspectRatio(null)
        player.setScale(0f)
    }

    private fun open(
        path: String,
        mode: AudioOutputMode,
    ): Map<String, Any?> {
        ensurePlayablePath(path)
        currentMediaPath = path
        requestedAudioOutputMode = mode
        currentPlaybackPath = resolvePlaybackPath(path)
        playbackError = null
        playbackCompleted = false
        lastKnownPositionMs = 0L
        lastKnownDurationMs = 0L
        lastKnownVoutCount = 0
        appliedSingleTrackAudioOutputMode = null
        resetSingleTrackAudioRoutingRetry()
        clearPendingInitialAudioRoutingReapply()
        selectedAudioTrackTitle = null
        selectedAudioChannelCount = null
        Log.i(
            tag,
            "open sourcePath=$path playbackPath=$currentPlaybackPath mode=$mode",
        )
        queueOrOpenPlaybackMedia(currentPlaybackPath ?: path, 0L, shouldResume = true)
        return snapshot()
    }

    private fun queueOrOpenPlaybackMedia(
        path: String,
        preservePositionMs: Long,
        shouldResume: Boolean,
    ) {
        ensurePlayablePath(path)
        pendingPlaybackRequest = null
        openPlaybackMedia(path, preservePositionMs, shouldResume)
    }

    private fun flushPendingPlaybackRequestIfPossible() {
        val pendingRequest = pendingPlaybackRequest ?: return
        pendingPlaybackRequest = null
        openPlaybackMedia(
            pendingRequest.path,
            preservePositionMs = pendingRequest.preservePositionMs,
            shouldResume = pendingRequest.shouldResume,
        )
    }

    private fun openPlaybackMedia(
        path: String,
        preservePositionMs: Long,
        shouldResume: Boolean,
    ) {
        ensurePlayablePath(path)
        player.stop()
        lastKnownVoutCount = 0
        playbackCompleted = false
        playbackError = null
        appliedSingleTrackAudioOutputMode = null
        resetSingleTrackAudioRoutingRetry()
        clearPendingInitialAudioRoutingReapply()
        selectedAudioTrackTitle = null
        selectedAudioChannelCount = null

        val media = buildMedia(path)
        try {
            player.setMedia(media)
        } finally {
            media.release()
        }

        currentPlaybackPath = path
        keepScreenOnRequested = shouldResume
        player.play()
        scheduleInitialAudioRoutingReapply(path)
        if (preservePositionMs > 0L) {
            player.setTime(preservePositionMs.coerceAtLeast(0L))
        }
        if (!shouldResume) {
            player.pause()
        }
        syncKeepScreenOnState()
        videoLayout?.let { attachPlayerViews(it, reason = "openPlaybackMedia") }
        updateSelectedAudioTrackInfo()
        Log.i(
            tag,
            "openPlaybackMedia path=$path shouldResume=$shouldResume positionMs=$preservePositionMs",
        )
    }

    private fun seekToProgress(progress: Double) {
        val durationMs = currentDurationMs
        if (durationMs <= 0L) {
            return
        }
        val targetPositionMs = (durationMs * progress).toLong().coerceAtLeast(0L)
        playbackCompleted = false
        playbackError = null
        lastKnownPositionMs = targetPositionMs
        player.setTime(targetPositionMs)
    }

    private fun snapshot(): Map<String, Any?> {
        val player = playerOrNull
        updateSelectedAudioTrackInfo()
        val mediaTrackCounts = resolvedMediaTrackCounts()
        val audioTracks = availableAudioTracks()
        return mapOf(
            "isPlaying" to (player?.isPlaying ?: false),
            "isPlaybackCompleted" to playbackCompleted,
            "hasVideoOutput" to (player != null && lastKnownVoutCount > 0),
            "playbackPositionMs" to currentPositionMs,
            "playbackDurationMs" to currentDurationMs,
            "videoTrackCount" to mediaTrackCounts.video,
            "audioTrackCount" to maxOf(mediaTrackCounts.audio, resolvedAudioTrackCount(audioTracks)),
            "playbackError" to playbackError,
            "selectedAudioTrackTitle" to selectedAudioTrackTitle,
            "selectedAudioChannelCount" to selectedAudioChannelCount,
        )
    }

    private fun pushSnapshot() {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            eventSink?.success(snapshot())
        } else {
            mainHandler.post { eventSink?.success(snapshot()) }
        }
    }

    private fun updateSelectedAudioTrackInfo() {
        val player = playerOrNull
        val audioTracks = availableAudioTracks()
        if (audioTracks.isEmpty()) {
            selectedAudioChannelCount = null
            selectedAudioTrackTitle =
                if ((player?.getAudioTrack() ?: -1) >= 0) {
                    "音轨 1"
                } else {
                    null
                }
            return
        }
        val selectedTrack =
            audioTracks.firstOrNull { it.id == player?.getAudioTrack() }
                ?: audioTracks.firstOrNull()
        selectedAudioTrackTitle = selectedTrack?.title
        selectedAudioChannelCount = selectedTrack?.channelCount
    }

    private fun resolvedAudioTrackCount(audioTracks: List<AudioTrackCandidate>): Int {
        if (audioTracks.isNotEmpty()) {
            return audioTracks.size
        }
        return if (playerOrNull?.getAudioTrack() ?: -1 >= 0) 1 else 0
    }

    private fun availableAudioTracks(): List<AudioTrackCandidate> {
        val player = playerOrNull ?: return emptyList()
        val trackDescriptions = player.getAudioTracks()
        if (trackDescriptions != null) {
            val candidates =
                trackDescriptions
                    .filter { it.id >= 0 }
                    .mapIndexed { index, track ->
                        val title = track.name.takeIf { it.isNotBlank() } ?: "音轨 ${index + 1}"
                        AudioTrackCandidate(
                            id = track.id,
                            title = title,
                            channelCount = resolveAudioTrackChannelCount(track.id),
                        )
                    }
            if (candidates.isNotEmpty()) {
                return candidates
            }
        }

        val media = player.getMedia() ?: return emptyList()
        val candidates = mutableListOf<AudioTrackCandidate>()
        val trackCount = media.getTrackCount()
        for (index in 0 until trackCount) {
            val track = media.getTrack(index) as? IMedia.AudioTrack ?: continue
            val title =
                track.description?.takeIf { it.isNotBlank() }
                    ?: track.language?.takeIf { it.isNotBlank() }
                    ?: "音轨 ${candidates.size + 1}"
            candidates +=
                AudioTrackCandidate(
                    id = track.id,
                    title = title,
                    channelCount = track.channels,
                )
        }
        return candidates
    }

    private fun resolvedMediaTrackCounts(): MediaTrackCounts {
        val player = playerOrNull ?: return MediaTrackCounts(0, 0)
        val media = player.getMedia() ?: return MediaTrackCounts(0, 0)
        var videoTracks = 0
        var audioTracks = 0
        val trackCount = media.getTrackCount()
        for (index in 0 until trackCount) {
            when (media.getTrack(index).type) {
                IMedia.Track.Type.Video -> videoTracks += 1
                IMedia.Track.Type.Audio -> audioTracks += 1
            }
        }
        return MediaTrackCounts(
            video = videoTracks,
            audio = audioTracks,
        )
    }

    private fun resolveAudioTrackChannelCount(trackId: Int): Int? {
        val player = playerOrNull ?: return null
        val media = player.getMedia() ?: return null
        val trackCount = media.getTrackCount()
        for (index in 0 until trackCount) {
            val track = media.getTrack(index)
            if (track.type != IMedia.Track.Type.Audio || track.id != trackId) {
                continue
            }
            return (track as? IMedia.AudioTrack)?.channels
        }
        return null
    }

    private fun preferredAudioTrackForMode(
        mode: AudioOutputMode,
        candidates: List<AudioTrackCandidate>,
    ): AudioTrackCandidate {
        val originalKeywords = listOf("原唱", "人声", "vocal", "original", "lead")
        val accompanimentKeywords = listOf("伴唱", "伴奏", "karaoke", "instrumental", "music", "bgm")
        val keywords = if (mode == AudioOutputMode.ORIGINAL) originalKeywords else accompanimentKeywords
        return candidates.firstOrNull { candidate ->
            val text = candidate.title.lowercase()
            keywords.any(text::contains)
        }
            ?: if (mode == AudioOutputMode.ACCOMPANIMENT && candidates.size > 1) {
                candidates[1]
            } else {
                candidates.first()
            }
    }

    private fun applyRequestedAudioOutputModeIfPossible() {
        val mediaPath = currentMediaPath ?: return
        if (isApplyingAudioOutputMode) {
            return
        }

        val audioTracks = availableAudioTracks()
        Log.i(
            tag,
            "applyAudioOutputMode requested=$requestedAudioOutputMode source=$mediaPath playback=$currentPlaybackPath audioTracks=${audioTracks.size}",
        )
        isApplyingAudioOutputMode = true
        try {
            if (audioTracks.size > 1) {
                resetSingleTrackAudioRoutingRetry()
                playbackError = null
                restoreStereoAudioChannelRouting()
                val targetTrack = preferredAudioTrackForMode(requestedAudioOutputMode, audioTracks)
                if (player.getAudioTrack() != targetTrack.id) {
                    player.setAudioTrack(targetTrack.id)
                }
                selectedAudioTrackTitle = targetTrack.title
                selectedAudioChannelCount = targetTrack.channelCount
                return
            }

            if (libVlcBridgeLoaded && singleTrackNativeChannelRoutingAvailable != false) {
                if (appliedSingleTrackAudioOutputMode == requestedAudioOutputMode) {
                    return
                }
                if (applySingleTrackAudioChannelRouting(requestedAudioOutputMode)) {
                    resetSingleTrackAudioRoutingRetry()
                    playbackError = null
                    updateSelectedAudioTrackInfo()
                    return
                }
                scheduleSingleTrackAudioRoutingRetry("nativeSetAudioChannel returned false for $mediaPath")
                return
            }

            if (player.instance == 0L || player.getMedia() == null) {
                return
            }

            scheduleSingleTrackAudioRoutingRetry("audio track metadata not ready for $mediaPath")
        } catch (error: Exception) {
            playbackError = "${localizedModeName(requestedAudioOutputMode)}切换失败：${error.message ?: error}"
            Log.e(tag, "applyRequestedAudioOutputMode failed", error)
        } finally {
            isApplyingAudioOutputMode = false
        }
    }

    private fun applySingleTrackAudioChannelRouting(mode: AudioOutputMode): Boolean {
        if (!libVlcBridgeLoaded || singleTrackNativeChannelRoutingAvailable == false) {
            return false
        }
        val playerInstance = player.instance
        if (playerInstance == 0L) {
            return false
        }
        val targetChannel =
            if (mode == AudioOutputMode.ACCOMPANIMENT) {
                libVlcAudioChannelLeft
            } else {
                libVlcAudioChannelRight
            }
        return try {
            val applied = nativeSetAudioChannel(playerInstance, targetChannel)
            if (applied) {
                singleTrackNativeChannelRoutingAvailable = true
                appliedSingleTrackAudioOutputMode = mode
            }
            applied
        } catch (error: UnsatisfiedLinkError) {
            singleTrackNativeChannelRoutingAvailable = false
            Log.e(tag, "nativeSetAudioChannel missing", error)
            false
        }
    }

    private fun restoreStereoAudioChannelRouting() {
        if (!libVlcBridgeLoaded || singleTrackNativeChannelRoutingAvailable == false) {
            appliedSingleTrackAudioOutputMode = null
            return
        }
        try {
            if (player.instance != 0L) {
                nativeSetAudioChannel(player.instance, libVlcAudioChannelStereo)
            }
        } catch (_: UnsatisfiedLinkError) {
            singleTrackNativeChannelRoutingAvailable = false
        } finally {
            appliedSingleTrackAudioOutputMode = null
        }
    }

    private fun scheduleInitialAudioRoutingReapply(path: String) {
        if (!libVlcBridgeLoaded || singleTrackNativeChannelRoutingAvailable == false) {
            return
        }
        clearPendingInitialAudioRoutingReapply()
        val expectedMode = requestedAudioOutputMode
        val runnable =
            Runnable {
                pendingInitialAudioRoutingReapplyRunnable = null
                if (currentPlaybackPath != path || player.instance == 0L) {
                    return@Runnable
                }
                appliedSingleTrackAudioOutputMode = null
                requestedAudioOutputMode = expectedMode
                applyRequestedAudioOutputModeIfPossible()
            }
        pendingInitialAudioRoutingReapplyRunnable = runnable
        mainHandler.postDelayed(runnable, initialAudioRoutingReapplyDelayMs)
    }

    private fun clearPendingInitialAudioRoutingReapply() {
        pendingInitialAudioRoutingReapplyRunnable?.let(mainHandler::removeCallbacks)
        pendingInitialAudioRoutingReapplyRunnable = null
    }

    private fun scheduleSingleTrackAudioRoutingRetry(reason: String) {
        if (singleTrackAudioRoutingRetryCount >= maxSingleTrackAudioRoutingRetries) {
            playbackError = "${localizedModeName(requestedAudioOutputMode)}切换失败：当前文件尚未准备好音频声道信息。"
            Log.w(tag, "singleTrackAudioRoutingRetry exhausted reason=$reason")
            return
        }
        singleTrackAudioRoutingRetryCount += 1
        Log.i(
            tag,
            "singleTrackAudioRoutingRetry attempt=$singleTrackAudioRoutingRetryCount reason=$reason",
        )
        mainHandler.removeCallbacks(singleTrackAudioRoutingRetryRunnable)
        mainHandler.postDelayed(
            singleTrackAudioRoutingRetryRunnable,
            singleTrackAudioRoutingRetryDelayMs,
        )
    }

    private fun resetSingleTrackAudioRoutingRetry() {
        singleTrackAudioRoutingRetryCount = 0
        mainHandler.removeCallbacks(singleTrackAudioRoutingRetryRunnable)
    }

    private val currentPositionMs: Long
        get() =
            playerOrNull?.time?.takeIf { it >= 0L }
                ?: lastKnownPositionMs

    private val currentDurationMs: Long
        get() =
            playerOrNull?.length?.takeIf { it > 0L }
                ?: lastKnownDurationMs

    private val isNearMediaEnd: Boolean
        get() {
            val durationMs = maxOf(currentDurationMs, lastKnownDurationMs)
            if (durationMs <= 0L) {
                return false
            }
            val positionMs = maxOf(currentPositionMs, lastKnownPositionMs)
            return positionMs >= maxOf(durationMs - 1500L, 0L)
        }

    private fun buildMedia(path: String): Media {
        if (path.startsWith("content://")) {
            return Media(libVlc, Uri.parse(path))
        }
        return Media(libVlc, path)
    }

    private fun ensurePlayablePath(path: String) {
        if (path.startsWith("content://")) {
            return
        }
        val file = File(path)
        require(file.exists()) { "本地视频文件不存在：$path" }
    }

    private fun resolvePlaybackPath(path: String): String? {
        if (!path.startsWith("content://")) {
            return path
        }

        return try {
            cacheContentUri(path)
        } catch (error: Throwable) {
            Log.w(tag, "resolvePlaybackPath failed for $path", error)
            path
        }
    }

    private fun cacheContentUri(path: String): String {
        val uri = Uri.parse(path)
        val cacheDir = File(applicationContext.cacheDir, "picked_media").also {
            if (!it.exists()) {
                it.mkdirs()
            }
        }

        val fileName = resolveDisplayName(uri)?.takeIf { it.isNotBlank() } ?: "picked_video"
        val outputFile = File(cacheDir, fileName)
        applicationContext.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        } ?: error("无法读取所选视频")
        return outputFile.absolutePath
    }

    private fun resolveDisplayName(uri: Uri): String? {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        applicationContext.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) {
                return null
            }
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && !cursor.isNull(index)) {
                return cursor.getString(index)
            }
        }
        return null
    }

    private fun parseAudioOutputMode(mode: String?): AudioOutputMode {
        return when (mode?.lowercase()) {
            "accompaniment" -> AudioOutputMode.ACCOMPANIMENT
            else -> AudioOutputMode.ORIGINAL
        }
    }

    private fun localizedModeName(mode: AudioOutputMode): String {
        return if (mode == AudioOutputMode.ACCOMPANIMENT) {
            "伴唱"
        } else {
            "原唱"
        }
    }

    private fun handlePlaybackFailure(
        error: Throwable,
        message: String = "Android libVLC 播放失败。",
    ): String {
        playbackError = "$message ${error.message ?: error}"
        Log.e(tag, playbackError, error)
        pushSnapshot()
        return playbackError ?: message
    }

    private fun eventName(eventType: Int): String {
        return when (eventType) {
            MediaPlayer.Event.Opening -> "Opening"
            MediaPlayer.Event.Buffering -> "Buffering"
            MediaPlayer.Event.Playing -> "Playing"
            MediaPlayer.Event.Paused -> "Paused"
            MediaPlayer.Event.Stopped -> "Stopped"
            MediaPlayer.Event.EndReached -> "EndReached"
            MediaPlayer.Event.EncounteredError -> "EncounteredError"
            MediaPlayer.Event.TimeChanged -> "TimeChanged"
            MediaPlayer.Event.LengthChanged -> "LengthChanged"
            MediaPlayer.Event.Vout -> "Vout"
            MediaPlayer.Event.ESAdded -> "ESAdded"
            MediaPlayer.Event.ESDeleted -> "ESDeleted"
            MediaPlayer.Event.ESSelected -> "ESSelected"
            MediaPlayer.Event.MediaChanged -> "MediaChanged"
            else -> eventType.toString()
        }
    }

    private class NativeKtvVideoViewFactory(
        private val host: NativeKtvPlayerHost,
    ) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(
            context: Context,
            viewId: Int,
            args: Any?,
        ): PlatformView {
            val layout = host.createVideoLayout(context)
            return object : PlatformView {
                override fun getView(): View = layout

                override fun dispose() {
                    host.detachVideoLayout(layout)
                }
            }
        }
    }
}
