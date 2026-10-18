package dev.craft.navigationtest

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.Point

/** The actual generated host and GL renderer, installed on an Android device. */
@RunWith(AndroidJUnit4::class)
class NativeMapTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    private fun <T> main(block: () -> T): T {
        val result = AtomicReference<Result<T>>()
        instrumentation.runOnMainSync { result.set(runCatching(block)) }
        return result.get().getOrThrow()
    }

    private fun awaitState(message: String, block: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 45_000
        while (SystemClock.uptimeMillis() < deadline) {
            if (main(block)) return
            SystemClock.sleep(100)
        }
        assertTrue(message, main(block))
    }

    private fun props() = JSONObject().put("fitToBounds", true).put("showsCompass", true).put("showsScale", true)
        .put("pitchEnabled", false).put("rotateEnabled", true)
        .put("edgePadding", JSONObject().put("top", 88).put("bottom", 180).put("left", 32).put("right", 32))

    private fun overlays(color: String = "#24724b") = JSONArray("""[
        {"type":"MapPolyline","props":{"id":"route","geometry":[47,11,47.01,11.01],"strokeColor":"#24724b","strokeWidth":5}},
        {"type":"MapMarker","props":{"id":"start","geometry":[47,11],"pinColor":"$color","title":"Trailhead"}},
        {"type":"MapMarker","props":{"id":"direction","geometry":[47.005,11.005],"bearing":90,"title":"Recorded direction"}}
    ]""")

    private fun features(map: MapLibreMap): List<Feature> = map.style?.getSourceAs<GeoJsonSource>("craft-map-overlays")
        ?.querySourceFeatures(null).orEmpty().distinctBy { it.getStringProperty("craftOverlayId") }

    private fun textViews(view: View): List<TextView> = (if (view is TextView) listOf(view) else emptyList()) +
        (if (view is ViewGroup) (0 until view.childCount).flatMap { textViews(view.getChildAt(it)) } else emptyList())

    private fun evidence(name: String) {
        val output = InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")
            ?: throw AssertionError("Gradle native map evidence directory unavailable")
        val directory = File(output, "native-maps").apply { mkdirs() }
        val image = instrumentation.uiAutomation.takeScreenshot() ?: throw AssertionError("Native screenshot unavailable")
        File(directory, "$name.png").outputStream().use { image.compress(Bitmap.CompressFormat.PNG, 100, it) }
        image.recycle()
    }

    private fun withMap(block: (MainActivity, CraftNativeMapView, MapView, MapLibreMap, AtomicInteger) -> Unit) {
        val activity = instrumentation.startActivitySync(Intent(instrumentation.targetContext, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)) as MainActivity
        lateinit var host: CraftNativeMapView
        var hostCreated = false
        lateinit var widget: MapView
        lateinit var map: MapLibreMap
        val ready = CountDownLatch(1)
        val loaded = AtomicInteger()
        try {
            main {
                host = CraftNativeMapView(activity)
                hostCreated = true
                widget = host.getChildAt(0) as MapView
                widget.addOnDidFinishLoadingMapListener { loaded.incrementAndGet() }
                host.configure(props(), overlays()) {}
                activity.setContentView(host)
                widget.getMapAsync { map = it; ready.countDown() }
            }
            assertTrue("The real native map did not initialize", ready.await(20, TimeUnit.SECONDS))
            awaitState("Native map did not render its recorded overlays") {
                features(map).map { it.getStringProperty("craftOverlayId") }.toSet() == setOf("route", "start", "direction") &&
                    map.queryRenderedFeatures(map.projection.toScreenLocation(LatLng(47.005, 11.005)), "craft-map-directions").isNotEmpty()
            }
            block(activity, host, widget, map, loaded)
        } finally {
            main { if (hostCreated) { host.destroy(); host.destroy() }; activity.finish() }
        }
    }

    @Test
    fun keyFreeBasemapsKeepTheRecordedRouteAndDirectionSignsVisible() = withMap { _, host, _, map, loaded ->
        for (type in listOf("outdoors", "standard", "satellite", "hybrid")) {
            val before = loaded.get()
            main {
                val options = props().put("mapType", if (type == "outdoors") "standard" else type)
                if (type == "outdoors") options.put("tileOverlay", JSONObject()
                    .put("urlTemplate", "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}")
                    .put("attribution", "Topography: Esri, USGS, NOAA, OpenStreetMap contributors"))
                host.configure(options, overlays()) {}
            }
            awaitState("$type did not finish loading its real native basemap") {
                loaded.get() > before && features(map).size == 3 &&
                    map.queryRenderedFeatures(map.projection.toScreenLocation(LatLng(47.005, 11.005)), "craft-map-directions").isNotEmpty()
            }
            main {
                val start = features(map).first { it.getStringProperty("craftOverlayId") == "start" }.geometry() as Point
                assertEquals(47.0, start.latitude(), 0.000001)
                assertEquals(11.0, start.longitude(), 0.000001)
                assertEquals(90.0, features(map).first { it.getStringProperty("craftOverlayId") == "direction" }.getNumberProperty("bearing").toDouble(), 0.001)
                assertTrue("Provider attribution must remain visible", textViews(host).any { it.visibility == View.VISIBLE && (it.text.contains("Esri") || it.text.contains("OpenStreetMap")) })
                for (point in listOf(LatLng(47.0, 11.0), LatLng(47.01, 11.01))) {
                    val screen = map.projection.toScreenLocation(point)
                    val density = host.resources.displayMetrics.density
                    assertTrue("Route must stay below floating top controls", screen.y >= 88 * density - 8)
                    assertTrue("Route must stay above the floating profile", screen.y <= host.height - 180 * density + 8)
                }
            }
            evidence("map-$type")
        }
    }

    @Test
    fun nativeMapMutationsUpdateThePinAndCameraWithoutReloadingTheStyle() = withMap { _, host, _, map, _ ->
        val style = main { map.style }
        main { host.configure(props().put("pitchEnabled", true).put("cameraPitch", 30).put("cameraHeading", 90), overlays("#2878c8")) {} }
        awaitState("The native map did not apply camera and pin mutations") {
            val pin = features(map).firstOrNull { it.getStringProperty("craftOverlayId") == "start" }
            pin?.getStringProperty("color") == "rgba(40,120,200,1.0)" &&
                kotlin.math.abs(map.cameraPosition.bearing - 90) < 1 && kotlin.math.abs(map.cameraPosition.tilt - 30) < 1 &&
                map.queryRenderedFeatures(map.projection.toScreenLocation(LatLng(47.0, 11.0)), "craft-map-markers").any { it.getStringProperty("color") == "rgba(40,120,200,1.0)" }
        }
        main {
            assertSame("Overlay updates must not reload the native basemap", style, map.style)
            assertTrue(map.uiSettings.isTiltGesturesEnabled)
            assertTrue(map.uiSettings.isCompassEnabled)
            assertEquals(3, features(map).size)
        }
        // Inspect the actual rendered pin, not just the JSON property sent to GL.
        val location = main {
            val screen = map.projection.toScreenLocation(LatLng(47.0, 11.0))
            val origin = IntArray(2).also { host.getLocationOnScreen(it) }
            (screen.x.toInt() + origin[0]) to (screen.y.toInt() + origin[1])
        }
        val image = instrumentation.uiAutomation.takeScreenshot() ?: throw AssertionError("Native screenshot unavailable")
        try {
            val pixel = image.getPixel(location.first, location.second)
            assertEquals(40.0, Color.red(pixel).toDouble(), 8.0)
            assertEquals(120.0, Color.green(pixel).toDouble(), 8.0)
            assertEquals(200.0, Color.blue(pixel).toDouble(), 8.0)
        } finally { image.recycle() }
        evidence("map-mutated-pin-and-camera")
    }

    @Test
    fun showingTheLocationDotDoesNotRequestPermissionDuringRendering() = withMap { activity, host, _, map, _ ->
        assertEquals(PackageManager.PERMISSION_DENIED, activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION))
        main {
            host.configure(props().put("showsUserLocation", true), overlays()) {}
            assertFalse(map.locationComponent.isLocationComponentActivated)
        }
        instrumentation.uiAutomation.waitForIdle(500, 5_000)
        assertEquals("Rendering a map must not open a permission dialog", activity.packageName, instrumentation.uiAutomation.rootInActiveWindow?.packageName?.toString())
        evidence("map-location-permission-not-requested")
    }
}
