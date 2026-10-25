package app.rollspot.shared.drafts

import java.io.File

actual class FileDraftStorage actual constructor(directory: String) : DraftStorage {
    private val root = File(directory)

    override fun read(name: String): ByteArray? = runCatching { File(root, name).takeIf { it.isFile }?.readBytes() }.getOrNull()

    override fun write(name: String, bytes: ByteArray?) {
        val file = File(root, name)
        if (bytes == null) {
            file.delete()
            return
        }
        file.parentFile?.mkdirs()
        // Write then rename, so a crash mid-write never leaves half a draft.
        val temp = File(file.parentFile, "${file.name}.tmp")
        temp.writeBytes(bytes)
        if (!temp.renameTo(file)) {
            file.delete()
            temp.renameTo(file)
        }
    }

    override fun deleteFolder(name: String) {
        File(root, name).deleteRecursively()
    }
}
