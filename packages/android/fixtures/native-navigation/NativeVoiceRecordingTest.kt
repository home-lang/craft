package dev.craft.navigationtest

import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeVoiceRecordingTest {
    @Test
    fun microphoneFilesAreBoundedOwnedAndDeletedOnCancellation() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        instrumentation.uiAutomation.executeShellCommand("pm grant ${context.packageName} android.permission.RECORD_AUDIO").close()
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var services: CraftNativeServices
            scenario.onActivity { activity -> services = CraftNativeServices(activity, JSONObject().put("enableAudioRecording", true)) { activity } }
            fun call(method: String, args: JSONArray): CraftNativeCapabilityResult {
                val latch = CountDownLatch(1)
                var result: CraftNativeCapabilityResult? = null
                services.perform("AudioRecording", method, args) { result = it; latch.countDown() }
                assertTrue("Microphone request did not settle", latch.await(10, TimeUnit.SECONDS))
                return result!!
            }
            val owner = UUID.randomUUID().toString()
            val other = UUID.randomUUID().toString()
            try {
                assertNull(call("start", JSONArray().put(owner).put(JSONObject().put("maxSeconds", 2))).code)
                assertEquals("RECORDING_BUSY", call("start", JSONArray().put(other)).code)
                assertEquals("RECORDING_NOT_FOUND", call("stop", JSONArray().put(other)).code)
                Thread.sleep(700)
                val stopped = call("stop", JSONArray().put(owner))
                assertNull(stopped.message, stopped.code)
                val file = stopped.data as JSONObject
                assertEquals("audio/mp4", file.getString("type"))
                assertTrue(file.getDouble("durationSeconds") > 0)
                val path = File(file.getString("path"))
                assertTrue(path.exists())
                call("cancel", JSONArray().put(other))
                assertTrue(path.exists())
                call("cancel", JSONArray().put(owner))
                assertFalse(path.exists())
            } finally { call("cancel", JSONArray().put(owner)) }
        }
    }
}
