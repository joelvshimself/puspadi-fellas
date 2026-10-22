package app.rollspot.shared.drafts

import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertNull

class FileDraftStorageTest {
    @Test
    fun writesReadsAndDeletesFolders() {
        val dir = Files.createTempDirectory("drafts").toFile()
        val storage = FileDraftStorage(dir.path)
        storage.write("contributions/u1/p1/flow.json", "{}".encodeToByteArray())
        storage.write("contributions/u1/p1/a.jpg", byteArrayOf(9, 8))
        assertContentEquals(byteArrayOf(9, 8), storage.read("contributions/u1/p1/a.jpg"))
        storage.write("contributions/u1/p1/a.jpg", null)
        assertNull(storage.read("contributions/u1/p1/a.jpg"))
        storage.deleteFolder("contributions/u1/p1")
        assertNull(storage.read("contributions/u1/p1/flow.json"))
        dir.deleteRecursively()
    }
}
