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
        searchQuery: String,
        pageIndex: Int,
        pageSize: Int,
    ): Map<String, Any?> {
        val normalizedPageIndex = pageIndex.coerceAtLeast(0)
        val normalizedPageSize = pageSize.coerceAtLeast(1)
        val normalizedLanguage = language.trim()
        val normalizedSearchQuery = normalizeSearchText(searchQuery)
        val selection = StringBuilder("${SongIndexDatabaseHelper.columnDirectoryUri} = ?")
        val selectionArgs = mutableListOf(rootUri)
        if (normalizedLanguage.isNotEmpty()) {
            selection.append(" AND ${SongIndexDatabaseHelper.columnLanguage} = ?")
            selectionArgs += normalizedLanguage
        }
        if (normalizedSearchQuery.isNotEmpty()) {
            selection.append(
                """
                AND (
                    ${SongIndexDatabaseHelper.columnTitleNorm} LIKE ?
                    OR ${SongIndexDatabaseHelper.columnArtistNorm} LIKE ?
                    OR ${SongIndexDatabaseHelper.columnTitleInitials} LIKE ?
                    OR ${SongIndexDatabaseHelper.columnArtistInitials} LIKE ?
                )
                """.trimIndent(),
            )
            val prefixQuery = "$normalizedSearchQuery%"
            selectionArgs += prefixQuery
            selectionArgs += prefixQuery
            selectionArgs += prefixQuery
            selectionArgs += prefixQuery
        }

        val database = songIndexDatabase.readableDatabase
        val totalCount =
            DatabaseUtils.longForQuery(
                database,
                "SELECT COUNT(1) FROM ${SongIndexDatabaseHelper.songsTable} WHERE $selection",
                selectionArgs.toTypedArray(),
            ).toInt()
        val offset = normalizedPageIndex * normalizedPageSize
        val songs = mutableListOf<Map<String, Any?>>()

        database
            .query(
                SongIndexDatabaseHelper.songsTable,
                arrayOf(
                    SongIndexDatabaseHelper.columnTitle,
                    SongIndexDatabaseHelper.columnArtist,
                    SongIndexDatabaseHelper.columnLanguage,
                    SongIndexDatabaseHelper.columnMediaPath,
                    SongIndexDatabaseHelper.columnSearchIndex,
                ),
                selection.toString(),
                selectionArgs.toTypedArray(),
                null,
                null,
                "${SongIndexDatabaseHelper.columnTitleNorm} ASC, ${SongIndexDatabaseHelper.columnArtistNorm} ASC",
                "$offset, $normalizedPageSize",
            ).use { cursor ->
                val titleIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnTitle)
                val artistIndex = cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnArtist)
                val languageIndex =
                    cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnLanguage)
                val mediaPathIndex =
                    cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnMediaPath)
                val searchIndexIndex =
                    cursor.getColumnIndexOrThrow(SongIndexDatabaseHelper.columnSearchIndex)
                while (cursor.moveToNext()) {
                    songs +=
                        mapOf(
                            "title" to cursor.getString(titleIndex),
                            "artist" to cursor.getString(artistIndex),
                            "language" to cursor.getString(languageIndex),
                            "mediaPath" to cursor.getString(mediaPathIndex),
                            "searchIndex" to cursor.getString(searchIndexIndex),
                        )
                }
            }

        return mapOf(
            "songs" to songs,
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
                    "title" to parsedName.first,
                    "artist" to parsedName.second,
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
            val title = parsedName.first
            val artist = parsedName.second
            val titleNorm = normalizeSearchText(title)
            val artistNorm = normalizeSearchText(artist)
            val titleLatin = buildLatinSearchText(title)
            val artistLatin = buildLatinSearchText(artist)
            val titleInitials = buildInitials(titleLatin)
            val artistInitials = buildInitials(artistLatin)
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
                ).filter { it.isNotBlank() }
                    .joinToString(" ")

            val values =
                ContentValues().apply {
                    put(SongIndexDatabaseHelper.columnDirectoryUri, rootUri)
                    put(SongIndexDatabaseHelper.columnMediaPath, file.uri.toString())
                    put(SongIndexDatabaseHelper.columnFileName, fileName)
                    put(SongIndexDatabaseHelper.columnTitle, title)
                    put(SongIndexDatabaseHelper.columnArtist, artist)
                    put(SongIndexDatabaseHelper.columnLanguage, "其它")
                    put(SongIndexDatabaseHelper.columnSearchIndex, searchIndex)
                    put(SongIndexDatabaseHelper.columnTitleNorm, titleNorm)
                    put(SongIndexDatabaseHelper.columnArtistNorm, artistNorm)
                    put(SongIndexDatabaseHelper.columnTitleInitials, titleInitials)
                    put(SongIndexDatabaseHelper.columnArtistInitials, artistInitials)
                    put(SongIndexDatabaseHelper.columnIndexedAt, indexedAt)
                }
            database.insertWithOnConflict(
                SongIndexDatabaseHelper.songsTable,
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE,
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

    private fun normalizeSearchText(text: String): String {
        return text.trim().lowercase()
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
}

private class SongIndexDatabaseHelper(
    context: Activity,
) : SQLiteOpenHelper(context, databaseName, null, databaseVersion) {
    companion object {
        const val databaseName = "ktv_song_index.db"
        const val databaseVersion = 2
        const val songsTable = "songs"
        const val columnId = "_id"
        const val columnDirectoryUri = "directory_uri"
        const val columnMediaPath = "media_path"
        const val columnFileName = "file_name"
        const val columnTitle = "title"
        const val columnArtist = "artist"
        const val columnLanguage = "language"
        const val columnSearchIndex = "search_index"
        const val columnTitleNorm = "title_norm"
        const val columnArtistNorm = "artist_norm"
        const val columnTitleInitials = "title_initials"
        const val columnArtistInitials = "artist_initials"
        const val columnIndexedAt = "indexed_at"
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
                $columnArtist TEXT NOT NULL,
                $columnLanguage TEXT NOT NULL,
                $columnSearchIndex TEXT NOT NULL,
                $columnTitleNorm TEXT NOT NULL,
                $columnArtistNorm TEXT NOT NULL,
                $columnTitleInitials TEXT NOT NULL,
                $columnArtistInitials TEXT NOT NULL,
                $columnIndexedAt INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX songs_directory_sort_idx ON $songsTable($columnDirectoryUri, $columnTitleNorm, $columnArtistNorm)",
        )
        db.execSQL(
            "CREATE INDEX songs_directory_language_idx ON $songsTable($columnDirectoryUri, $columnLanguage)",
        )
        db.execSQL(
            "CREATE INDEX songs_directory_title_initials_idx ON $songsTable($columnDirectoryUri, $columnTitleInitials)",
        )
        db.execSQL(
            "CREATE INDEX songs_directory_artist_initials_idx ON $songsTable($columnDirectoryUri, $columnArtistInitials)",
        )
    }

    override fun onUpgrade(
        db: SQLiteDatabase,
        oldVersion: Int,
        newVersion: Int,
    ) {
        db.execSQL("DROP TABLE IF EXISTS $songsTable")
        onCreate(db)
    }
}
