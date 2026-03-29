package com.ktv.player.ktv2

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class Ktv2Plugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private companion object {
        const val videoPickerRequestCode = 9021
        const val videoPickerChannel = "ktv/video_picker"
    }

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingVideoPickerResult: MethodChannel.Result? = null
    private var videoPickerMethodChannel: MethodChannel? = null
    private var nativePlayerHost: NativeKtvPlayerHost? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        nativePlayerHost =
            NativeKtvPlayerHost(
                binding.applicationContext,
                binding.binaryMessenger,
                binding.platformViewRegistry,
            )

        videoPickerMethodChannel =
            MethodChannel(binding.binaryMessenger, videoPickerChannel).also {
                it.setMethodCallHandler(this)
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        pendingVideoPickerResult?.error("plugin_detached", "Video picker was detached.", null)
        pendingVideoPickerResult = null
        videoPickerMethodChannel?.setMethodCallHandler(null)
        videoPickerMethodChannel = null
        nativePlayerHost?.dispose()
        nativePlayerHost = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickVideo" -> handlePickVideo(result)
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != videoPickerRequestCode) {
            return false
        }

        val pendingResult = pendingVideoPickerResult
        pendingVideoPickerResult = null
        if (pendingResult == null) {
            return true
        }

        val currentActivity = activity
        if (currentActivity == null) {
            pendingResult.error("no_activity", "Activity is unavailable.", null)
            return true
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult.success(null)
            return true
        }

        val uri = data.data
        if (uri == null) {
            pendingResult.error("picker_failed", "Failed to retrieve selected file URI", null)
            return true
        }

        val takeFlags =
            data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            if (takeFlags != 0) {
                currentActivity.contentResolver.takePersistableUriPermission(uri, takeFlags)
            }
        } catch (_: SecurityException) {
            try {
                currentActivity.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
            }
        }

        pendingResult.success(
            mapOf(
                "uri" to uri.toString(),
                "displayName" to
                    (resolveDisplayName(currentActivity, uri) ?: uri.lastPathSegment ?: "已选视频"),
            ),
        )
        return true
    }

    private fun detachFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        pendingVideoPickerResult?.error("no_activity", "Activity was detached.", null)
        pendingVideoPickerResult = null
    }

    private fun handlePickVideo(result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("no_activity", "Video picker requires a foreground activity.", null)
            return
        }

        if (pendingVideoPickerResult != null) {
            result.error("picker_busy", "A picker request is already in progress", null)
            return
        }

        pendingVideoPickerResult = result
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
        currentActivity.startActivityForResult(intent, videoPickerRequestCode)
    }

    private fun resolveDisplayName(
        activity: Activity,
        uri: Uri,
    ): String? {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        activity.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
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
}
