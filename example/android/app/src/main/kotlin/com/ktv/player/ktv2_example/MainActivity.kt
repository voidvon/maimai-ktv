package com.ktv.player.ktv2_example

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.ActivityInfo
import android.database.DatabaseUtils
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.icu.text.Transliterator
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
import java.text.Normalizer

private const val unrecognizedArtistValue = "未识别歌手"
private const val otherLanguageValue = "其它"

private val languageKeywordMappings =
    mapOf(
        "国语" to "国语",
        "國語" to "国语",
        "普通话" to "国语",
        "普通話" to "国语",
        "华语" to "国语",
        "華語" to "国语",
        "粤语" to "粤语",
        "粵語" to "粤语",
        "广东话" to "粤语",
        "廣東話" to "粤语",
        "白话" to "粤语",
        "白話" to "粤语",
        "闽南语" to "闽南语",
        "閩南語" to "闽南语",
        "闽南话" to "闽南语",
        "閩南話" to "闽南语",
        "台语" to "闽南语",
        "台語" to "闽南语",
        "福建话" to "闽南语",
        "福建話" to "闽南语",
        "英语" to "英语",
        "英語" to "英语",
        "英文" to "英语",
        "日语" to "日语",
        "日語" to "日语",
        "日文" to "日语",
        "韩语" to "韩语",
        "韓語" to "韩语",
        "韩文" to "韩语",
        "韓文" to "韩语",
        "客语" to "客语",
        "客語" to "客语",
        "客家话" to "客语",
        "客家話" to "客语",
    ).mapKeys { Normalizer.normalize(it.key.trim(), Normalizer.Form.NFKC).lowercase() }

