package com.vtn.todolist.backup

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * A folder the user picks through the Storage Access Framework (Google
 * Drive, a folder on the phone or SD card…) that daily backups are copied
 * to. The permission is persisted, so copies keep working across launches
 * until the user revokes it or deletes the folder.
 */
class BackupFolderChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val prefs = activity.getSharedPreferences("backup_folder", Context.MODE_PRIVATE)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "todolist/backup_folder").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "name" -> background(result) { folderName() }
            "pick" -> pick(result)
            "clear" -> {
                current()?.let(::release)
                prefs.edit().remove(KEY).apply()
                result.success(null)
            }
            "write" -> {
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null) {
                    result.success(false)
                } else {
                    background(result) { write(name, bytes) }
                }
            }
            "prune" -> {
                val prefix = call.argument<String>("prefix") ?: ""
                val keep = call.argument<Int>("keep") ?: Int.MAX_VALUE
                background(result) {
                    prune(prefix, keep)
                    null
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.success(null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.success(null)
        }
    }

    /** Forwarded from MainActivity.onActivityResult; true when it was ours */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                tree,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            result.success(null)
            return true
        }
        // Let go of the folder picked before, if it was another one
        current()?.takeIf { it != tree }?.let(::release)
        prefs.edit().putString(KEY, tree.toString()).apply()
        background(result) { folderName() }
        return true
    }

    private fun current(): Uri? = prefs.getString(KEY, null)?.let(Uri::parse)

    /** Access can be revoked in system settings */
    private fun granted(tree: Uri): Boolean =
        activity.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }

    private fun release(tree: Uri) {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                tree,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // Already gone
        }
    }

    private fun folderDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    /** Null when no folder is set, access is gone, or the folder was deleted */
    private fun folderName(): String? {
        val tree = current() ?: return null
        if (!granted(tree)) return null
        return try {
            activity.contentResolver.query(
                folderDocument(tree),
                arrayOf(Document.COLUMN_DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        } catch (e: Exception) {
            null
        }
    }

    private fun write(name: String, bytes: ByteArray): Boolean {
        val tree = current() ?: return false
        if (!granted(tree)) return false
        val resolver = activity.contentResolver
        return try {
            // Same name again (a second backup today): overwrite, don't add "(1)"
            val target = children(tree).firstOrNull { it.second == name }?.first
                ?: DocumentsContract.createDocument(
                    resolver,
                    folderDocument(tree),
                    // Keeps the .todobackup name as it is
                    "application/octet-stream",
                    name,
                )
                ?: return false
            val stream = try {
                resolver.openOutputStream(target, "wt")
            } catch (e: Exception) {
                // Some providers don't know "wt"
                resolver.openOutputStream(target, "w")
            }
            stream?.use { it.write(bytes) } ?: return false
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun prune(prefix: String, keep: Int) {
        val tree = current() ?: return
        if (!granted(tree)) return
        children(tree)
            .filter { it.second.startsWith(prefix) }
            .sortedByDescending { it.second }
            .drop(keep)
            .forEach { (uri, _) ->
                try {
                    DocumentsContract.deleteDocument(activity.contentResolver, uri)
                } catch (e: Exception) {
                    // Leave it
                }
            }
    }

    /** (document uri, display name) of each file in the folder */
    private fun children(tree: Uri): List<Pair<Uri, String>> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val found = mutableListOf<Pair<Uri, String>>()
        activity.contentResolver.query(
            childrenUri,
            arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: continue
                found += DocumentsContract.buildDocumentUriUsingTree(tree, id) to name
            }
        }
        return found
    }

    /** Storage providers may hit the network: keep them off the main thread */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try {
                work()
            } catch (e: Exception) {
                null
            }
            main.post { result.success(value) }
        }
    }

    companion object {
        private const val KEY = "tree_uri"
        private const val REQUEST_CODE = 0x7B4C
    }
}
