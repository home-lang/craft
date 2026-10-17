package {{PACKAGE_NAME}}

import java.io.File
import java.io.IOException
import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CraftNativeImageCacheTest {
    private val publicHeaders = mapOf("Cache-Control" to listOf("public, max-age=3600, immutable"))

    private fun fixture(check: (File) -> Unit) {
        val root = Files.createTempDirectory("craft-image-cache-test-").toFile()
        try { check(root) }
        finally { root.deleteRecursively() }
    }

    private fun put(cache: CraftNativeImageCache, address: String, value: String, expiresAt: Long = 10_000): Boolean =
        cache.write(address, CraftNativeImagePolicy(expiresAt)) { output -> output.write(value.toByteArray()); true }

    @Test
    fun survivesAColdCacheInstanceWithoutStoringAddresses() = fixture { root ->
        val address = "https://example.test/avatar?capability=never-store-this-address"
        assertTrue(put(CraftNativeImageCache(root, now = { 1000 }), address, "image"))
        val restored = CraftNativeImageCache(root, now = { 2000 }).read(address)
        assertNotNull(restored)
        assertEquals("image", String(restored!!, Charsets.UTF_8))
        assertTrue(root.listFiles().orEmpty().none { it.name.contains("capability") || it.readText().contains(address) })
    }

    @Test
    fun expiresAtTheServersFreshnessBoundary() = fixture { root ->
        var clock = 1000L
        val cache = CraftNativeImageCache(root, now = { clock })
        assertTrue(put(cache, "https://example.test/a", "image", 2000))
        clock = 1999
        assertNotNull(cache.read("https://example.test/a"))
        clock = 2000
        assertNull(cache.read("https://example.test/a"))
    }

    @Test
    fun keepsRecentlyReadEntriesWithinTheByteBudget() = fixture { root ->
        var clock = 1L
        val cache = CraftNativeImageCache(root, maxBytes = 6, maxEntryBytes = 4, maxEntries = 3, now = { clock })
        assertTrue(put(cache, "a", "aaa"))
        clock++
        assertTrue(put(cache, "b", "bbb"))
        clock++
        assertNotNull(cache.read("a"))
        clock++
        assertTrue(put(cache, "c", "ccc"))
        assertNull(cache.read("b"))
        assertNotNull(cache.read("a"))
        assertNotNull(cache.read("c"))
    }

    @Test
    fun alsoBoundsTheNumberOfSmallEntries() = fixture { root ->
        var clock = 1L
        val cache = CraftNativeImageCache(root, maxBytes = 100, maxEntryBytes = 10, maxEntries = 1, now = { clock })
        assertTrue(put(cache, "a", "a"))
        clock++
        assertTrue(put(cache, "b", "b"))
        assertNull(cache.read("a"))
        assertEquals("b", String(cache.read("b")!!, Charsets.UTF_8))
    }

    @Test
    fun failedOrOversizedEncodingKeepsThePreviousCompleteImage() = fixture { root ->
        val cache = CraftNativeImageCache(root, maxBytes = 100, maxEntryBytes = 8, now = { 1 })
        assertTrue(put(cache, "a", "before"))
        assertFalse(put(cache, "a", "too-large-to-store"))
        assertFalse(cache.write("a", CraftNativeImagePolicy(1000)) { it.write("partial".toByteArray()); false })
        assertFalse(cache.write("a", CraftNativeImagePolicy(1000)) { throw IOException("No space left") })
        assertEquals("before", String(cache.read("a")!!, Charsets.UTF_8))
        assertTrue(root.listFiles().orEmpty().none { it.name.endsWith(".tmp") })
    }

    @Test
    fun readAndWriteFailuresRemainCacheMisses() = fixture { root ->
        val blocked = File(root, "not-a-directory").apply { writeText("occupied") }
        val cache = CraftNativeImageCache(blocked, now = { 1 })
        assertFalse(put(cache, "a", "image"))
        assertNull(cache.read("a"))
        cache.remove("a")
    }

    @Test
    fun removalAndEmptyFilesAreNeverRestored() = fixture { root ->
        val cache = CraftNativeImageCache(root, now = { 1 })
        assertTrue(put(cache, "a", "image"))
        root.listFiles()!!.single().writeBytes(byteArrayOf())
        assertNull(cache.read("a"))
        assertTrue(put(cache, "a", "image"))
        cache.remove("a")
        assertNull(cache.read("a"))
    }

    @Test
    fun distinctQueryVersionsKeepDistinctImages() = fixture { root ->
        val cache = CraftNativeImageCache(root, now = { 1 })
        assertTrue(put(cache, "https://example.test/image?v=1", "first"))
        assertTrue(put(cache, "https://example.test/image?v=2", "second"))
        assertArrayEquals("first".toByteArray(), cache.read("https://example.test/image?v=1"))
        assertArrayEquals("second".toByteArray(), cache.read("https://example.test/image?v=2"))
    }

    @Test
    fun relaunchReclaimsInterruptedEncodingsWithoutRemovingCompleteImages() = fixture { root ->
        val cache = CraftNativeImageCache(root, now = { 1 })
        assertTrue(put(cache, "a", "image"))
        val interrupted = File(root, "interrupted.tmp").apply { writeText("partial") }
        val next = CraftNativeImageCache(root, now = { 2 })
        assertFalse(interrupted.exists())
        assertArrayEquals("image".toByteArray(), next.read("a"))
    }

    @Test
    fun onlyExplicitlyPublicFreshResponsesArePersisted() {
        val policy = craftNativeImagePolicy(emptyMap(), publicHeaders + ("Age" to listOf("60")), 1000)
        assertEquals(1000 + 3540L * 1000, policy?.expiresAt)
        assertNotNull(craftNativeImagePolicy(emptyMap(), mapOf("cache-control" to listOf("PuBliC, MAX-AGE=\"20\"")), 1000))
        for (control in listOf("private, max-age=20", "public, private, max-age=20", "public, no-store, max-age=20", "public, no-cache, max-age=20", "public, max-age=0", "public, max-age=-1", "public, max-age=invalid", "public", "max-age=20")) {
            assertNull(control, craftNativeImagePolicy(emptyMap(), mapOf("Cache-Control" to listOf(control)), 1000))
        }
    }

    @Test
    fun credentialsCookiesAndUnboundedVariantsNeverUseThePublicCache() {
        for (headers in listOf(mapOf("Authorization" to "Bearer a"), mapOf("Cookie" to "session=a"), mapOf("X-Account" to "private"))) {
            assertNull(craftNativeImagePolicy(headers, publicHeaders, 1000))
        }
        assertNull(craftNativeImagePolicy(emptyMap(), publicHeaders + ("Set-Cookie" to listOf("session=a")), 1000))
        assertNull(craftNativeImagePolicy(emptyMap(), publicHeaders + ("Vary" to listOf("*")), 1000))
        assertNull(craftNativeImagePolicy(emptyMap(), publicHeaders + ("Vary" to listOf("Cookie")), 1000))
        assertNotNull(craftNativeImagePolicy(emptyMap(), publicHeaders + ("Vary" to listOf("Accept-Encoding")), 1000))
    }
}
