package dev.craft.navigationtest

import android.content.Context
import android.graphics.Color
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.swiperefreshlayout.widget.CircularProgressDrawable
import android.widget.LinearLayout
import android.widget.TextView
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import java.util.concurrent.atomic.AtomicInteger
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeFlatListTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    @Test
    fun celebrationIsFiniteReplayableAndHonorsReducedMotion() {
        // The protocol CI leg removes system animations; native navigation
        // legs keep them on. Exercise the real policy in both configurations.
        val motionEnabled = android.animation.ValueAnimator.areAnimatorsEnabled()
        val firstStart = if (motionEnabled) 1 else 0
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        lateinit var celebration: CraftNativeCelebration
        lateinit var card: View
        scenario.onActivity { activity ->
            val host = FrameLayout(activity)
            activity.setContentView(host)
            card = View(activity)
            host.addView(card, FrameLayout.LayoutParams(300, 240))
            celebration = CraftNativeCelebration(card)
        }
        instrumentation.waitForIdleSync()
        scenario.onActivity {
            val request = JSONObject().put("replay", 0)
            celebration.configure(request, 20f)
            celebration.layout()
            assertEquals(firstStart, celebration.starts)
            assertEquals(motionEnabled, celebration.isRunning)
            celebration.configure(request, 20f)
            celebration.layout()
            assertEquals(firstStart, celebration.starts)
            celebration.stop()
            assertTrue(!celebration.isRunning)
            celebration.configure(JSONObject().put("replay", 1), 20f)
            celebration.layout(false)
            assertEquals(firstStart, celebration.starts)
            celebration.layout(true)
            assertEquals(firstStart, celebration.starts)
            celebration.configure(JSONObject().put("replay", 2).put("enabled", false), 20f)
            celebration.layout(true)
            assertEquals(firstStart, celebration.starts)
            celebration.configure(JSONObject().put("replay", -1), 20f)
            celebration.layout(true)
            assertEquals(firstStart, celebration.starts)
            celebration.configure(JSONObject().put("replay", 3), 20f)
            celebration.layout()
            assertEquals(firstStart * 2, celebration.starts)
        }
        SystemClock.sleep(3300)
        scenario.onActivity { assertTrue(!celebration.isRunning) }
        scenario.close()
    }

    private fun findImage(view: View): ImageView? {
        if (view is ImageView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findImage(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private fun row(index: Int): JSONObject = JSONObject()
        .put("id", "row-$index")
        .put("type", "Text")
        .put("children", JSONArray().put("Row $index"))

    private fun chrome(id: String, role: String): JSONObject = JSONObject()
        .put("id", id)
        .put("type", "Text")
        .put("props", JSONObject().put("listRole", role))
        .put("children", JSONArray().put(role))

    private fun awaitCount(list: CraftNativeFlatList, expected: Int) {
        repeat(100) {
            if (list.adapter?.itemCount == expected) return
            SystemClock.sleep(50)
        }
        throw AssertionError("Timed out waiting for $expected FlatList cells; found ${list.adapter?.itemCount}")
    }

    private fun attach(list: CraftNativeFlatList) {
        list.layoutParams = FrameLayout.LayoutParams(320, 480)
        val width = View.MeasureSpec.makeMeasureSpec(320, View.MeasureSpec.EXACTLY)
        val height = View.MeasureSpec.makeMeasureSpec(480, View.MeasureSpec.EXACTLY)
        list.measure(width, height)
        list.layout(0, 0, 320, 480)
    }

    private fun launchHost(): Pair<ActivityScenario<MainActivity>, CraftNativeFlatList> {
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        lateinit var list: CraftNativeFlatList
        scenario.onActivity { activity ->
            val host = FrameLayout(activity)
            activity.setContentView(host)
            list = CraftNativeFlatList(activity)
            host.addView(list)
            attach(list)
        }
        return scenario to list
    }

    private fun renderer(context: Context, renders: AtomicInteger): CraftNativeRenderItem =
        { node, _, previous ->
            renders.incrementAndGet()
            (previous as? TextView ?: TextView(context)).apply {
                text = node.optJSONArray("children")?.optString(0).orEmpty()
                minHeight = 44
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
            }
        }

    @Test
    fun recyclesTenThousandRowsAndRetainsTheViewport() {
        val context = instrumentation.targetContext
        lateinit var list: CraftNativeFlatList
        val renders = AtomicInteger()
        val rows = (0 until 10_000).map(::row)
        instrumentation.runOnMainSync {
            list = CraftNativeFlatList(context)
            attach(list)
            list.apply(rows, false, 1, false, 0.1, renderer(context, renders), { _ -> }, null)
        }
        awaitCount(list, 10_000)
        instrumentation.runOnMainSync {
            attach(list)
            list.scrollToPosition(5_000)
            attach(list)
        }
        SystemClock.sleep(300)

        val before = (list.layoutManager as LinearLayoutManager).findFirstVisibleItemPosition()
        assertTrue("RecyclerView materialized too many of 10,000 rows", renders.get() < 200)
        assertTrue("RecyclerView did not reach the requested viewport", before >= 4_900)

        val moved = listOf(rows[1], rows[0]) + rows.drop(2)
        instrumentation.runOnMainSync {
            list.apply(moved, false, 1, false, 0.1, renderer(context, renders), { _ -> }, null)
        }
        awaitCount(list, 10_000)
        instrumentation.runOnMainSync { attach(list) }
        SystemClock.sleep(500)
        val after = (list.layoutManager as LinearLayoutManager).findFirstVisibleItemPosition()
        assertTrue("keyed update reset the viewport", after >= 4_900)
        assertTrue("keyed update rendered the full data set", renders.get() < 400)
    }

    @Test
    fun forwardsScrollAndMomentumCallbacks() {
        val (scenario, list) = launchHost()
        val context = list.context
        val scrollCount = AtomicInteger()
        val momentumBeginCount = AtomicInteger()
        val momentumEndCount = AtomicInteger()
        val rows = (0 until 100).map(::row)
        try {
            instrumentation.runOnMainSync {
                list.onScrollEvent = { scrollCount.incrementAndGet() }
                list.onMomentumScrollBegin = { momentumBeginCount.incrementAndGet() }
                list.onMomentumScrollEnd = { momentumEndCount.incrementAndGet() }
                list.apply(rows, false, 1, false, 0.1, renderer(context, AtomicInteger()), { _ -> }, null)
            }
            awaitCount(list, 100)
            instrumentation.runOnMainSync {
                attach(list)
                list.smoothScrollToPosition(99)
            }
            repeat(50) {
                if (momentumEndCount.get() > 0) return@repeat
                SystemClock.sleep(50)
            }
            assertTrue("RecyclerView did not emit scroll callbacks", scrollCount.get() > 0)
            assertEquals(1, momentumBeginCount.get())
            assertEquals(1, momentumEndCount.get())
        } finally {
            scenario.close()
        }
    }

    @Test
    fun configuresHorizontalGridInvertedAndChromeOnlyLists() {
        val context = instrumentation.targetContext
        lateinit var list: CraftNativeFlatList
        val renders = AtomicInteger()
        val nodes = listOf(chrome("header", "header")) + (0 until 8).map(::row)
        instrumentation.runOnMainSync {
            list = CraftNativeFlatList(context)
            attach(list)
            list.apply(nodes, true, 1, true, 0.1, renderer(context, renders), { _ -> }, null)
        }
        awaitCount(list, 9)
        val horizontal = list.layoutManager as LinearLayoutManager
        assertEquals(LinearLayoutManager.HORIZONTAL, horizontal.orientation)
        val invertedIdentities = list.visibleItemIdentities
        assertEquals("row-7", invertedIdentities.first())
        assertEquals("mounted identities must stay in adapter order", invertedIdentities, invertedIdentities.sortedBy { it.substringAfter('-').toInt() })

        instrumentation.runOnMainSync {
            list.apply(nodes, false, 3, false, 0.1, renderer(context, renders), { _ -> }, null)
        }
        awaitCount(list, 9)
        SystemClock.sleep(200)
        val grid = list.layoutManager as GridLayoutManager
        assertEquals(3, grid.spanCount)
        assertEquals(3, grid.spanSizeLookup.getSpanSize(0))
        assertEquals(1, grid.spanSizeLookup.getSpanSize(1))

        val updated = listOf(chrome("header", "header"), row(0).put("children", JSONArray().put("Updated"))) +
            (1 until 8).map(::row)
        instrumentation.runOnMainSync {
            list.apply(updated, false, 3, false, 0.1, renderer(context, renders), { _ -> }, null)
        }
        SystemClock.sleep(300)
        instrumentation.runOnMainSync { attach(list) }

        val chromeEndReached = AtomicInteger()
        val chromeOnly = listOf(
            chrome("header", "header"),
            chrome("empty", "empty"),
            chrome("footer", "footer"),
        )
        instrumentation.runOnMainSync {
            list.apply(chromeOnly, false, 1, false, 0.1, renderer(context, renders), { _ -> }, {
                chromeEndReached.incrementAndGet()
            })
        }
        awaitCount(list, 3)
        SystemClock.sleep(300)
        assertEquals("chrome-only lists must not reach the data end", 0, chromeEndReached.get())
    }

    @Test
    fun appliesScrollIndicatorsAndBounceAxes() {
        val context = instrumentation.targetContext
        val list = CraftNativeFlatList(context)
        list.setScrollIndicators(vertical = false, horizontal = true)
        list.setBounceOptions(enabled = true, vertical = false, horizontal = true)
        assertTrue("vertical indicator should be hidden", !list.isVerticalScrollBarEnabled)
        assertTrue("horizontal indicator should be visible", list.isHorizontalScrollBarEnabled)
        assertEquals(View.OVER_SCROLL_NEVER, list.overScrollMode)
        list.apply(emptyList(), true, 1, false, 0.1, renderer(context, AtomicInteger()), { _ -> }, null)
        list.setBounceOptions(enabled = true, vertical = false, horizontal = true)
        assertEquals(View.OVER_SCROLL_ALWAYS, list.overScrollMode)
        list.setBounceOptions(enabled = false, vertical = true, horizontal = true)
        assertEquals(View.OVER_SCROLL_NEVER, list.overScrollMode)
    }

    @Test
    fun preservesRowTouchTargetsWhenScrollingIsDisabled() {
        val list = CraftNativeFlatList(instrumentation.targetContext)
        list.setScrollEnabled(false)
        assertTrue("scrollEnabled should be false", !list.isScrollEnabledForTest)
        list.setScrollEnabled(true)
        assertTrue("scrollEnabled should be restored", list.isScrollEnabledForTest)
    }

    @Test
    fun nonScrollingListMeasuresItsFullContentHeight() {
        val context = instrumentation.targetContext
        val list = CraftNativeFlatList(context)
        val rows = (0 until 3).map(::row)
        val contentSizeChanges = AtomicInteger()
        instrumentation.runOnMainSync {
            list.setScrollEnabled(false)
            list.onContentSizeChanged = { contentSizeChanges.incrementAndGet() }
            list.apply(rows, false, 1, false, 0.1, renderer(context, AtomicInteger()), { _ -> }, null)
        }
        awaitCount(list, rows.size)
        instrumentation.runOnMainSync {
            list.measure(
                View.MeasureSpec.makeMeasureSpec(320, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(1_000, View.MeasureSpec.AT_MOST),
            )
            list.layout(0, 0, list.measuredWidth, list.measuredHeight)
        }
        assertTrue("non-scrolling FlatList should include every row", list.measuredHeight >= rows.size * 44)
        repeat(100) {
            if (contentSizeChanges.get() > 0) return@repeat
            SystemClock.sleep(10)
        }
        assertTrue("non-scrolling FlatList should report content-size changes", contentSizeChanges.get() > 0)
    }

    @Test
    fun appliesPagingToNativeList() {
        val list = CraftNativeFlatList(instrumentation.targetContext)
        list.setPagingEnabled(true)
        assertTrue("paging should be enabled", list.isPagingEnabledForTest)
        list.setPagingEnabled(false)
        assertTrue("paging should be disabled", !list.isPagingEnabledForTest)
    }

    @Test
    fun refreshAppearanceUsesTheScreenContrastFallback() {
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        lateinit var host: CraftNativeRefreshableFlatList
        lateinit var indicator: ImageView
        try {
            scenario.onActivity { activity ->
                val root = FrameLayout(activity)
                activity.setContentView(root)
                host = CraftNativeRefreshableFlatList(activity)
                root.addView(host, FrameLayout.LayoutParams(320, 480))
                host.measure(
                    View.MeasureSpec.makeMeasureSpec(320, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(480, View.MeasureSpec.EXACTLY),
                )
                host.layout(0, 0, 320, 480)
                host.setRefreshAppearance(JSONObject(), Color.BLACK)
                indicator = findImage(host) ?: throw AssertionError("refresh indicator did not mount")
            }
            assertEquals(Color.BLACK, (indicator.drawable as CircularProgressDrawable).colorSchemeColors.single())
            instrumentation.runOnMainSync {
                host.setRefreshAppearance(JSONObject().put("tintColor", "#123456"), Color.WHITE)
            }
            assertEquals(Color.rgb(0x12, 0x34, 0x56), (indicator.drawable as CircularProgressDrawable).colorSchemeColors.single())
            instrumentation.runOnMainSync {
                host.setRefreshAppearance(JSONObject().put("tintColor", "not-a-color"), Color.WHITE)
            }
            assertEquals("invalid refresh tint should use the screen fallback", Color.WHITE, (indicator.drawable as CircularProgressDrawable).colorSchemeColors.single())
            instrumentation.runOnMainSync { host.setRefreshAppearance(JSONObject(), Color.WHITE) }
            assertEquals(Color.WHITE, (indicator.drawable as CircularProgressDrawable).colorSchemeColors.single())
        } finally {
            scenario.close()
        }
    }

    @Test
    fun acceptsVirtualizedScrollTargets() {
        val list = CraftNativeFlatList(instrumentation.targetContext)
        list.setScrollTarget(JSONObject().put("id", "row").put("key", "first"))
        assertTrue("scroll target should remain pending until rows mount", list.isScrollTargetPendingForTest)
        list.setScrollTarget(null)
        assertTrue("clearing the target should cancel pending work", !list.isScrollTargetPendingForTest)
    }

    @Test
    fun usesRenderedHeightsForVariableRows() {
        val context = instrumentation.targetContext
        lateinit var list: CraftNativeFlatList
        val rows = listOf(row(0), row(1).put("children", JSONArray().put("Tall\nrow\ncontent\ncontent")))
        instrumentation.runOnMainSync {
            list = CraftNativeFlatList(context)
            attach(list)
            list.apply(
                rows,
                false,
                1,
                false,
                0.1,
                { node, _, previous ->
                    (previous as? TextView ?: TextView(context)).apply {
                        text = node.optJSONArray("children")?.optString(0).orEmpty()
                        minHeight = 0
                        layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            if (text.contains('\n')) 120 else 24,
                        )
                    }
                },
                { _ -> },
                null,
            )
        }
        awaitCount(list, 2)
        instrumentation.runOnMainSync { attach(list) }
        val short = list.findViewHolderForAdapterPosition(0)?.itemView
            ?: throw AssertionError("short row did not mount")
        val tall = list.findViewHolderForAdapterPosition(1)?.itemView
            ?: throw AssertionError("tall row did not mount")
        assertTrue("rendered row height was not retained", tall.height > short.height + 20)
    }

    @Test
    fun verticalRowsFillTheListWidthWhenNoWidthIsAuthored() {
        val context = instrumentation.targetContext
        lateinit var list: CraftNativeFlatList
        val rows = listOf(row(0), row(1))
        instrumentation.runOnMainSync {
            list = CraftNativeFlatList(context)
            attach(list)
            list.apply(
                rows,
                false,
                1,
                false,
                0.1,
                { node, _, previous ->
                    (previous as? TextView ?: TextView(context)).apply {
                        text = node.optJSONArray("children")?.optString(0).orEmpty()
                        layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                        )
                    }
                },
                { _ -> },
                null,
            )
        }
        awaitCount(list, 2)
        instrumentation.runOnMainSync { attach(list) }
        val holder = list.findViewHolderForAdapterPosition(0)
            ?: throw AssertionError("first row did not mount")
        val hosted = (holder.itemView as ViewGroup).getChildAt(0)
            ?: throw AssertionError("first row root did not mount")
        assertEquals("vertical row root should fill its cell", list.width, hosted.width)
    }

    @Test
    fun horizontalRowsKeepIntrinsicWidthWhenNoWidthIsAuthored() {
        val context = instrumentation.targetContext
        lateinit var list: CraftNativeFlatList
        val rows = listOf(
            row(0).put("children", JSONArray().put("short")),
            row(1).put("children", JSONArray().put("a much longer horizontal row")),
        )
        instrumentation.runOnMainSync {
            list = CraftNativeFlatList(context)
            attach(list)
            list.apply(
                rows,
                true,
                1,
                false,
                0.1,
                { node, _, previous ->
                    (previous as? TextView ?: TextView(context)).apply {
                        text = node.optJSONArray("children")?.optString(0).orEmpty()
                        minWidth = 0
                        layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        )
                    }
                },
                { _ -> },
                null,
            )
        }
        awaitCount(list, 2)
        instrumentation.runOnMainSync { attach(list) }
        SystemClock.sleep(200)
        val short = list.findViewHolderForAdapterPosition(0)?.itemView
            ?: throw AssertionError("short horizontal row did not mount")
        val long = list.findViewHolderForAdapterPosition(1)?.itemView
            ?: throw AssertionError("long horizontal row did not mount")
        val shortHosted = (short as ViewGroup).getChildAt(0)
            ?: throw AssertionError("short horizontal row root did not mount")
        val longHosted = (long as ViewGroup).getChildAt(0)
            ?: throw AssertionError("long horizontal row root did not mount")
        assertTrue("short horizontal row was stretched to the viewport", shortHosted.width < list.width)
        assertTrue("long horizontal row did not grow intrinsically", longHosted.width > shortHosted.width + 20)
    }
}
