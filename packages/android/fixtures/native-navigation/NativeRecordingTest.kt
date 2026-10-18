package dev.craft.navigationtest

import android.content.Context
import android.content.ContextWrapper
import android.location.Location
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.craft.runtime.CraftLocationRecordingStore as Store
import com.craft.runtime.CraftRecordingException
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeRecordingTest {
    private fun fixture(test: (Context, File) -> Unit) {
        val base = InstrumentationRegistry.getInstrumentation().targetContext
        val name = "recording-test-${UUID.randomUUID()}"
        val root = File(base.cacheDir, name).apply { check(mkdirs()) }
        val context = object : ContextWrapper(base) {
            override fun getFilesDir() = root
            override fun getSharedPreferences(key: String, mode: Int) = base.getSharedPreferences("$name-$key", mode)
        }
        try { Store.listener = null; test(context, root) }
        finally { Store.listener = null; root.deleteRecursively(); base.deleteSharedPreferences("$name-craft_location_recording") }
    }
    private fun owner(id: String) = JSONObject().put("expectedId", id)
    private fun archive(root: File, id: String, kind: String = "completed"): File {
        val hash = java.security.MessageDigest.getInstance("SHA-256").digest(id.toByteArray()).joinToString("") { "%02x".format(it) }
        return File(root, "craft-location-$kind-$hash.json")
    }
    private fun rejects(code: String, operation: () -> Unit) {
        try { operation(); fail("Expected $code") }
        catch (error: CraftRecordingException) { assertEquals(code, error.code) }
    }

    @Test fun completedOwnerCanRecoverAndAcknowledgeWithoutChangingNewOwner() = fixture { context, root ->
        Store.start(context, "A", 1)
        File(root, "craft-location-recording.jsonl").writeText("{\"latitude\":1}\n")
        Store.finish(context, owner("A"))
        Store.start(context, "B", 2)
        val current = File(root, "craft-location-recording.jsonl")
        current.writeText("{\"latitude\":2}\n")
        assertEquals(1, Store.read(context, owner("A")).getJSONObject(0).getInt("latitude"))
        assertEquals("A", Store.finish(context, owner("A")).getString("id"))
        assertFalse(Store.state(context, options = owner("A")).getBoolean("active"))
        rejects("RECORDING_CONFLICT") { Store.updatePause(context, true, owner("A")) }
        rejects("RECORDING_ALREADY_ACTIVE") { Store.acknowledge(context, owner("B")) }
        assertTrue(Store.acknowledge(context, owner("A")))
        assertTrue(Store.acknowledge(context, owner("A")))
        rejects("RECORDING_NOT_FOUND") { Store.read(context, owner("A")) }
        assertEquals("B", Store.recordingId(context))
        assertTrue(Store.isActive(context))
        assertEquals("{\"latitude\":2}\n", current.readText())
    }

    @Test fun archiveFailureRefusesReplacementBeforeTruncatingSamples() = fixture { context, root ->
        Store.start(context, "A", 1)
        val current = File(root, "craft-location-recording.jsonl")
        current.writeText("{\"latitude\":1}\n")
        Store.finish(context, owner("A"))
        check(archive(root, "A").mkdir())
        try { Store.start(context, "B", 2); fail("Replaced an unreadable archive") } catch (_: java.io.IOException) { }
        assertEquals("A", Store.recordingId(context))
        assertEquals("{\"latitude\":1}\n", current.readText())
    }

    @Test fun acknowledgedCurrentRecordingIsCleanedAfterInterruptedDeletion() = fixture { context, root ->
        Store.start(context, "A", 1)
        Store.finish(context, owner("A"))
        archive(root, "A", "ack").writeText("A")
        Store.recover(context)
        assertNull(Store.recordingId(context))
        assertFalse(File(root, "craft-location-recording.jsonl").exists())
        assertTrue(Store.acknowledge(context, owner("A")))
        rejects("RECORDING_NOT_FOUND") { Store.read(context, owner("A")) }
    }

    @Test fun recordingEventsKeepTheOwnerCapturedBeforeAccountHandoff() = fixture { context, _ ->
        Store.start(context, "A", 1)
        val owners = mutableListOf<String>()
        Store.listener = { _, id -> owners += id }
        val point = Location("fixture").apply { latitude = 1.0; longitude = 2.0; time = 3 }
        Store.append(context, point, "A")
        Store.finish(context, owner("A"))
        Store.start(context, "B", 2)
        Store.listener = { _, id -> owners += id }
        Store.append(context, point, "A")
        Store.append(context, point, "B")
        assertEquals(listOf("A", "B"), owners)
        assertEquals("B", Store.read(context, owner("B")).getJSONObject(0).getString("recordingId"))
    }

    @Test fun simultaneousStartsHaveExactlyOneOwner() = fixture { context, _ ->
        val ready = CountDownLatch(12)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(12)
        val started = AtomicInteger()
        val refused = AtomicInteger()
        val errors = java.util.Collections.synchronizedList(mutableListOf<Throwable>())
        repeat(12) { index -> thread(name = "recording-owner-$index") {
            ready.countDown()
            try {
                check(release.await(5, TimeUnit.SECONDS))
                Store.start(context, "owner-$index", index.toLong())
                started.incrementAndGet()
            } catch (error: CraftRecordingException) {
                if (error.code == "RECORDING_ALREADY_ACTIVE") refused.incrementAndGet() else errors += error
            } catch (error: Throwable) { errors += error }
            finally { finished.countDown() }
        } }
        assertTrue(ready.await(5, TimeUnit.SECONDS))
        release.countDown()
        assertTrue(finished.await(10, TimeUnit.SECONDS))
        assertTrue(errors.toString(), errors.isEmpty())
        assertEquals(1, started.get())
        assertEquals(11, refused.get())
        assertTrue(Store.isActive(context))
    }
}
