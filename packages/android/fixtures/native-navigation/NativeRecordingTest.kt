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
        try { Store.listener = null; Store.nativeListener = null; test(context, root) }
        finally { Store.listener = null; Store.nativeListener = null; root.deleteRecursively(); base.deleteSharedPreferences("$name-craft_location_recording") }
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

    @Test fun plannedIdentitySurvivesLostStartResponseAndRejectsReuse() = fixture { context, root ->
        val planned = UUID.randomUUID().toString()
        // Only permission and the OS service launch are isolated. The actual
        // production perform/start/state/file/ACK code runs unchanged.
        val host = object : ContextWrapper(context) {
            override fun checkPermission(permission: String, pid: Int, uid: Int) = android.content.pm.PackageManager.PERMISSION_GRANTED
            override fun checkSelfPermission(permission: String) = android.content.pm.PackageManager.PERMISSION_GRANTED
            override fun startForegroundService(intent: android.content.Intent): android.content.ComponentName = android.content.ComponentName(packageName, "FixtureLocationService")
            override fun startService(intent: android.content.Intent): android.content.ComponentName = android.content.ComponentName(packageName, "FixtureLocationService")
        }
        val intent = File(root, "draft.json")
        intent.writeText(JSONObject().put("owner", "A").put("gpsRecordingId", planned).toString())
        val started = JSONObject(Store.perform(host, "startRecording", JSONObject().put("recordingId", planned).toString()))
        assertTrue(started.toString(), started.getBoolean("ok"))
        // Discard the response's ID; recover only the precommitted intent.
        val reopened = JSONObject(intent.readText()).getString("gpsRecordingId")
        val current = File(root, "craft-location-recording.jsonl")
        current.writeText("{\"latitude\":1}\n")
        Store.recover(context)
        assertEquals(planned, reopened)
        assertEquals(planned, Store.state(context, options = owner(reopened)).getString("id"))
        assertEquals(1, Store.read(context, owner(reopened)).getJSONObject(0).getInt("latitude"))
        Store.finish(context, owner(reopened))
        val reused = JSONObject(Store.perform(host, "startRecording", JSONObject().put("recordingId", planned).toString()))
        assertEquals("RECORDING_CONFLICT", reused.getString("code"))
        assertEquals("{\"latitude\":1}\n", current.readText())
        Store.acknowledge(context, owner(reopened))
        val acknowledged = JSONObject(Store.perform(host, "startRecording", JSONObject().put("recordingId", planned).toString()))
        assertEquals("RECORDING_CONFLICT", acknowledged.getString("code"))
        assertFalse(current.exists())
    }

    @Test fun aPageStartedRecordingAlsoReachesTheNativeScreenHub() = fixture { context, _ ->
        val token = "recording-hub-${UUID.randomUUID()}"
        val received = CountDownLatch(1)
        val nativeCount = AtomicInteger()
        var pageCount = 0
        val services = CraftNativeServices(context, JSONObject().put("enableGeolocation", true)) { null }
        CraftNativeHub.register(token) { type, payload ->
            if (type == "CRAFT_EVENT" && payload.optString("event") == "craftLocationUpdate") {
                assertEquals("page-A", payload.getJSONObject("detail").getString("recordingId"))
                nativeCount.incrementAndGet()
                received.countDown()
            }
        }
        try {
            Store.start(context, "page-A", 1)
            Store.listen(context, "page-A") { _, id -> assertEquals("page-A", id); pageCount += 1 }
            Store.append(context, Location("fixture").apply { latitude = 1.0; longitude = 2.0; time = 3 }, "page-A")
            assertTrue(received.await(5, TimeUnit.SECONDS))
            assertEquals(1, pageCount)
            assertEquals(1, nativeCount.get())
        } finally { CraftNativeHub.unregister(token); services.close() }
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
        val nativeOwners = mutableListOf<String>()
        Store.nativeListener = { _, id -> nativeOwners += id }
        Store.listener = { _, id -> owners += id }
        val point = Location("fixture").apply { latitude = 1.0; longitude = 2.0; time = 3 }
        Store.append(context, point, "A")
        Store.finish(context, owner("A"))
        Store.start(context, "B", 2)
        Store.listener = { _, id -> owners += id }
        Store.listen(context, "A") { _, _ -> fail("Late A callback replaced B's listener") }
        Store.append(context, point, "A")
        Store.append(context, point, "B")
        assertEquals(listOf("A", "B"), owners)
        assertEquals(listOf("A", "B"), nativeOwners)
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
