package {{PACKAGE_NAME}}

import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.util.Collections
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
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
    private fun serve(ranges: Boolean = true, status: Int = 200, payload: ByteArray = body, check: (String, MutableList<String?>) -> Unit) {
        val seen = Collections.synchronizedList(mutableListOf<String?>())
        val server = ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"))
        server.soTimeout = 5000
        val served = CompletableFuture<Unit>()
        val worker = thread(name = "craft-media-http-fixture") {
            try {
                server.accept().use { socket ->
                    socket.soTimeout = 5000
                    val reader = socket.getInputStream().bufferedReader(Charsets.US_ASCII)
                    checkNotNull(reader.readLine()) { "Missing HTTP request" }
                    var range: String? = null
                    while (true) {
                        val header = reader.readLine() ?: break
                        if (header.isEmpty()) break
                        if (header.startsWith("Range:", ignoreCase = true)) range = header.substringAfter(':').trim()
                    }
                    seen.add(range)
                    val start = Regex("^bytes=(\\d+)-$").find(range.orEmpty())?.groupValues?.get(1)?.toInt()
                    val code = when {
                        status != 200 -> status
                        ranges && start != null && start >= payload.size -> 416
                        ranges && start != null -> 206
                        else -> 200
                    }
                    val bytes = when (code) {
                        206 -> payload.copyOfRange(start!!, payload.size)
                        200 -> payload
                        else -> byteArrayOf()
                    }
                    val contentRange = if (code == 206) "Content-Range: bytes $start-${payload.size - 1}/${payload.size}\r\n" else ""
                    val headers = "HTTP/1.1 $code Test\r\nContent-Length: ${bytes.size}\r\n${contentRange}Connection: close\r\n\r\n"
                    socket.getOutputStream().write(headers.toByteArray(Charsets.US_ASCII) + bytes)
                }
                served.complete(Unit)
            } catch (error: Throwable) {
                served.completeExceptionally(error)
            }
        }
        try {
            check("http://127.0.0.1:${server.localPort}/clip.mp4", seen)
            served.get(5, TimeUnit.SECONDS)
        } finally {
            server.close()
            worker.join(5000)
            assertFalse("The local HTTP fixture must stop after each transfer", worker.isAlive)
        }
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
    fun refusesAnEmptyResponseWithoutRetainingAnUnresumablePart() = part { file ->
        serve(payload = byteArrayOf()) { address, _ ->
            assertEquals(CraftResumableDownload.Fetched.Incomplete, CraftResumableDownload().fetch(address, emptyMap(), file) { false })
            assertFalse("An empty file has no bytes to resume", file.exists())
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
