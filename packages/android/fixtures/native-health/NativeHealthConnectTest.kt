package {{PACKAGE_NAME}}

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * CraftNativeHealth against the device's real Health Connect: what a native
 * screen's `craft.health` reads and writes, in the shapes the iOS host
 * answers (CraftHealth.swift). Needs Android 14 or later (Health Connect in
 * the platform) and an app whose manifest declares the permissions below;
 * they are granted here the way a person grants them in Health Connect.
 */
@RunWith(AndroidJUnit4::class)
class NativeHealthConnectTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val zone = ZoneId.systemDefault()

    private val permissions = listOf(
        "READ_STEPS", "READ_HEART_RATE", "READ_ACTIVE_CALORIES_BURNED", "READ_DISTANCE", "READ_EXERCISE",
        "WRITE_EXERCISE", "WRITE_ACTIVE_CALORIES_BURNED", "WRITE_DISTANCE", "READ_SLEEP", "READ_WEIGHT",
        "READ_NUTRITION", "READ_MINDFULNESS", "WRITE_MINDFULNESS",
        // The fixture's own test data (steps, a night, a weigh-in, a meal,
        // heart rate): the fixture app declares these writes.
        "WRITE_STEPS", "WRITE_HEART_RATE", "WRITE_SLEEP", "WRITE_WEIGHT", "WRITE_NUTRITION",
    ).map { "android.permission.health.$it" }

    @Before
    fun grant() {
        // What the app's manifest declares, granted as Health Connect's
        // sheet grants it; one the manifest does not declare is skipped.
        val declared = context.packageManager.getPackageInfo(context.packageName, android.content.pm.PackageManager.GET_PERMISSIONS)
            .requestedPermissions.orEmpty().toSet()
        for (permission in permissions.filter { it in declared }) {
            runCatching { instrumentation.uiAutomation.grantRuntimePermission(context.packageName, permission) }
        }
    }

    private fun call(health: CraftNativeHealth, method: String, args: JSONArray = JSONArray()): CraftNativeCapabilityResult {
        val latch = CountDownLatch(1)
        var answer: CraftNativeCapabilityResult? = null
        instrumentation.runOnMainSync {
            health.perform(method, args) {
                answer = it
                latch.countDown()
            }
        }
        assertTrue("$method did not settle", latch.await(30, TimeUnit.SECONDS))
        return requireNotNull(answer)
    }

    private fun ok(result: CraftNativeCapabilityResult): Any? {
        assertNull("${result.code}: ${result.message}", result.code)
        return result.data
    }

    @Test
    fun readsAndWritesInTheHealthKitShapes() = runBlocking {
        val health = CraftNativeHealth(context, { null }, backgroundReads = false, historyReads = false)
        try {
            assertEquals("available", ok(call(health, "availability")))

            // Everything asked for is granted already: answered with no sheet.
            assertEquals(true, ok(call(health, "requestAuthorization", JSONArray().put(JSONArray().put("steps").put("sleep").put("workouts")).put(JSONObject().put("write", JSONArray().put("workouts"))))))
            val granted = ok(call(health, "grantedTypes")) as JSONArray
            assertTrue((0 until granted.length()).map(granted::getString).containsAll(listOf("steps", "sleep", "workouts")))

            val client = HealthConnectClient.getOrCreate(context)
            // What this app wrote in the last two days is this test's own,
            // from an earlier run: gone, so sums count this run alone.
            val lately = TimeRangeFilter.between(Instant.now().minusSeconds(48 * 3600), Instant.now().plusSeconds(60))
            for (type in listOf(ExerciseSessionRecord::class, DistanceRecord::class, ActiveCaloriesBurnedRecord::class, StepsRecord::class,
                HeartRateRecord::class, SleepSessionRecord::class, WeightRecord::class, NutritionRecord::class)) {
                runCatching { client.deleteRecords(type, lately) }
            }
            val now = Instant.now().minusSeconds(600)
            val offset = zone.rules.getOffset(now)
            val tag = UUID.randomUUID().toString()
            client.insertRecords(listOf(
                StepsRecord(startTime = now.minusSeconds(3600), startZoneOffset = offset, endTime = now.minusSeconds(1800), endZoneOffset = offset, count = 4321, metadata = Metadata.manualEntry(clientRecordId = "steps-$tag")),
                HeartRateRecord(startTime = now.minusSeconds(300), startZoneOffset = offset, endTime = now, endZoneOffset = offset,
                    samples = listOf(HeartRateRecord.Sample(now.minusSeconds(240), 61), HeartRateRecord.Sample(now.minusSeconds(120), 64)),
                    metadata = Metadata.manualEntry(clientRecordId = "hr-$tag")),
                SleepSessionRecord(startTime = now.minusSeconds(9 * 3600), startZoneOffset = offset, endTime = now.minusSeconds(3600 + 1800), endZoneOffset = offset,
                    stages = listOf(
                        SleepSessionRecord.Stage(now.minusSeconds(9 * 3600), now.minusSeconds(6 * 3600), SleepSessionRecord.STAGE_TYPE_LIGHT),
                        SleepSessionRecord.Stage(now.minusSeconds(6 * 3600), now.minusSeconds(4 * 3600), SleepSessionRecord.STAGE_TYPE_DEEP),
                        SleepSessionRecord.Stage(now.minusSeconds(4 * 3600), now.minusSeconds(3600 + 1800), SleepSessionRecord.STAGE_TYPE_AWAKE),
                    ),
                    metadata = Metadata.manualEntry(clientRecordId = "sleep-$tag")),
                WeightRecord(time = now.minusSeconds(7200), zoneOffset = offset, weight = Mass.kilograms(72.5), metadata = Metadata.manualEntry(clientRecordId = "weight-$tag")),
                NutritionRecord(startTime = now.minusSeconds(5400), startZoneOffset = offset, endTime = now.minusSeconds(5000), endZoneOffset = offset,
                    energy = Energy.kilocalories(640.0), protein = Mass.grams(32.0), metadata = Metadata.manualEntry(clientRecordId = "food-$tag")),
            ))

            val start = now.minusSeconds(24 * 3600).toEpochMilli().toDouble()
            val end = Instant.now().toEpochMilli().toDouble()
            val range = JSONObject().put("startDate", start).put("endDate", end)
            val today = LocalDate.now(zone).format(DateTimeFormatter.ISO_LOCAL_DATE)

            // A finished run, written as the workout player writes it, and read back.
            val runStart = now.minusSeconds(2 * 3600).toEpochMilli().toDouble()
            val saved = ok(call(health, "saveWorkout", JSONArray().put(JSONObject()
                .put("activityId", "run-$tag").put("type", "running")
                .put("startDate", runStart).put("endDate", runStart + 1_800_000)
                .put("distanceMeters", 5000).put("activeEnergyCalories", 320)))) as JSONObject
            assertNotNull(saved.optString("id").takeIf { it.isNotBlank() })
            val workouts = ok(call(health, "getWorkouts", JSONArray().put(range))) as JSONArray
            val run = (0 until workouts.length()).map(workouts::getJSONObject).first { it.getDouble("startDate") == runStart }
            assertEquals("running", run.getString("type"))
            assertEquals(1800.0, run.getDouble("durationSeconds"), 1.0)
            assertEquals(5000.0, run.getDouble("distanceMeters"), 1.0)
            // The writing app is named as people know it: HQ skips its own writes by that name.
            assertEquals(context.applicationInfo.loadLabel(context.packageManager).toString(), run.getString("sourceName"))

            // A day's steps are Health Connect's own sum, which counts only the
            // apps on its data-priority list: an app joins it when a person
            // grants it there, which a test's shell grant does not do. The
            // answer is a list of days either way.
            val steps = ok(call(health, "getDailyStatistics", JSONArray().put("steps").put(range))) as JSONArray
            for (index in 0 until steps.length()) {
                val day = steps.getJSONObject(index)
                assertTrue(Regex("\\d{4}-\\d{2}-\\d{2}").matches(day.getString("date")))
                assertEquals("count", day.getString("unit"))
            }

            val beats = ok(call(health, "getHeartRateSamples", JSONArray().put(range))) as JSONArray
            val bpms = (0 until beats.length()).map { beats.getJSONObject(it).getDouble("bpm") }
            assertTrue("beats $beats", bpms.containsAll(listOf(61.0, 64.0)))

            val intervals = ok(call(health, "getSleepIntervals", JSONArray().put(range))) as JSONArray
            val stages = (0 until intervals.length()).map { intervals.getJSONObject(it).getString("stage") }
            assertTrue("stages $stages", stages.containsAll(listOf("core", "deep", "awake")))
            val nights = ok(call(health, "getDailyStatistics", JSONArray().put("sleep").put(range))) as JSONArray
            assertTrue("sleep $nights", (0 until nights.length()).any { nights.getJSONObject(it).getDouble("value") >= 5.0 })

            val weights = ok(call(health, "getDailyStatistics", JSONArray().put("bodyMass").put(range))) as JSONArray
            assertTrue("weight $weights", (0 until weights.length()).any { weights.getJSONObject(it).getDouble("value") == 72.5 })
            val food = ok(call(health, "getDailyStatistics", JSONArray().put("dietaryEnergy").put(range))) as JSONArray
            assertTrue("food $food", food.length() == 0 || (0 until food.length()).any { food.getJSONObject(it).getDouble("value") >= 640.0 })

            // Mindful minutes, where this Health Connect has them: a second save keeps the first.
            val mindful = call(health, "saveMindfulSession", JSONArray().put(JSONObject().put("id", "breath-$tag").put("startDate", start + 60_000).put("endDate", start + 360_000)))
            if (mindful.code == null) {
                assertEquals(false, (mindful.data as JSONObject).getBoolean("existing"))
                val again = ok(call(health, "saveMindfulSession", JSONArray().put(JSONObject().put("id", "breath-$tag").put("startDate", start + 60_000).put("endDate", start + 360_000)))) as JSONObject
                assertEquals(true, again.getBoolean("existing"))
                val sessions = ok(call(health, "getMindfulSessions", JSONArray().put(range))) as JSONArray
                assertTrue((0 until sessions.length()).map(sessions::getJSONObject).any { it.optString("externalId") == "breath-$tag" && it.getBoolean("ownApp") })
            } else {
                assertEquals("UNSUPPORTED", mindful.code)
            }

            // Unknown types and methods fail the way the iOS host's do.
            assertEquals("INVALID_ARGUMENT", call(health, "requestAuthorization", JSONArray().put(JSONArray().put("oxygen"))).code)
            assertEquals("UNKNOWN_ACTION", call(health, "measureAura").code)
        }
        finally {
            health.close()
        }
    }
}
