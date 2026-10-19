package {{PACKAGE_NAME}}

import com.sun.net.httpserver.HttpServer
import java.io.File
import java.net.InetSocketAddress
import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * craft.media's transfers on Android (CraftResumableDownload): a part an
 * earlier attempt left is resumed with a Range request, a server that
 * ignores Range starts the file again, and a part that no longer lines up
 * is dropped. Against a local server, on the JVM.
 */
class CraftNativeResumableDownloadTest {
    private val body = "0123456789abcdefghij".toByteArray()

    /** Serves `body`, honouring `Range: bytes=N-` when `ranges` is on; records each request's Range. */
    private fun serve(ranges: Boolean = true, status: Int = 200, check: (String, MutableList<String?>) -> Unit) {
        val seen = mutableListOf<String?>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val range = exchange.requestHeaders.getFirst("Range")
            seen.add(range)
            val start = Regex("^bytes=(\\d+)-$").find(range.orEmpty())?.groupValues?.get(1)?.toInt()
            when {
                status != 200 -> exchange.sendResponseHeaders(status, -1)
                ranges && start != null && start >= body.size -> exchange.sendResponseHeaders(416, -1)
                ranges && start != null -> {
                    exchange.responseHeaders.add("Content-Range", "bytes $start-${body.size - 1}/${body.size}")
                    exchange.sendResponseHeaders(206, (body.size - start).toLong())
                    exchange.responseBody.use { it.write(body, start, body.size - start) }
                }
                else -> {
                    exchange.sendResponseHeaders(200, body.size.toLong())
                    exchange.responseBody.use { it.write(body) }
                }
            }
            exchange.close()
        }
        server.start()
        try { check("http://127.0.0.1:${server.address.port}/clip.mp4", seen) }
        finally { server.stop(0) }
    }

    private fun part(check: (File) -> Unit) {
        val root = Files.createTempDirectory("craft-media-test-").toFile()
        try { check(File(root, "clip.mp4.part")) }
        finally { root.deleteRecursively() }
    }

    @Test
    fun fetchesTheWholeFileTheFirstTime() = part { file ->
        serve { address, seen ->
            val fetched = CraftResumableDownload().fetch(address, emptyMap(), file) { false }
            assertEquals(CraftResumableDownload.Fetched.Complete(body.size.toLong()), fetched)
            assertArrayEquals(body, file.readBytes())
            assertEquals(listOf<String?>(null), seen)
        }
    }

    @Test
    fun resumesWhereAnEarlierAttemptStopped() = part { file ->
        file.writeBytes(body.copyOfRange(0, 7))
        serve { address, seen ->
            val fetched = CraftResumableDownload().fetch(address, mapOf("Authorization" to "Bearer t"), file) { false }
            assertEquals(CraftResumableDownload.Fetched.Complete(body.size.toLong()), fetched)
            assertArrayEquals(body, file.readBytes())
            assertEquals(listOf<String?>("bytes=7-"), seen)
        }
    }

    @Test
    fun startsAgainWhenTheServerIgnoresTheRange() = part { file ->
        file.writeBytes("stale".toByteArray())
        serve(ranges = false) { address, _ ->
            assertEquals(CraftResumableDownload.Fetched.Complete(body.size.toLong()), CraftResumableDownload().fetch(address, emptyMap(), file) { false })
            assertArrayEquals(body, file.readBytes())
        }
    }

    @Test
    fun dropsAPartThatNoLongerLinesUp() = part { file ->
        file.writeBytes(ByteArray(body.size + 5))
        serve { address, _ ->
            assertEquals(CraftResumableDownload.Fetched.Restart, CraftResumableDownload().fetch(address, emptyMap(), file) { false })
            assertFalse(file.exists())
        }
    }

    @Test
    fun saysWhatTheServerRefusedAndKeepsNothing() = part { file ->
        serve(status = 404) { address, _ ->
            assertEquals(CraftResumableDownload.Fetched.Refused(404), CraftResumableDownload().fetch(address, emptyMap(), file) { false })
            assertFalse(file.exists())
        }
    }

    @Test
    fun refusesAPartNobodyAskedFor() = part { file ->
        serve(status = 206) { address, seen ->
            assertEquals(CraftResumableDownload.Fetched.Refused(206), CraftResumableDownload().fetch(address, emptyMap(), file) { false })
            assertEquals(listOf<String?>(null), seen)
            assertFalse(file.exists())
        }
    }

    @Test
    fun keepsWhatItHasWhenStopped() = part { file ->
        serve { address, _ ->
            assertEquals(CraftResumableDownload.Fetched.Stopped, CraftResumableDownload().fetch(address, emptyMap(), file) { true })
            assertTrue(file.exists())
        }
    }

    @Test
    fun readsContentRange() {
        assertEquals(100L, CraftResumableDownload.rangeStart("bytes 100-199/1000"))
        assertEquals(1000L, CraftResumableDownload.rangeTotal("bytes 100-199/1000"))
        assertEquals(-1L, CraftResumableDownload.rangeTotal("bytes 100-199/*"))
        assertEquals(-1L, CraftResumableDownload.rangeStart(null))
    }
}
