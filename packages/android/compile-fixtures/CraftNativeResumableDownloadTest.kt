package {{PACKAGE_NAME}}

import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
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

    /**
     * Serves `body`, honouring `Range: bytes=N-` when `ranges` is on; records
     * each request's Range. A plain socket: Android's unit-test classpath has
     * no com.sun.net.httpserver.
     */
    private fun serve(ranges: Boolean = true, status: Int = 200, check: (String, MutableList<String?>) -> Unit) {
        val seen = java.util.Collections.synchronizedList(mutableListOf<String?>())
        val server = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        val thread = Thread {
            while (!server.isClosed) {
                val socket = runCatching { server.accept() }.getOrNull() ?: break
                socket.use { client ->
                    val reader = client.getInputStream().bufferedReader(Charsets.ISO_8859_1)
                    val lines = generateSequence { reader.readLine() }.takeWhile { it.isNotEmpty() }.toList()
                    val range = lines.drop(1).firstOrNull { it.startsWith("Range:", ignoreCase = true) }?.substringAfter(':')?.trim()
                    seen.add(range)
                    val start = Regex("^bytes=(\\d+)-$").find(range.orEmpty())?.groupValues?.get(1)?.toInt()
                    val out = client.getOutputStream()
                    fun head(code: Int, length: Int, extra: String = "") =
                        out.write("HTTP/1.1 $code X\r\nContent-Length: $length\r\n${extra}Connection: close\r\n\r\n".toByteArray(Charsets.ISO_8859_1))
                    when {
                        status != 200 -> head(status, 0)
                        ranges && start != null && start >= body.size -> head(416, 0)
                        ranges && start != null -> {
                            head(206, body.size - start, "Content-Range: bytes $start-${body.size - 1}/${body.size}\r\n")
                            out.write(body, start, body.size - start)
                        }
                        else -> {
                            head(200, body.size)
                            out.write(body)
                        }
                    }
                    out.flush()
                }
            }
        }
        thread.isDaemon = true
        thread.start()
        try { check("http://127.0.0.1:${server.localPort}/clip.mp4", seen) }
        finally { server.close(); thread.join(2000) }
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
