package app.rollspot.shared.drafts

/**
 * Where unfinished contributions live on the device: small named blobs (JSON, JPEGs).
 * Names may contain `/` for folders. Writing null deletes.
 */
interface DraftStorage {
    fun read(name: String): ByteArray?
    fun write(name: String, bytes: ByteArray?)
    /** Deletes the folder [name] and everything in it. */
    fun deleteFolder(name: String)
}

/** Files under [directory]: the app's files dir on Android, Application Support on iOS. */
expect class FileDraftStorage(directory: String) : DraftStorage

/** For tests and previews: forgets everything when the process ends. */
class InMemoryDraftStorage : DraftStorage {
    private val blobs = mutableMapOf<String, ByteArray>()
    override fun read(name: String): ByteArray? = blobs[name]
    override fun write(name: String, bytes: ByteArray?) {
        if (bytes == null) blobs.remove(name) else blobs[name] = bytes
    }
    override fun deleteFolder(name: String) {
        blobs.keys.filter { it.startsWith("${name.trimEnd('/')}/") }.forEach(blobs::remove)
    }
}
