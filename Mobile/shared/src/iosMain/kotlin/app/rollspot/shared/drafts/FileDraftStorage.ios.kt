package app.rollspot.shared.drafts

import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSData
import platform.Foundation.NSFileManager
import platform.Foundation.NSString
import platform.Foundation.create
import platform.Foundation.dataWithContentsOfFile
import platform.Foundation.stringByDeletingLastPathComponent
import platform.Foundation.writeToFile
import platform.posix.memcpy

@OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)
actual class FileDraftStorage actual constructor(directory: String) : DraftStorage {
    private val root = directory.trimEnd('/')
    private val files = NSFileManager.defaultManager

    private fun path(name: String) = "$root/$name"

    override fun read(name: String): ByteArray? {
        val data = NSData.dataWithContentsOfFile(path(name)) ?: return null
        val size = data.length.toInt()
        if (size == 0) return ByteArray(0)
        return ByteArray(size).apply { usePinned { memcpy(it.addressOf(0), data.bytes, data.length) } }
    }

    override fun write(name: String, bytes: ByteArray?) {
        val target = path(name)
        if (bytes == null) {
            files.removeItemAtPath(target, null)
            return
        }
        @Suppress("CAST_NEVER_SUCCEEDS")
        val folder = (target as NSString).stringByDeletingLastPathComponent
        files.createDirectoryAtPath(folder, withIntermediateDirectories = true, attributes = null, error = null)
        val data = bytes.usePinned { NSData.create(bytes = it.addressOf(0), length = bytes.size.toULong()) }
        // Atomic: written to a temporary file, then moved into place.
        data.writeToFile(target, atomically = true)
    }

    override fun deleteFolder(name: String) {
        files.removeItemAtPath(path(name.trimEnd('/')), null)
    }
}