private val tagKeywordMappings =
    mapOf(
        "流行" to "流行",
        "流行音乐" to "流行",
        "流行音樂" to "流行",
        "流行歌曲" to "流行",
        "经典" to "经典",
        "經典" to "经典",
        "经典老歌" to "经典",
        "經典老歌" to "经典",
        "怀旧" to "经典",
        "懷舊" to "经典",
        "摇滚" to "摇滚",
        "搖滾" to "摇滚",
        "摇滚乐" to "摇滚",
        "搖滾樂" to "摇滚",
        "民谣" to "民谣",
        "民謠" to "民谣",
        "校园民谣" to "民谣",
        "校園民謠" to "民谣",
        "舞曲" to "舞曲",
        "劲爆" to "舞曲",
        "勁爆" to "舞曲",
        "嗨歌" to "舞曲",
        "dj" to "DJ",
        "电音" to "DJ",
        "電音" to "DJ",
        "情歌" to "情歌",
        "抒情" to "情歌",
        "儿歌" to "儿歌",
        "兒歌" to "儿歌",
        "童谣" to "儿歌",
        "童謠" to "儿歌",
        "戏曲" to "戏曲",
        "戲曲" to "戏曲",
        "黄梅戏" to "戏曲",
        "黃梅戲" to "戏曲",
        "京剧" to "戏曲",
        "京劇" to "戏曲",
        "越剧" to "戏曲",
        "越劇" to "戏曲",
        "对唱" to "对唱",
        "對唱" to "对唱",
        "合唱" to "合唱",
        "现场版" to "现场版",
        "現場版" to "现场版",
        "live" to "Live",
        "演唱会" to "演唱会",
        "演唱會" to "演唱会",
        "mv" to "MV",
        "伴奏版" to "伴奏版",
        "原版" to "原版",
        "重制版" to "重制版",
        "重製版" to "重制版",
    ).mapKeys { Normalizer.normalize(it.key.trim(), Normalizer.Form.NFKC).lowercase() }

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
                "3g2",
                "3gp",
                "asf",
                "avi",
                "dat",
                "divx",
                "dv",
                "f4v",
                "flv",
                "m1v",
                "m2t",
                "m2ts",
                "m2v",
                "m4v",
                "mkv",
                "mov",
                "mp4",
                "mpe",
                "mpeg",
                "mpg",
                "mts",
                "mxf",
                "ogm",
                "ogv",
                "qt",
                "rm",
                "rmvb",
                "tod",
                "tp",
                "trp",
                "ts",
                "vob",
                "webm",
                "wmv",
            )
    }

    private var pendingVideoPickerResult: MethodChannel.Result? = null
    private var pendingDirectoryPickerResult: MethodChannel.Result? = null
    private val songIndexDatabase by lazy { SongIndexDatabaseHelper(this) }
    private val hanLatinTransliterator: Transliterator? by lazy {
        runCatching { Transliterator.getInstance("Han-Latin; Latin-ASCII") }.getOrNull()
    }
    private val artistHyphenWhitelist: Set<String> by lazy { loadArtistHyphenWhitelist() }

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
                "scanLibraryIntoIndex" -> {
                    val rootUri = call.argument<String>("rootUri")
                    if (rootUri.isNullOrBlank()) {
                        result.error("invalid_args", "Missing rootUri", null)
                    } else {
                        try {
                            result.success(scanLibraryIntoIndex(rootUri))
                        } catch (error: Exception) {
                            result.error(
                                "scan_failed",
                                error.message ?: "Failed to index library",
                                null,
                            )
                        }
                    }
                }
                "queryIndexedSongs" -> {
                    val rootUri = call.argument<String>("rootUri")
                    if (rootUri.isNullOrBlank()) {
                        result.error("invalid_args", "Missing rootUri", null)
                    } else {
                        try {
                            result.success(
                                queryIndexedSongs(
                                    rootUri = rootUri,
                                    language = call.argument<String>("language").orEmpty(),
                                    artist = call.argument<String>("artist").orEmpty(),
                                    searchQuery = call.argument<String>("searchQuery").orEmpty(),
                                    pageIndex = call.argument<Int>("pageIndex") ?: 0,
                                    pageSize = call.argument<Int>("pageSize") ?: 8,
                                ),
                            )
                        } catch (error: Exception) {
                            result.error(
                                "query_failed",
                                error.message ?: "Failed to query indexed songs",
                                null,
                            )
                        }
                    }
                }
                "queryIndexedArtists" -> {
                    val rootUri = call.argument<String>("rootUri")
                    if (rootUri.isNullOrBlank()) {
                        result.error("invalid_args", "Missing rootUri", null)
                    } else {
                        try {
                            result.success(
                                queryIndexedArtists(
                                    rootUri = rootUri,
                                    language = call.argument<String>("language").orEmpty(),
                                    searchQuery = call.argument<String>("searchQuery").orEmpty(),
                                    pageIndex = call.argument<Int>("pageIndex") ?: 0,
                                    pageSize = call.argument<Int>("pageSize") ?: 8,
                                ),
                            )
                        } catch (error: Exception) {
                            result.error(
                                "query_failed",
                                error.message ?: "Failed to query indexed artists",
                                null,
                            )
                        }
                    }
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

    private fun scanLibraryIntoIndex(rootUri: String): Int {
        val uri = Uri.parse(rootUri)
        val root =
            DocumentFile.fromTreeUri(this, uri)
                ?: throw IllegalStateException("无法打开选中的 Android 目录。")
        val indexedAt = System.currentTimeMillis()
        val database = songIndexDatabase.writableDatabase
        var indexedCount = 0

        database.beginTransaction()
        try {
            database.delete(
                SongIndexDatabaseHelper.songsTable,
                "${SongIndexDatabaseHelper.columnDirectoryUri} = ?",
                arrayOf(rootUri),
            )
            indexDirectoryRecursive(
                directory = root,
                rootUri = rootUri,
                indexedAt = indexedAt,
                database = database,
            ) { indexedCount += 1 }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }

        return indexedCount
    }

    private fun queryIndexedSongs(
        rootUri: String,
        language: String,
        artist: String,
        searchQuery: String,
        pageIndex: Int,
        pageSize: Int,
    ): Map<String, Any?> {
        val normalizedPageIndex = pageIndex.coerceAtLeast(0)
        val normalizedPageSize = pageSize.coerceAtLeast(1)
        val normalizedLanguage = language.trim()
        val normalizedArtist = artist.trim()
        val normalizedSearchQuery = normalizeSearchText(searchQuery)
        val selection = StringBuilder("s.${SongIndexDatabaseHelper.columnDirectoryUri} = ?")
        val selectionArgs = mutableListOf(rootUri)
        if (normalizedLanguage.isNotEmpty()) {
            selection.append(
                """
                AND EXISTS (
                    SELECT 1
                    FROM ${SongIndexDatabaseHelper.songLanguagesTable} sl_filter
                    WHERE sl_filter.${SongIndexDatabaseHelper.columnSongId} = s.${SongIndexDatabaseHelper.columnId}
                      AND sl_filter.${SongIndexDatabaseHelper.columnLanguage} = ?
                )
                """.trimIndent(),
            )
            selectionArgs += normalizedLanguage
        }
        if (normalizedArtist.isNotEmpty()) {
            selection.append(
                """
                AND EXISTS (
                    SELECT 1
                    FROM ${SongIndexDatabaseHelper.songArtistsTable} sa_filter
                    WHERE sa_filter.${SongIndexDatabaseHelper.columnSongId} = s.${SongIndexDatabaseHelper.columnId}
                      AND sa_filter.${SongIndexDatabaseHelper.columnArtistName} = ?
                )
                """.trimIndent(),
            )
            selectionArgs += normalizedArtist
        }
        if (normalizedSearchQuery.isNotEmpty()) {
            selection.append(
                """
                AND (
                    s.${SongIndexDatabaseHelper.columnTitleNorm} LIKE ?
                    OR s.${SongIndexDatabaseHelper.columnTitleInitials} LIKE ?
                    OR s.${SongIndexDatabaseHelper.columnArtistInitials} LIKE ?
                    OR EXISTS (
                        SELECT 1
                        FROM ${SongIndexDatabaseHelper.songArtistsTable} sa
                        WHERE sa.${SongIndexDatabaseHelper.columnSongId} = s.${SongIndexDatabaseHelper.columnId}
                          AND sa.${SongIndexDatabaseHelper.columnArtistName} LIKE ?
                    )
                    OR s.${SongIndexDatabaseHelper.columnSearchIndex} LIKE ?
                )
                """.trimIndent(),
            )
            val prefixQuery = "$normalizedSearchQuery%"
            val containsQuery = "%$normalizedSearchQuery%"
            selectionArgs += prefixQuery
            selectionArgs += prefixQuery
            selectionArgs += prefixQuery
            selectionArgs += prefixQuery
            selectionArgs += containsQuery
        }

        val database = songIndexDatabase.readableDatabase
        val totalCount =
            DatabaseUtils.longForQuery(
                database,
                "SELECT COUNT(1) FROM ${SongIndexDatabaseHelper.songsTable} s WHERE $selection",
                selectionArgs.toTypedArray(),
            ).toInt()
        val offset = normalizedPageIndex * normalizedPageSize
        val songs = mutableListOf<Map<String, Any?>>()
        val songIds = mutableListOf<Long>()
        val languageMap = linkedMapOf<Long, MutableList<String>>()
        val tagMap = linkedMapOf<Long, MutableList<String>>()

        database.rawQuery(
            """
            SELECT
                s.${SongIndexDatabaseHelper.columnId},
                s.${SongIndexDatabaseHelper.columnTitle},
                s.${SongIndexDatabaseHelper.columnArtistDisplayName},
                s.${SongIndexDatabaseHelper.columnMediaPath},
                s.${SongIndexDatabaseHelper.columnSearchIndex}
            FROM ${SongIndexDatabaseHelper.songsTable} s
            WHERE $selection
            ORDER BY
                s.${SongIndexDatabaseHelper.columnTitleNorm} ASC,
                s.${SongIndexDatabaseHelper.columnArtistDisplayName} ASC
            LIMIT ? OFFSET ?
            """.trimIndent(),
            (selectionArgs + normalizedPageSize.toString() + offset.toString()).toTypedArray(),
        ).use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnId)
            val titleIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnTitle)
            val artistIndex =
                cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnArtistDisplayName)
            val mediaPathIndex =
                cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnMediaPath)
            val searchIndexIndex =
                cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnSearchIndex)
            while (cursor.moveToNext()) {
                val songId = cursor.getLong(idIndex)
                songIds += songId
                songs +=
                    linkedMapOf(
                        "songId" to songId,
                        "title" to cursor.getString(titleIndex),
                        "artist" to cursor.getString(artistIndex),
                        "mediaPath" to cursor.getString(mediaPathIndex),
                        "searchIndex" to cursor.getString(searchIndexIndex),
                    )
            }
        }

        if (songIds.isNotEmpty()) {
            val placeholders = List(songIds.size) { "?" }.joinToString(", ")
            database.rawQuery(
                """
                SELECT
                    ${SongIndexDatabaseHelper.columnSongId},
                    ${SongIndexDatabaseHelper.columnLanguage}
                FROM ${SongIndexDatabaseHelper.songLanguagesTable}
                WHERE ${SongIndexDatabaseHelper.columnSongId} IN ($placeholders)
                ORDER BY rowid ASC
                """.trimIndent(),
                songIds.map(Long::toString).toTypedArray(),
            ).use { cursor ->
                val songIdIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnSongId)
                val languageIndex =
                    cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnLanguage)
                while (cursor.moveToNext()) {
                    val songId = cursor.getLong(songIdIndex)
                    val value = cursor.getString(languageIndex)
                    val languages = languageMap.getOrPut(songId) { mutableListOf() }
                    if (!languages.contains(value)) {
                        languages += value
                    }
                }
            }
            database.rawQuery(
                """
                SELECT
                    ${SongIndexDatabaseHelper.columnSongId},
                    ${SongIndexDatabaseHelper.columnTag}
                FROM ${SongIndexDatabaseHelper.songTagsTable}
                WHERE ${SongIndexDatabaseHelper.columnSongId} IN ($placeholders)
                ORDER BY rowid ASC
                """.trimIndent(),
                songIds.map(Long::toString).toTypedArray(),
            ).use { cursor ->
                val songIdIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnSongId)
                val tagIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnTag)
                while (cursor.moveToNext()) {
                    val songId = cursor.getLong(songIdIndex)
                    val value = cursor.getString(tagIndex)
                    val tags = tagMap.getOrPut(songId) { mutableListOf() }
                    if (!tags.contains(value)) {
                        tags += value
                    }
                }
            }
        }

        val normalizedSongs =
            songs.map { song ->
                val songId = song["songId"] as Long
                val languages = languageMap[songId].orEmpty()
                val tags = tagMap[songId].orEmpty()
                mapOf(
                    "title" to song.getValue("title"),
                    "artist" to song.getValue("artist"),
                    "language" to languages.joinToString("/").ifBlank { otherLanguageValue },
                    "languages" to languages,
                    "tags" to tags,
                    "mediaPath" to song.getValue("mediaPath"),
                    "searchIndex" to song.getValue("searchIndex"),
                )
            }

        return mapOf(
            "songs" to normalizedSongs,
            "totalCount" to totalCount,
            "pageIndex" to normalizedPageIndex,
            "pageSize" to normalizedPageSize,
        )
    }

    private fun queryIndexedArtists(
        rootUri: String,
        language: String,
        searchQuery: String,
        pageIndex: Int,
        pageSize: Int,
    ): Map<String, Any?> {
        val normalizedPageIndex = pageIndex.coerceAtLeast(0)
        val normalizedPageSize = pageSize.coerceAtLeast(1)
        val normalizedLanguage = language.trim()
        val normalizedSearchQuery = normalizeSearchText(searchQuery)
        val selection = StringBuilder("s.${SongIndexDatabaseHelper.columnDirectoryUri} = ?")
        val selectionArgs = mutableListOf(rootUri)
        if (normalizedLanguage.isNotEmpty()) {
            selection.append(
                """
                AND EXISTS (
                    SELECT 1
                    FROM ${SongIndexDatabaseHelper.songLanguagesTable} sl_filter
                    WHERE sl_filter.${SongIndexDatabaseHelper.columnSongId} = s.${SongIndexDatabaseHelper.columnId}
                      AND sl_filter.${SongIndexDatabaseHelper.columnLanguage} = ?
                )
                """.trimIndent(),
            )
            selectionArgs += normalizedLanguage
        }
        if (normalizedSearchQuery.isNotEmpty()) {
            selection.append(
                """
                AND (
                    LOWER(sa.${SongIndexDatabaseHelper.columnArtistName}) LIKE ?
                    OR EXISTS (
                        SELECT 1
                        FROM ${SongIndexDatabaseHelper.songArtistsTable} sa_match
                        INNER JOIN ${SongIndexDatabaseHelper.songsTable} s_match
                            ON s_match.${SongIndexDatabaseHelper.columnId} = sa_match.${SongIndexDatabaseHelper.columnSongId}
                        WHERE sa_match.${SongIndexDatabaseHelper.columnArtistName} = sa.${SongIndexDatabaseHelper.columnArtistName}
                          AND s_match.${SongIndexDatabaseHelper.columnDirectoryUri} = s.${SongIndexDatabaseHelper.columnDirectoryUri}
                          AND s_match.${SongIndexDatabaseHelper.columnArtistInitials} LIKE ?
                    )
                )
                """.trimIndent(),
            )
            val containsQuery = "%$normalizedSearchQuery%"
            val prefixQuery = "$normalizedSearchQuery%"
            selectionArgs += containsQuery
            selectionArgs += prefixQuery
        }

        val database = songIndexDatabase.readableDatabase
        val totalCount =
            DatabaseUtils.longForQuery(
                database,
                """
                SELECT COUNT(1)
                FROM (
                    SELECT sa.${SongIndexDatabaseHelper.columnArtistName}
                    FROM ${SongIndexDatabaseHelper.songArtistsTable} sa
                    INNER JOIN ${SongIndexDatabaseHelper.songsTable} s
                        ON s.${SongIndexDatabaseHelper.columnId} = sa.${SongIndexDatabaseHelper.columnSongId}
                    WHERE $selection
                    GROUP BY sa.${SongIndexDatabaseHelper.columnArtistName}
                )
                """.trimIndent(),
                selectionArgs.toTypedArray(),
            ).toInt()
        val offset = normalizedPageIndex * normalizedPageSize
        val artists = mutableListOf<Map<String, Any?>>()
        database.rawQuery(
            """
            SELECT
                sa.${SongIndexDatabaseHelper.columnArtistName},
                COUNT(DISTINCT s.${SongIndexDatabaseHelper.columnId}) AS song_count
            FROM ${SongIndexDatabaseHelper.songArtistsTable} sa
            INNER JOIN ${SongIndexDatabaseHelper.songsTable} s
                ON s.${SongIndexDatabaseHelper.columnId} = sa.${SongIndexDatabaseHelper.columnSongId}
            WHERE $selection
            GROUP BY sa.${SongIndexDatabaseHelper.columnArtistName}
            ORDER BY sa.${SongIndexDatabaseHelper.columnArtistName} ASC
            LIMIT ? OFFSET ?
            """.trimIndent(),
            (selectionArgs + normalizedPageSize.toString() + offset.toString()).toTypedArray(),
        ).use { cursor ->
            val nameIndex =
                cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnArtistName)
            val songCountIndex = cursor.getColumnIndexOrThrow("song_count")
            while (cursor.moveToNext()) {
                val artistName = cursor.getString(nameIndex)
                artists +=
                    mapOf(
                        "name" to artistName,
                        "songCount" to cursor.getInt(songCountIndex),
                        "searchIndex" to normalizeSearchText(artistName),
                    )
            }
        }

        return mapOf(
            "artists" to artists,
            "totalCount" to totalCount,
            "pageIndex" to normalizedPageIndex,
            "pageSize" to normalizedPageSize,
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
                    "title" to parsedName.title,
                    "artist" to parsedName.artistDisplayName,
                    "filePath" to file.uri.toString(),
                    "fileName" to fileName,
                    "extension" to extension,
                ),
            )
        }
    }

    private fun indexDirectoryRecursive(
        directory: DocumentFile,
        rootUri: String,
        indexedAt: Long,
        database: SQLiteDatabase,
        onIndexed: () -> Unit,
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
                indexDirectoryRecursive(
                    directory = file,
                    rootUri = rootUri,
                    indexedAt = indexedAt,
                    database = database,
                    onIndexed = onIndexed,
                )
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
            val title = parsedName.title
            val artistDisplayName = parsedName.artistDisplayName
            val titleNorm = normalizeSearchText(title)
            val artistNorm = normalizeSearchText(artistDisplayName)
            val titleLatin = buildLatinSearchText(title)
            val artistLatin = buildLatinSearchText(artistDisplayName)
            val titleInitials = buildInitials(titleLatin)
            val artistInitials = buildInitials(artistLatin)
            val artistSearchTokens =
                parsedName.artistNames.flatMap { artistName ->
                    val nameNorm = normalizeSearchText(artistName)
                    val nameLatin = buildLatinSearchText(artistName)
                    listOf(
                        nameNorm,
                        nameLatin,
                        buildInitials(nameLatin),
                    )
                }
            val searchIndex =
                listOf(
                    titleNorm,
                    artistNorm,
                    fileName.lowercase(),
                    extension,
                    titleLatin,
                    artistLatin,
                    titleInitials,
                    artistInitials,
                ).plus(parsedName.languages.map(::normalizeSearchText))
                    .plus(parsedName.tags.map(::normalizeSearchText))
                    .plus(artistSearchTokens)
                    .filter { it.isNotBlank() }
                    .joinToString(" ")

            val values =
                ContentValues().apply {
                    put(SongIndexDatabaseHelper.columnDirectoryUri, rootUri)
                    put(SongIndexDatabaseHelper.columnMediaPath, file.uri.toString())
                    put(SongIndexDatabaseHelper.columnFileName, fileName)
                    put(SongIndexDatabaseHelper.columnTitle, title)
                    put(SongIndexDatabaseHelper.columnArtistDisplayName, artistDisplayName)
                    put(SongIndexDatabaseHelper.columnSearchIndex, searchIndex)
                    put(SongIndexDatabaseHelper.columnTitleNorm, titleNorm)
                    put(SongIndexDatabaseHelper.columnTitleInitials, titleInitials)
                    put(SongIndexDatabaseHelper.columnArtistInitials, artistInitials)
                    put(SongIndexDatabaseHelper.columnIndexedAt, indexedAt)
                }
            val songId =
                database.insertWithOnConflict(
                    SongIndexDatabaseHelper.songsTable,
                    null,
                    values,
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            insertSongRelations(
                database = database,
                songId = songId,
                artists = parsedName.artistNames,
                languages = parsedName.languages,
                tags = parsedName.tags,
            )
            onIndexed()
        }
    }

    private fun extractExtension(fileName: String): String {
        val dotIndex = fileName.lastIndexOf('.')
        if (dotIndex == -1 || dotIndex == fileName.length - 1) {
            return ""
        }
        return fileName.substring(dotIndex + 1).lowercase()
    }

    private fun parseFileName(fileName: String): ParsedSongMetadata {
        val baseName = removeExtension(fileName)
        val normalizedBaseName = normalizeFileNameForParsing(baseName)
        val segments = normalizedBaseName.split('-').map { it.trim() }
        if (segments.isEmpty()) {
            return createFallbackMetadata(fileName, baseName)
        }

        for (artistSegmentCount in segments.size downTo 1) {
            val artistCandidate = segments.take(artistSegmentCount).joinToString("-").trim()
            if (artistCandidate.isBlank()) {
                continue
            }
            if (!artistHyphenWhitelist.contains(normalizeArtistWhitelistValue(artistCandidate))) {
                continue
            }
            parseWithArtistSegmentCount(
                segments = segments,
                artistSegmentCount = artistSegmentCount,
            )?.let { return it }
        }

        parseWithArtistSegmentCount(
            segments = segments,
            artistSegmentCount = 1,
        )?.let { return it }

        return createFallbackMetadata(fileName, baseName)
    }

    private fun normalizeSearchText(text: String): String {
        return Normalizer.normalize(text.trim(), Normalizer.Form.NFKC).lowercase()
    }

    private fun buildLatinSearchText(source: String): String {
        val normalizedSource = source.trim()
        if (normalizedSource.isEmpty()) {
            return ""
        }
        val transliterated =
            hanLatinTransliterator?.transliterate(normalizedSource) ?: normalizedSource
        return transliterated
            .lowercase()
            .replace(Regex("[^a-z0-9]+"), " ")
            .trim()
    }

    private fun buildInitials(latinSearchText: String): String {
        if (latinSearchText.isBlank()) {
            return ""
        }
        return latinSearchText
            .split(Regex("\\s+"))
            .filter { it.isNotBlank() }
            .joinToString(separator = "") { it.first().toString() }
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

    private fun insertSongRelations(
        database: SQLiteDatabase,
        songId: Long,
        artists: List<String>,
        languages: List<String>,
        tags: List<String>,
    ) {
        insertRelationValues(
            database = database,
            table = SongIndexDatabaseHelper.songArtistsTable,
            valueColumn = SongIndexDatabaseHelper.columnArtistName,
            songId = songId,
            values = artists,
        )
        insertRelationValues(
            database = database,
            table = SongIndexDatabaseHelper.songLanguagesTable,
            valueColumn = SongIndexDatabaseHelper.columnLanguage,
            songId = songId,
            values = languages,
        )
        insertRelationValues(
            database = database,
            table = SongIndexDatabaseHelper.songTagsTable,
            valueColumn = SongIndexDatabaseHelper.columnTag,
            songId = songId,
            values = tags,
        )
    }

    private fun insertRelationValues(
        database: SQLiteDatabase,
        table: String,
        valueColumn: String,
        songId: Long,
        values: List<String>,
    ) {
        values.forEach { value ->
            database.insertWithOnConflict(
                table,
                null,
                ContentValues().apply {
                    put(SongIndexDatabaseHelper.columnSongId, songId)
                    put(valueColumn, value)
                },
                SQLiteDatabase.CONFLICT_IGNORE,
            )
        }
    }

    private fun parseWithArtistSegmentCount(
        segments: List<String>,
        artistSegmentCount: Int,
    ): ParsedSongMetadata? {
        if (artistSegmentCount <= 0 || artistSegmentCount > segments.size) {
            return null
        }

        val artistDisplayName = segments.take(artistSegmentCount).joinToString("-").trim()
        val artistNames =
            artistDisplayName.split('&')
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        if (artistDisplayName.isBlank() || artistNames.isEmpty()) {
            return null
        }

        var rightIndex = segments.lastIndex
        val languagesReversed = mutableListOf<String>()
        val tagsReversed = mutableListOf<String>()
        while (rightIndex >= artistSegmentCount) {
            val segment = segments[rightIndex].trim()
            if (segment.isEmpty()) {
                rightIndex -= 1
                continue
            }

            val cleanedSegment = cleanTrailingNoise(segment)
            if (cleanedSegment.isBlank()) {
                rightIndex -= 1
                continue
            }

            val normalizedKeyword = normalizeKeyword(cleanedSegment)
            val languageMatch = languageKeywordMappings[normalizedKeyword]
            if (languageMatch != null) {
                if (!languagesReversed.contains(languageMatch)) {
                    languagesReversed += languageMatch
                }
                rightIndex -= 1
                continue
            }

            val tagMatch = tagKeywordMappings[normalizedKeyword]
            if (tagMatch != null) {
                if (!tagsReversed.contains(tagMatch)) {
                    tagsReversed += tagMatch
                }
                rightIndex -= 1
                continue
            }
            break
        }

        val titleSegments =
            segments.subList(artistSegmentCount, rightIndex + 1)
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        val title = titleSegments.joinToString("-").trim()
        if (title.isEmpty()) {
            return null
        }

        val languages =
            languagesReversed.asReversed().ifEmpty {
                listOf(otherLanguageValue)
            }
        return ParsedSongMetadata(
            title = title,
            artistDisplayName = artistDisplayName,
            artistNames = artistNames,
            languages = languages,
            tags = tagsReversed.asReversed(),
        )
    }

    private fun createFallbackMetadata(
        fileName: String,
        baseName: String,
    ): ParsedSongMetadata {
        val fallbackTitle =
            baseName.trim().ifBlank {
                fileName.trim().ifBlank { "未知歌曲" }
            }
        return ParsedSongMetadata(
            title = fallbackTitle,
            artistDisplayName = unrecognizedArtistValue,
            artistNames = listOf(unrecognizedArtistValue),
            languages = listOf(otherLanguageValue),
            tags = emptyList(),
        )
    }

    private fun removeExtension(fileName: String): String {
        val dotIndex = fileName.lastIndexOf('.')
        return if (dotIndex == -1) {
            fileName
        } else {
            fileName.substring(0, dotIndex)
        }
    }

    private fun normalizeFileNameForParsing(baseName: String): String {
        return baseName.trim()
            .replace(Regex("\\s*[—–]\\s*"), "-")
            .replace(Regex("\\s+-\\s+"), "-")
    }

    private fun normalizeArtistWhitelistValue(value: String): String {
        return normalizeFileNameForParsing(value).trim().lowercase()
    }

    private fun loadArtistHyphenWhitelist(): Set<String> {
        return runCatching {
            assets.open("sqlite_hyphen_whitelist.yaml").bufferedReader().useLines { lines ->
                val artistNames = linkedSetOf<String>()
                var inArtistNames = false
                lines.forEach { rawLine ->
                    val trimmedLine = rawLine.trim()
                    if (trimmedLine.isEmpty() || trimmedLine.startsWith("#")) {
                        return@forEach
                    }
                    if (!rawLine.startsWith(" ") && trimmedLine.endsWith(":")) {
                        inArtistNames = trimmedLine == "artist_names:"
                        return@forEach
                    }
                    if (inArtistNames && trimmedLine.startsWith("- ")) {
                        val artistName = trimmedLine.removePrefix("- ").trim()
                        if (artistName.isNotEmpty()) {
                            artistNames += normalizeArtistWhitelistValue(artistName)
                        }
                    }
                }
                artistNames
            }
        }.getOrDefault(emptySet())
    }

    private fun cleanTrailingNoise(segment: String): String {
        var cleaned = segment.trim()
        val suffixPatterns =
            listOf(
                Regex("(?i)[ _-]*副本\\s*\\(\\d+\\)$"),
                Regex("(?i)[ _-]*副本$"),
                Regex("(?i)[ _-]*copy\\s*\\(\\d+\\)$"),
                Regex("(?i)[ _-]*copy$"),
                Regex("\\s*\\(\\d+\\)$"),
            )
        while (cleaned.isNotEmpty()) {
            val updated =
                suffixPatterns.fold(cleaned) { current, pattern ->
                    current.replace(pattern, "")
                }.trim()
            if (updated == cleaned) {
                break
            }
            cleaned = updated
        }
        return cleaned
    }

    private fun normalizeKeyword(keyword: String): String {
        return normalizeSearchText(keyword)
            .replace(Regex("\\s+"), " ")
            .trim('-', '_', ' ', '.', '。', ',', '，', '(', ')', '（', '）')
    }
}

