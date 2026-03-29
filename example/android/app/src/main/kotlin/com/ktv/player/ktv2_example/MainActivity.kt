package com.ktv.player.ktv2_example

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val videoPickerRequestCode = 9021
        const val videoPickerChannel = "ktv2_example/video_picker"
    }

    private var pendingVideoPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            videoPickerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickVideo" -> handlePickVideo(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != videoPickerRequestCode) {
            return
        }

        val pendingResult = pendingVideoPickerResult
        pendingVideoPickerResult = null
        if (pendingResult == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult.success(null)
            return
        }

        val uri = data.data
        if (uri == null) {
            pendingResult.error("picker_failed", "Failed to retrieve selected file URI", null)
            return
        }

        val takeFlags =
            data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            if (takeFlags != 0) {
                contentResolver.takePersistableUriPermission(uri, takeFlags)
            }
        } catch (_: SecurityException) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
            }
        }

        pendingResult.success(
            mapOf(
                "uri" to uri.toString(),
                "displayName" to (resolveDisplayName(uri) ?: uri.lastPathSegment ?: "已选视频"),
            ),
        )
    }

    private fun handlePickVideo(result: MethodChannel.Result) {
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
        startActivityForResult(intent, videoPickerRequestCode)
    }

    private fun resolveDisplayName(uri: Uri): String? {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
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
