package dev.craft.navigationtest

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.net.ServerSocket
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeCapabilitiesTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    private fun call(
        capabilities: CraftNativeCapabilities,
        module: String,
        method: String,
        args: JSONArray = JSONArray(),
    ): CraftNativeCapabilityResult {
        val latch = CountDownLatch(1)
        var answer: CraftNativeCapabilityResult? = null
        capabilities.perform(
            UUID.randomUUID().toString(),
            CRAFT_NATIVE_CAPABILITY_PROTOCOL_VERSION,
            module,
            method,
            args,
        ) {
            answer = it
            latch.countDown()
        }
        assertTrue("native capability did not settle", latch.await(10, TimeUnit.SECONDS))
        return requireNotNull(answer)
    }

    @Test
    fun fetchUsesTheSameTextProtocolAsTheIosHost() {
        val server = ServerSocket(0)
        val received = mutableListOf<String>()
        val serving = thread(name = "native-fetch-fixture") {
            server.accept().use { socket ->
                val reader = socket.getInputStream().bufferedReader()
                val lines = mutableListOf<String>()
                while (true) {
                    val line = reader.readLine()
                    if (line.isNullOrEmpty()) break
                    lines += line
                }
                val length = lines.firstOrNull { it.startsWith("Content-Length:", ignoreCase = true) }
                    ?.substringAfter(':')?.trim()?.toIntOrNull() ?: 0
                val body = CharArray(length)
                var offset = 0
                while (offset < length) {
                    val count = reader.read(body, offset, length - offset)
                    if (count < 0) break
                    offset += count
                }
                received += lines.joinToString("\n") + "\n\n" + String(body, 0, offset)
                val response = "{\"activity\":{\"id\":42}}"
                socket.getOutputStream().bufferedWriter().use { writer ->
                    writer.write("HTTP/1.1 201 Created\r\n")
                    writer.write("Content-Type: application/json\r\n")
                    writer.write("X-Native-Test: android\r\n")
                    writer.write("Content-Length: ${response.toByteArray().size}\r\n")
                    writer.write("Connection: close\r\n\r\n")
                    writer.write(response)
                }
            }
        }
        val activity = instrumentation.startActivitySync(
            Intent(instrumentation.targetContext, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ) as MainActivity
        val capabilities = CraftNativeCapabilities(activity, JSONObject())
        try {
            assertTrue(capabilities.names().toString().contains("fetch"))
            assertEquals("INVALID_ARGUMENT", call(capabilities, "Network", "fetch", JSONArray()
                .put(JSONObject().put("url", "/api/activities"))).code)
            assertEquals("INVALID_ARGUMENT", call(capabilities, "Network", "fetch", JSONArray().put(JSONObject()
                .put("url", "http://127.0.0.1:${server.localPort}/api/activities")
                .put("method", "GET")
                .put("body", "not allowed"))).code)
            assertEquals("INVALID_ARGUMENT", call(capabilities, "Network", "fetch", JSONArray().put(JSONObject()
                .put("url", "http://127.0.0.1:${server.localPort}/api/activities")
                .put("body", 42))).code)
            assertEquals("INVALID_ARGUMENT", call(capabilities, "Network", "fetch", JSONArray().put(JSONObject()
                .put("url", "http://127.0.0.1:${server.localPort}/api/activities")
                .put("headers", JSONObject().put("X-Native-Test", 42)))).code)

            val result = call(capabilities, "Network", "fetch", JSONArray().put(JSONObject()
                .put("url", "http://127.0.0.1:${server.localPort}/api/activities")
                .put("method", "POST")
                .put("headers", JSONObject()
                    .put("Authorization", "Bearer native-token")
                    .put("Content-Type", "application/json"))
                .put("body", "{\"distance\":5}")))
            assertNull(result.code)
            val response = result.data as JSONObject
            assertEquals(201, response.getInt("status"))
            assertEquals("Created", response.getString("statusText"))
            assertEquals("android", response.getJSONObject("headers").getString("x-native-test"))
            assertEquals("{\"activity\":{\"id\":42}}", response.getString("body"))
            serving.join(5_000)
            assertTrue(received.single().contains("authorization: Bearer native-token", ignoreCase = true))
            assertTrue(received.single().endsWith("{\"distance\":5}"))
        }
        finally {
            server.close()
            capabilities.close()
            instrumentation.runOnMainSync { activity.finishAndRemoveTask() }
            instrumentation.waitForIdleSync()
        }
    }

    @Test
    fun persistsStorageAndCommittedDatabaseTransactionsAcrossHosts() {
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ) as MainActivity
        val config = JSONObject()
            .put("enableLocalDatabase", true)
            .put("enableDeepLinks", true)
            .put("enableLocalNotifications", true)
            .put("enableSecureStorage", true)
            .put("enableBiometric", true)
        var capabilities = CraftNativeCapabilities(activity, config)
        try {
            call(capabilities, "Storage", "clear")
            assertNull(call(capabilities, "Storage", "set", JSONArray()
                .put("profile").put(JSONObject().put("name", "Ada").put("visits", 2))).code)
            assertEquals("INVALID_ARGUMENT", call(capabilities, "Storage", "set", JSONArray()
                .put("invalid").put(Any())).code)
            capabilities.close()
            capabilities = CraftNativeCapabilities(activity, config)
            val profile = call(capabilities, "Storage", "get", JSONArray().put("profile")).data as JSONObject
            assertEquals("Ada", profile.getString("name"))
            assertEquals(2, profile.getInt("visits"))

            assertNull(call(capabilities, "SecureStorage", "clear").code)
            assertNull(call(capabilities, "SecureStorage", "set", JSONArray().put("secret").put("keychain-value")).code)
            assertEquals("keychain-value", call(capabilities, "SecureStorage", "get", JSONArray().put("secret")).data)
            assertNull(call(capabilities, "SecureStorage", "remove", JSONArray().put("secret")).code)
            assertEquals(JSONObject.NULL, call(capabilities, "SecureStorage", "get", JSONArray().put("secret")).data)
            assertNull(call(capabilities, "Biometrics", "isAvailable").code)
            assertNull(call(capabilities, "Biometrics", "getBiometricType").code)

            val table = "capability_${UUID.randomUUID().toString().replace("-", "")}"
            assertNull(call(capabilities, "Database", "execute", JSONArray()
                .put("CREATE TABLE $table (id INTEGER PRIMARY KEY, name TEXT NOT NULL)").put(JSONArray())).code)
            assertNull(call(capabilities, "Database", "beginTransaction").code)
            assertNull(call(capabilities, "Database", "execute", JSONArray()
                .put("INSERT INTO $table (name) VALUES (?)").put(JSONArray().put("Grace"))).code)
            assertNull(call(capabilities, "Database", "commit").code)
            capabilities.close()
            capabilities = CraftNativeCapabilities(activity, config)
            val rows = call(capabilities, "Database", "query", JSONArray()
                .put("SELECT name FROM $table").put(JSONArray())).data as JSONArray
            assertEquals("Grace", rows.getJSONObject(0).getString("name"))
        }
        finally {
            capabilities.close()
            instrumentation.runOnMainSync { activity.finishAndRemoveTask() }
            instrumentation.waitForIdleSync()
        }
    }
}