private data class ParsedSongMetadata(
    val title: String,
    val artistDisplayName: String,
    val artistNames: List<String>,
    val languages: List<String>,
    val tags: List<String>,
)

private class SongIndexDatabaseHelper(
    context: Activity,
) : SQLiteOpenHelper(context, databaseName, null, databaseVersion) {
    companion object {
        const val databaseName = "ktv_song_index.db"
        const val databaseVersion = 3
        const val songsTable = "songs"
        const val songArtistsTable = "song_artists"
        const val songLanguagesTable = "song_languages"
        const val songTagsTable = "song_tags"
        const val columnId = "_id"
        const val columnSongId = "song_id"
        const val columnDirectoryUri = "directory_uri"
        const val columnMediaPath = "media_path"
        const val columnFileName = "file_name"
        const val columnTitle = "title"
        const val columnArtistDisplayName = "artist_display_name"
        const val columnArtistName = "artist_name"
        const val columnLanguage = "language"
        const val columnTag = "tag"
        const val columnSearchIndex = "search_index"
        const val columnTitleNorm = "title_norm"
        const val columnTitleInitials = "title_initials"
        const val columnArtistInitials = "artist_initials"
        const val columnIndexedAt = "indexed_at"
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $songsTable (
                $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
                $columnDirectoryUri TEXT NOT NULL,
                $columnMediaPath TEXT NOT NULL UNIQUE,
                $columnFileName TEXT NOT NULL,
                $columnTitle TEXT NOT NULL,
                $columnArtistDisplayName TEXT NOT NULL,
                $columnSearchIndex TEXT NOT NULL,
                $columnTitleNorm TEXT NOT NULL,
                $columnTitleInitials TEXT NOT NULL,
                $columnArtistInitials TEXT NOT NULL,
                $columnIndexedAt INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE $songArtistsTable (
                $columnSongId INTEGER NOT NULL,
                $columnArtistName TEXT NOT NULL,
                PRIMARY KEY ($columnSongId, $columnArtistName),
                FOREIGN KEY ($columnSongId) REFERENCES $songsTable($columnId) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE $songLanguagesTable (
                $columnSongId INTEGER NOT NULL,
                $columnLanguage TEXT NOT NULL,
                PRIMARY KEY ($columnSongId, $columnLanguage),
                FOREIGN KEY ($columnSongId) REFERENCES $songsTable($columnId) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE $songTagsTable (
                $columnSongId INTEGER NOT NULL,
                $columnTag TEXT NOT NULL,
                PRIMARY KEY ($columnSongId, $columnTag),
                FOREIGN KEY ($columnSongId) REFERENCES $songsTable($columnId) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX songs_directory_sort_idx ON $songsTable($columnDirectoryUri, $columnTitleNorm, $columnArtistDisplayName)",
        )
        db.execSQL(
            "CREATE INDEX songs_directory_title_initials_idx ON $songsTable($columnDirectoryUri, $columnTitleInitials)",
        )
        db.execSQL(
            "CREATE INDEX songs_directory_artist_initials_idx ON $songsTable($columnDirectoryUri, $columnArtistInitials)",
        )
        db.execSQL(
            "CREATE INDEX idx_song_languages_language_song ON $songLanguagesTable($columnLanguage, $columnSongId)",
        )
        db.execSQL(
            "CREATE INDEX idx_song_tags_tag_song ON $songTagsTable($columnTag, $columnSongId)",
        )
        db.execSQL(
            "CREATE INDEX idx_song_artists_artist_song ON $songArtistsTable($columnArtistName, $columnSongId)",
        )
    }

    override fun onUpgrade(
        db: SQLiteDatabase,
        oldVersion: Int,
        newVersion: Int,
    ) {
        db.execSQL("DROP TABLE IF EXISTS $songTagsTable")
        db.execSQL("DROP TABLE IF EXISTS $songLanguagesTable")
        db.execSQL("DROP TABLE IF EXISTS $songArtistsTable")
        db.execSQL("DROP TABLE IF EXISTS $songsTable")
        onCreate(db)
    }
}
