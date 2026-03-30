package com.ktv.player.ktv2_example

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ActivityInfo
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.view.Surface
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val preferencesName = "ktv2_example_prefs"
        const val selectedDirectoryKey = "selected_directory_uri"
        const val videoPickerRequestCode = 9021
        const val directoryPickerRequestCode = 9022
        const val videoPickerChannel = "ktv2_example/video_picker"
        const val androidStorageChannel = "ktv2_example/android_storage"
        const val orientationChannel = "ktv2_example/orientation"
        val supportedExtensions =
            setOf(
                "mp4",
                "mkv",
                "avi",
                "mov",
                "dat",
                "rmvb",
                "rm",
                "mpg",
                "mpeg",
                "vob",
            )
    }

    private var pendingVideoPickerResult: MethodChannel.Result? = null
    private var pendingDirectoryPickerResult: MethodChannel.Result? = null

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            androidStorageChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> handlePickDirectory(call, result)
                "ensureDirectoryAccess" -> {
                    val path = call.argument<String>("path")
                    result.success(path?.let(::ensureDirectoryAccess) ?: false)
                }
                "clearDirectoryAccess" -> {
                    clearDirectoryAccess(call.argument("path"))
                    result.success(null)
                }
                "saveSelectedDirectory" -> {
                    saveSelectedDirectory(call.argument("path"))
                    result.success(null)
                }
                "loadSelectedDirectory" -> {
                    result.success(loadSelectedDirectory())
                }
                "scanLibrary" -> {
                    val rootUri = call.argument<String>("rootUri")
                    if (rootUri.isNullOrBlank()) {
                        result.error("invalid_args", "Missing rootUri", null)
                    } else {
                        try {
                            result.success(scanLibrary(rootUri))
                        } catch (error: Exception) {
                            result.error(
                                "scan_failed",
                                error.message ?: "Failed to scan library",
                                null,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            orientationChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterVideoFullscreen" -> {
                    requestedOrientation = resolveLandscapeOrientation()
                    result.success(null)
                }
                "exitVideoFullscreen" -> {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun resolveLandscapeOrientation(): Int {
        val rotation = display?.rotation ?: Surface.ROTATION_0
        return if (rotation == Surface.ROTATION_270) {
            ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
        } else {
            ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            videoPickerRequestCode -> handleVideoPickerResult(resultCode, data)
            directoryPickerRequestCode -> handleDirectoryPickerResult(resultCode, data)
            else -> return
        }
    }

    private fun handleVideoPickerResult(resultCode: Int, data: Intent?) {
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

    private fun handleDirectoryPickerResult(resultCode: Int, data: Intent?) {
        val pendingResult = pendingDirectoryPickerResult
        pendingDirectoryPickerResult = null
        if (pendingResult == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult.success(null)
            return
        }

        val uri = data.data
        if (uri == null) {
            pendingResult.error("picker_failed", "Failed to retrieve selected directory URI", null)
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

        pendingResult.success(uri.toString())
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
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
        try {
            startActivityForResult(intent, videoPickerRequestCode)
        } catch (_: ActivityNotFoundException) {
            pendingVideoPickerResult = null
            result.error("picker_unavailable", "System document picker is unavailable", null)
        }
    }

    private fun handlePickDirectory(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDirectoryPickerResult != null) {
            result.error("picker_busy", "A directory picker request is already in progress", null)
            return
        }

        pendingDirectoryPickerResult = result
        val initialDirectory = call.argument<String>("initialDirectory")
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                if (
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !initialDirectory.isNullOrBlank() &&
                    initialDirectory.startsWith("content://")
                ) {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialDirectory))
                }
            }
        try {
            startActivityForResult(intent, directoryPickerRequestCode)
        } catch (_: ActivityNotFoundException) {
            pendingDirectoryPickerResult = null
            result.error("picker_unavailable", "System directory picker is unavailable", null)
        }
    }

    private fun ensureDirectoryAccess(path: String): Boolean {
        if (!path.startsWith("content://")) {
            return true
        }

        val uri = Uri.parse(path)
        return contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
    }

    private fun clearDirectoryAccess(path: String?) {
        if (path.isNullOrBlank() || !path.startsWith("content://")) {
            return
        }

        val uri = Uri.parse(path)
        try {
            contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            try {
                contentResolver.releasePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
            }
        }
    }

    private fun saveSelectedDirectory(path: String?) {
        getSharedPreferences(preferencesName, MODE_PRIVATE)
            .edit()
            .putString(selectedDirectoryKey, path)
            .apply()
    }

    private fun loadSelectedDirectory(): String? {
        return getSharedPreferences(preferencesName, MODE_PRIVATE)
            .getString(selectedDirectoryKey, null)
    }

    private fun scanLibrary(rootUri: String): List<Map<String, Any?>> {
        val uri = Uri.parse(rootUri)
        val root =
            DocumentFile.fromTreeUri(this, uri)
                ?: throw IllegalStateException("无法打开选中的 Android 目录。")

        val items = mutableListOf<Map<String, Any?>>()
        scanDirectoryRecursive(root, items)
        return items.sortedWith(
            compareBy<Map<String, Any?>>(
                { (it["title"] as? String).orEmpty() },
                { (it["artist"] as? String).orEmpty() },
            ),
        )
    }

    private fun scanDirectoryRecursive(
        directory: DocumentFile,
        items: MutableList<Map<String, Any?>>,
    ) {
        val files =
            try {
                directory.listFiles()
            } catch (_: SecurityException) {
                return
            } catch (_: Exception) {
                return
            }

        for (file in files) {
            if (file.isDirectory) {
                scanDirectoryRecursive(file, items)
                continue
            }

            if (!file.isFile) {
                continue
            }

            val fileName = file.name ?: continue
            val extension = extractExtension(fileName)
            if (!supportedExtensions.contains(extension)) {
                continue
            }

            val parsedName = parseFileName(fileName)
            items.add(
                mapOf(
                    "title" to parsedName.first,
                    "artist" to parsedName.second,
                    "filePath" to file.uri.toString(),
                    "fileName" to fileName,
                    "extension" to extension,
                ),
            )
        }
    }

    private fun extractExtension(fileName: String): String {
        val dotIndex = fileName.lastIndexOf('.')
        if (dotIndex == -1 || dotIndex == fileName.length - 1) {
            return ""
        }
        return fileName.substring(dotIndex + 1).lowercase()
    }

    private fun parseFileName(fileName: String): Pair<String, String> {
        val dotIndex = fileName.lastIndexOf('.')
        val baseName =
            if (dotIndex == -1) {
                fileName
            } else {
                fileName.substring(0, dotIndex)
            }

        val separators = listOf(" - ", " — ", " – ", "_", "-")
        for (separator in separators) {
            val separatorIndex = baseName.indexOf(separator)
            if (separatorIndex <= 0 || separatorIndex >= baseName.length - separator.length) {
                continue
            }

            val artist = baseName.substring(0, separatorIndex).trim()
            val title = baseName.substring(separatorIndex + separator.length).trim()
            if (artist.isNotEmpty() && title.isNotEmpty()) {
                return title to artist
            }
        }

        return baseName.trim() to "未识别歌手"
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
