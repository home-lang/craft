package dev.craft.navigationtest

import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.SystemClock
import android.text.InputFilter
import android.text.InputType
import android.text.Layout
import android.text.Spanned
import android.text.style.ReplacementSpan
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.inputmethod.EditorInfo
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.accessibility.AccessibilityNodeInfo
import android.webkit.WebView
import android.widget.Button
import android.widget.CheckBox
import android.widget.DatePicker
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import android.widget.TimePicker
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import androidx.core.view.ViewCompat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

@RunWith(AndroidJUnit4::class)
class NativeNavigationTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    private fun find(view: View, id: String): View? {
        if (view.tag?.toString() == id || view.contentDescription?.toString() == id) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                find(view.getChildAt(index), id)?.let { return it }
            }
        }
        return null
    }

    private fun findAll(view: View, id: String, matches: MutableList<View>) {
        if (view.tag?.toString() == id || view.contentDescription?.toString() == id) matches += view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) findAll(view.getChildAt(index), id, matches)
        }
    }

    private fun containsType(view: View, type: Class<out View>): Boolean {
        if (type.isInstance(view)) return true
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                if (containsType(view.getChildAt(index), type)) return true
            }
        }
        return false
    }

    private fun <T : View> findType(view: View, type: Class<T>): T? {
        if (type.isInstance(view)) return type.cast(view)
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findType(view.getChildAt(index), type)?.let { return it }
            }
        }
        return null
    }

    private fun awaitHorizontalScroller(activity: MainActivity, id: String): android.widget.HorizontalScrollView {
        repeat(75) {
            var matching: android.widget.HorizontalScrollView? = null
            instrumentation.runOnMainSync {
                val host = find(activity.window.decorView, id)
                val scroller = host?.let { findType(it, android.widget.HorizontalScrollView::class.java) }
                val child = scroller?.getChildAt(0)
                if (scroller != null && child != null && scroller.width > 0 && scroller.height > 0 && child.width > 0) {
                    matching = scroller
                }
            }
            if (matching != null) return matching!!
            SystemClock.sleep(100)
        }
        val host = awaitView(activity, id)
        val scroller = findType(host, android.widget.HorizontalScrollView::class.java)
            ?: throw AssertionError("$id did not contain an Android HorizontalScrollView")
        val child = scroller.getChildAt(0)
        throw AssertionError(
            "$id horizontal scroller did not lay out " +
                "(viewport=${scroller.width}x${scroller.height}, " +
                "content=${child?.width ?: 0}x${child?.height ?: 0})"
        )
    }

    private fun containsWebView(view: View): Boolean {
        if (view is WebView) return true
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                if (containsWebView(view.getChildAt(index))) return true
            }
        }
        return false
    }

    private fun awaitView(activity: MainActivity, id: String, matches: (View) -> Boolean = { true }): View {
        repeat(75) {
            var found: View? = null
            instrumentation.runOnMainSync { found = find(activity.window.decorView, id)?.takeIf(matches) }
            if (found != null) return found!!
            SystemClock.sleep(200)
        }
        var tree = ""
        instrumentation.runOnMainSync { tree = describe(activity.window.decorView) }
        throw AssertionError("Timed out waiting for native control $id. View tree: $tree")
    }

    private fun describe(view: View): String {
        val own = "${view.javaClass.simpleName}[${view.contentDescription}]" +
            if (view is TextView) "=${view.text}" else ""
        if (view !is ViewGroup) return own
        return own + (0 until view.childCount).joinToString(prefix = "(", postfix = ")") {
            describe(view.getChildAt(it))
        }
    }

    private fun click(activity: MainActivity, id: String) {
        val view = awaitView(activity, id)
        assertTrue("$id is not an Android Button", view is Button)
        instrumentation.runOnMainSync { view.performClick() }
    }

    private fun pullToRefresh(host: SwipeRefreshLayout) {
        var ready = false
        for (attempt in 0 until 75) {
            instrumentation.runOnMainSync { ready = host.isLaidOut && host.width > 0 && host.height > 0 }
            if (ready) break
            SystemClock.sleep(100)
        }
        assertTrue("pull-to-refresh host did not lay out", ready)
        instrumentation.runOnMainSync {
            val downTime = SystemClock.uptimeMillis()
            val x = host.width / 2f
            val startY = 2f
            val endY = (host.height * 0.9f).coerceAtLeast(240f * host.resources.displayMetrics.density)
            val down = MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, x, startY, 0)
            host.dispatchTouchEvent(down)
            down.recycle()
            for (step in 1..8) {
                val y = startY + (endY - startY) * step / 8f
                val move = MotionEvent.obtain(downTime, downTime + step * 16, MotionEvent.ACTION_MOVE, x, y, 0)
                host.dispatchTouchEvent(move)
                move.recycle()
            }
            val up = MotionEvent.obtain(downTime, downTime + 144, MotionEvent.ACTION_UP, x, endY, 0)
            host.dispatchTouchEvent(up)
            up.recycle()
        }
    }

    private fun swipeTab(activity: MainActivity, left: Boolean) {
        val chrome = findType(activity.window.decorView, CraftNativeChrome::class.java)
            ?: throw AssertionError("native chrome did not mount")
        // The hosted emulator cannot inject a window-targeted touchscreen
        // sequence reliably. Drive the same public callbacks that the shell's
        // touch interceptor invokes, retaining the real interactive transition
        // and leaving touch ownership covered by the source contract.
        val y = chrome.content.top + chrome.content.height * 0.85f
        val startX = if (left) chrome.width * 0.8f else chrome.width * 0.2f
        val endX = if (left) chrome.width * 0.2f else chrome.width * 0.8f
        val deltaX = endX - startX
        instrumentation.runOnMainSync {
            val started = chrome.onTabSwipeStart?.invoke(deltaX, startX, y) == true
            assertTrue("native tab swipe did not start", started)
            if (left) {
                val roots = mutableListOf<View>()
                findAll(chrome.content, "root", roots)
                val incoming = roots.maxByOrNull { kotlin.math.abs((it.parent as? View)?.translationX ?: 0f) }
                assertTrue(
                    "incoming SafeAreaView did not receive window insets before tab swipe movement",
                    incoming != null && incoming.paddingTop >= (16 * activity.resources.displayMetrics.density).toInt(),
                )
            }
            listOf(0.25f, 0.5f, 0.75f, 1f).forEach { fraction ->
                chrome.onTabSwipeMove?.invoke(deltaX * fraction)
            }
            chrome.onTabSwipeEnd?.invoke(deltaX, false)
        }
    }

    private fun awaitText(activity: MainActivity, id: String, expected: String): TextView {
        var actual = "<missing>"
        repeat(75) {
            var matching: TextView? = null
            instrumentation.runOnMainSync {
                val view = find(activity.window.decorView, id)
                actual = (view as? TextView)?.text?.toString() ?: "<missing>"
                if (view is TextView && view.text.toString() == expected) matching = view
            }
            if (matching != null) return matching!!
            SystemClock.sleep(100)
        }
        throw AssertionError("Timed out waiting for $id to read $expected (actual: $actual)")
    }

    private fun awaitLayoutWidth(activity: MainActivity, id: String, expected: Double): Double {
        val density = activity.resources.displayMetrics.density.toDouble()
        var actual = ""
        repeat(75) {
            var reported: Double? = null
            instrumentation.runOnMainSync {
                actual = (find(activity.window.decorView, id) as? TextView)?.text?.toString().orEmpty()
                reported = actual.removePrefix("Layout width: ").toDoubleOrNull()
            }
            // Native layout uses whole physical pixels. At fractional display
            // densities, a logical 180dp need not report the integer 180.
            if (reported != null && kotlin.math.abs(reported!! - expected) < 1.0 / density) return reported!!
            SystemClock.sleep(100)
        }
        throw AssertionError("Timed out waiting for $id near $expected dp; got '$actual' at density $density")
    }

    private fun awaitProgressBar(
        activity: MainActivity,
        id: String,
        expected: String,
        predicate: (ProgressBar) -> Boolean,
    ): ProgressBar {
        repeat(75) {
            var matching: ProgressBar? = null
            instrumentation.runOnMainSync {
                val view = find(activity.window.decorView, id)
                if (view is ProgressBar && predicate(view)) matching = view
            }
            if (matching != null) return matching!!
            SystemClock.sleep(100)
        }
        throw AssertionError("Timed out waiting for $id to be $expected")
    }

    private fun awaitImageTintCleared(activity: MainActivity, id: String): ImageView {
        repeat(75) {
            var matching: ImageView? = null
            instrumentation.runOnMainSync {
                val view = find(activity.window.decorView, id)
                if (view is ImageView && view.colorFilter == null) matching = view
            }
            if (matching != null) return matching!!
            SystemClock.sleep(100)
        }
        throw AssertionError("Timed out waiting for $id tint to clear")
    }

    private fun awaitLayoutIncrease(activity: MainActivity, id: String, baseline: Int): TextView {
        repeat(75) {
            var matching: TextView? = null
            instrumentation.runOnMainSync {
                val view = find(activity.window.decorView, id)
                if (view is TextView && view.text.toString().substringAfterLast(": ").toIntOrNull()?.let { it > baseline } == true) {
                    matching = view
                }
            }
            if (matching != null) return matching!!
            SystemClock.sleep(100)
        }
        throw AssertionError("Timed out waiting for $id layout count to exceed $baseline")
    }

    private fun awaitWidthDecrease(view: View, from: Int, amount: Int, density: Float) {
        repeat(75) {
            var settled = false
            instrumentation.runOnMainSync {
                settled = view.width < from - (amount * density).toInt()
            }
            if (settled) return
            SystemClock.sleep(100)
        }
        throw AssertionError("width did not settle below ${from - (amount * density).toInt()}, was ${view.width}")
    }

    private fun backgroundColor(view: View): Int? =
        (view.background as? GradientDrawable)?.color?.defaultColor

    private fun awaitBackgroundColor(view: View, previous: Int?): Int {
        repeat(75) {
            var current: Int? = null
            instrumentation.runOnMainSync { current = backgroundColor(view) }
            if (current != null && current != previous) return current!!
            SystemClock.sleep(100)
        }
        throw AssertionError("native theme probe did not change background")
    }

    private fun assertNoWebView(activity: MainActivity) {
        var present = false
        instrumentation.runOnMainSync { present = containsWebView(activity.window.decorView) }
        assertFalse("Native STX route created a WebView instance", present)
    }

    private fun assertScrolls(scroll: ScrollView) {
        var viewportHeight = 0
        var contentHeight = 0
        repeat(50) {
            var moved = false
            instrumentation.runOnMainSync {
                viewportHeight = scroll.height
                contentHeight = scroll.getChildAt(0)?.height ?: 0
                if (contentHeight > viewportHeight) {
                    scroll.scrollTo(0, contentHeight - viewportHeight)
                    moved = scroll.scrollY > 0
                }
            }
            if (moved) return
            SystemClock.sleep(100)
        }
        throw AssertionError(
            "native ScrollView did not move through overflow content " +
                "(viewport=$viewportHeight, content=$contentHeight, offset=${scroll.scrollY})"
        )
    }

    @Test
    fun compiledBundleRendersNavigatesAndRetainsNativeControls() {
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ) as MainActivity
        try {
            val homeState = awaitText(activity, "navigation-home-state", "Home state: Ada/0")
            click(activity, "navigation-increment")
            awaitText(activity, "navigation-home-state", "Home state: Ada/1")
            click(activity, "navigation-open-details")
            assertEquals("Details for Ada", (awaitView(activity, "details-title") as TextView).text.toString())
            click(activity, "details-back")
            awaitText(activity, "navigation-home-state", "Home state: Ada/1")
            assertEquals("Home state: Ada/1", homeState.text.toString())

            val carousel = awaitHorizontalScroller(activity, "tab-swipe-carousel")
            val carouselContent = carousel.getChildAt(0)
                ?: throw AssertionError("carousel did not mount a content child")
            assertTrue(
                "carousel content was not wider than its viewport (content=${carouselContent.width}, viewport=${carousel.width})",
                carouselContent.width > carousel.width,
            )
            assertTrue(
                "carousel should be able to consume a left swipe before the tab shell",
                carousel.canScrollHorizontally(1),
            )
            // Instrumentation cannot inject a targeted touchscreen event into
            // the app window on the hosted emulator. Exercise the same native
            // scroll range deterministically; the shell's gesture ownership is
            // covered by the source contract and the real device path.
            carousel.scrollTo(carousel.width, 0)
            assertTrue("carousel content did not scroll within its native range", carousel.scrollX > 0)
            swipeTab(activity, left = true)
            assertEquals("Details for ", (awaitView(activity, "details-title") as TextView).text.toString())
            swipeTab(activity, left = false)
            val name = awaitView(activity, "name-input")
            val root = awaitView(activity, "root")
            assertTrue("View did not render as LinearLayout", root is LinearLayout)
            val authoredRootPadding = (16 * activity.resources.displayMetrics.density).toInt()
            val initialRootTop = root.paddingTop
            val initialRootBottom = root.paddingBottom
            assertTrue("SafeAreaView did not retain its authored top padding", initialRootTop >= authoredRootPadding)
            click(activity, "toggle-safe-area")
            awaitText(activity, "safe-area-status", "Safe edges: bottom")
            assertSame("SafeAreaView edge updates replaced the root", root, awaitView(activity, "root"))
            assertEquals("Removing the top edge did not remove the window inset", authoredRootPadding, root.paddingTop)
            assertTrue("Removing the top edge changed the bottom inset", root.paddingBottom >= initialRootBottom)
            click(activity, "toggle-safe-area")
            awaitText(activity, "safe-area-status", "Safe edges: top,bottom")
            assertTrue("Restoring the top edge did not restore the window inset", root.paddingTop > authoredRootPadding)
            val rootHost = awaitView(activity, "native-root-scroll")
            val rootScroll = findType(rootHost, ScrollView::class.java)
                ?: throw AssertionError("native-root-scroll did not contain an Android ScrollView")
            val rootOverlay = awaitView(activity, "native-root-overlay")
            val overlayTopBeforeScroll = rootOverlay.top
            val overlayRightBeforeScroll = rootOverlay.right
            assertScrolls(rootScroll)
            assertEquals("root absolute sibling moved with ScrollView content", overlayTopBeforeScroll, rootOverlay.top)
            assertEquals("root absolute sibling changed horizontal position", overlayRightBeforeScroll, rootOverlay.right)
            instrumentation.runOnMainSync { rootScroll.scrollTo(0, 0) }
            val bubble = awaitView(activity, "max-content-bubble") as ViewGroup
            val bubbleText = awaitView(activity, "max-content-bubble-text") as TextView
            assertEquals("text took min-content width and wrapped unexpectedly", 1, bubbleText.lineCount)
            assertTrue("bubble did not retain its authored horizontal padding", bubble.width > bubbleText.width)
            assertTrue(name is EditText)
            val nameInput = name as EditText
            assertEquals("email keyboard must retain the text input class", InputType.TYPE_CLASS_TEXT, nameInput.inputType and InputType.TYPE_MASK_CLASS)
            assertEquals(Color.rgb(0x94, 0xa3, 0xb8), nameInput.hintTextColors.defaultColor)
            assertEquals(Color.rgb(0x22, 0xc5, 0x5e), nameInput.highlightColor)
            assertTrue(nameInput.filters.any { it is InputFilter.LengthFilter })
            assertEquals(
                InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS,
                nameInput.inputType and InputType.TYPE_MASK_VARIATION,
            )
            assertEquals(EditorInfo.IME_ACTION_DONE, nameInput.imeOptions and EditorInfo.IME_MASK_ACTION)
            click(activity, "toggle-input-colors")
            awaitText(activity, "input-style-status", "input colors off")
            assertSame("Removing input colors replaced the native field", nameInput, awaitView(activity, "name-input"))
            click(activity, "toggle-input-colors")
            awaitText(activity, "input-style-status", "input colors on")
            assertSame("Restoring input colors replaced the native field", nameInput, awaitView(activity, "name-input"))
            val notes = awaitView(activity, "notes-input")
            assertTrue("multiline TextInput should be an EditText", notes is EditText)
            assertFalse("multiline TextInput should not be single line", (notes as EditText).isSingleLine)
            assertEquals(3, notes.maxLines)
            assertEquals("Draft", (notes as EditText).text.toString())
            assertEquals("Notes", notes.hint.toString())
            assertEquals(Color.rgb(0x22, 0xc5, 0x5e), notes.highlightColor)
            val readonly = awaitView(activity, "readonly-input") as EditText
            assertTrue("editable=false should disable the native input", !readonly.isEnabled)
            assertEquals("Read only", readonly.text.toString())
            val password = awaitView(activity, "password-input") as EditText
            assertEquals(InputType.TYPE_TEXT_VARIATION_PASSWORD, password.inputType and InputType.TYPE_MASK_VARIATION)
            val title = awaitView(activity, "home-title")
            assertTrue(title is TextView)
            assertEquals(Color.WHITE, (title as TextView).currentTextColor)
            assertEquals("Text accessibility should use visible content, not its test identity", null, title.contentDescription)
            click(activity, "native-audio-context")
            awaitText(activity, "audio-context-status", "AudioContext ready")
            val disabled = awaitView(activity, "disabled-button") as Button
            assertFalse(disabled.isEnabled)
            val styled = awaitView(activity, "styled-row") as LinearLayout
            val styledFirst = awaitView(activity, "styled-first") as TextView
            val styledSecond = awaitView(activity, "styled-second") as TextView
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                assertTrue("explicit shadow offset did not install an outline", styled.outlineProvider !== ViewOutlineProvider.BACKGROUND)
            }
            val density = activity.resources.displayMetrics.density
            assertEquals(LinearLayout.HORIZONTAL, styled.orientation)
            assertTrue(styled.indexOfChild(styledSecond) < styled.indexOfChild(styledFirst))
            assertEquals((10 * density).toInt(), styled.paddingLeft)
            assertEquals((5 * density).toInt(), styled.paddingTop)
            assertEquals(0.75f, styled.alpha)
            assertEquals("transform translateX was not applied", (4 * density), styled.translationX, 1f)
            assertEquals("transform scaleX was not applied", 0.9f, styled.scaleX, 0.01f)
            assertEquals("transform rotate was not applied", 2f, styled.rotation, 0.1f)
            assertTrue("styled row should have laid out before skew drawing", styled.width > 0 && styled.height > 0)
            assertEquals("FIRST", styledFirst.text.toString())
            assertEquals(Color.rgb(0xfe, 0xdc, 0xba), styledFirst.currentTextColor)
            assertEquals(21f, styledFirst.textSize / density)
            assertTrue(styledFirst.typeface.style and Typeface.BOLD != 0)
            assertTrue(styledFirst.typeface.style and Typeface.ITALIC != 0)
            val decorations = (styledFirst.text as? Spanned)?.getSpans(0, styledFirst.text.length, ReplacementSpan::class.java).orEmpty()
            assertTrue("text decoration span was not applied", decorations.isNotEmpty())
            assertEquals((70 * density).toInt(), styledFirst.layoutParams.width)
            val gradient = awaitView(activity, "gradient-box")
            val gradientBackground = gradient.background as? GradientDrawable
            assertTrue("gradient fixture did not use a GradientDrawable", gradientBackground != null)
            assertEquals(GradientDrawable.Orientation.TL_BR, gradientBackground?.orientation)
            assertEquals(3, gradientBackground?.colors?.size)
            awaitView(activity, "grid-wrap")
            val gridFirst = awaitView(activity, "grid-first")
            val gridSecond = awaitView(activity, "grid-second")
            val gridThird = awaitView(activity, "grid-third")
            assertEquals(gridFirst.top, gridSecond.top)
            assertTrue("grid columns did not lay out side by side", gridSecond.left > gridFirst.left)
            assertTrue("grid rows did not advance after the first track", gridThird.top > gridFirst.top)
            val fractionalGrid = awaitView(activity, "grid-fractional-wrap")
            val fractionalFirst = awaitView(activity, "grid-fractional-first")
            val fractionalSecond = awaitView(activity, "grid-fractional-second")
            val fractionalThird = awaitView(activity, "grid-fractional-third")
            assertEquals(fractionalFirst.width, fractionalSecond.width)
            assertTrue("fractional grid columns overlapped", fractionalSecond.left > fractionalFirst.right)
            assertTrue("fractional grid overflowed its container", fractionalThird.right <= fractionalGrid.right)
            // A child's top and left are in its container's coordinates.
            val gridAlign = awaitView(activity, "grid-align-wrap")
            val gridAlignFirst = awaitView(activity, "grid-align-first")
            val gridAlignThird = awaitView(activity, "grid-align-third")
            assertTrue("grid alignContent did not center its rows", gridAlignFirst.top > (20 * density).toInt())
            val gridAspect = awaitView(activity, "grid-aspect-ratio-box")
            assertEquals((80 * density).toInt(), gridAspect.width)
            assertEquals((40 * density).toInt(), gridAspect.height)
            val gridPercentHeight = awaitView(activity, "grid-percent-height")
            assertEquals((40 * density).toInt(), gridPercentHeight.height)
            val gridEvenly = awaitView(activity, "grid-align-evenly-wrap")
            val gridEvenlyFirst = awaitView(activity, "grid-evenly-first")
            val gridEvenlyThird = awaitView(activity, "grid-evenly-third")
            assertTrue("grid space-evenly missed the leading slot", gridEvenlyFirst.top > (10 * density).toInt())
            assertTrue("grid space-evenly missed the inter-row slot", gridEvenlyThird.top - gridEvenlyFirst.top > (35 * density).toInt())
            val aspectRatioBox = awaitView(activity, "aspect-ratio-box")
            // 100 points is 262.5 pixels at 2.625: a pixel either way is rounding.
            assertEquals("aspectRatio width", 100.0 * density, aspectRatioBox.width.toDouble(), 1.0)
            assertEquals("aspectRatio height", 50.0 * density, aspectRatioBox.height.toDouble(), 1.0)
            val alignFirst = awaitView(activity, "align-content-first")
            val alignThird = awaitView(activity, "align-content-third")
            assertTrue("alignContent did not distribute wrapped lines", alignThird.top - alignFirst.top > (50 * density).toInt())
            awaitView(activity, "align-content-stretch-wrap")
            val stretchFirst = awaitView(activity, "align-stretch-first")
            val stretchThird = awaitView(activity, "align-stretch-third")
            assertTrue("alignContent stretch did not expand the first line", stretchFirst.height > (35 * density).toInt())
            assertTrue("alignContent stretch did not expand the line height", stretchThird.top - stretchFirst.top > (35 * density).toInt())
            val evenly = awaitView(activity, "align-content-evenly-wrap")
            val evenlyFirst = awaitView(activity, "align-evenly-first")
            val evenlyThird = awaitView(activity, "align-evenly-third")
            assertTrue("alignContent space-evenly missed the leading slot", evenlyFirst.top > (10 * density).toInt())
            assertTrue("alignContent space-evenly missed the inter-line slot", evenlyThird.top - evenlyFirst.top > (35 * density).toInt())
            val growFirst = awaitView(activity, "flex-grow-first")
            val growSecond = awaitView(activity, "flex-grow-second")
            assertTrue("flexGrow did not consume remaining main-axis space", growFirst.width > growSecond.width)
            val capped = awaitView(activity, "flex-bound-first")
            val redistributed = awaitView(activity, "flex-bound-second")
            assertEquals("maxWidth did not freeze the capped flex item", 64.0 * density, capped.width.toDouble(), 2.0 * density)
            assertTrue("remaining flex space was not redistributed", redistributed.width > capped.width + (40 * density).toInt())
            val justifyCenter = awaitView(activity, "justify-center-wrap")
            val justifyCenterFirst = awaitView(activity, "justify-center-first")
            val justifyCenterSecond = awaitView(activity, "justify-center-second")
            assertTrue("shared justify-center position was not applied", justifyCenterFirst.left > (20 * density).toInt())
            assertTrue("shared justify-center gap was not applied", justifyCenterSecond.left > justifyCenterFirst.right)
            val justifyBetween = awaitView(activity, "justify-between-wrap")
            val justifyBetweenFirst = awaitView(activity, "justify-between-first")
            val justifyBetweenSecond = awaitView(activity, "justify-between-second")
            assertTrue("shared space-between leading position was not applied", justifyBetweenFirst.left <= (20 * density).toInt())
            assertTrue("shared space-between trailing position was not applied", justifyBetweenSecond.right >= justifyBetween.width - (20 * density).toInt())
            val crossAxis = awaitView(activity, "cross-axis-wrap")
            val crossCenter = awaitView(activity, "cross-axis-center")
            val crossEnd = awaitView(activity, "cross-axis-end")
            assertTrue("alignItems center did not center the child", abs(crossCenter.top + crossCenter.height / 2 - crossAxis.height / 2) <= (3 * density).toInt())
            assertTrue("alignSelf flex-end did not move the child to the line end", crossEnd.top > crossCenter.top)
            val baseline = awaitView(activity, "baseline-wrap")
            val baselineLarge = awaitView(activity, "baseline-large")
            val baselineSmall = awaitView(activity, "baseline-small")
            assertTrue("baseline alignment did not lower the smaller label", baselineLarge.top < baselineSmall.top)
            val reverseColumn = awaitView(activity, "reverse-column") as LinearLayout
            val reverseColumnFirst = awaitView(activity, "reverse-column-first")
            val reverseColumnSecond = awaitView(activity, "reverse-column-second")
            assertEquals(LinearLayout.VERTICAL, reverseColumn.orientation)
            assertTrue("column-reverse did not invert the main axis", reverseColumnFirst.top > reverseColumnSecond.top)
            val reverseWrap = awaitView(activity, "reverse-wrap")
            val reverseWrapFirst = awaitView(activity, "reverse-wrap-first")
            val reverseWrapSecond = awaitView(activity, "reverse-wrap-second")
            val reverseWrapThird = awaitView(activity, "reverse-wrap-third")
            val reverseWrapFourth = awaitView(activity, "reverse-wrap-fourth")
            assertTrue("row-reverse did not reverse the first wrapped line", reverseWrapFirst.left > reverseWrapSecond.left)
            assertTrue("row-reverse did not reverse the second wrapped line", reverseWrapThird.left > reverseWrapFourth.left)
            assertTrue("row-reverse reversed wrapped line order", reverseWrapThird.top > reverseWrapFirst.top)
            assertTrue("row-reverse wrapped line escaped its container", reverseWrapFourth.bottom <= reverseWrap.bottom)
            val link = awaitView(activity, "native-link")
            assertTrue("native link should be a TextView", link is TextView)
            assertEquals("Open native link", (link as TextView).text.toString())
            assertTrue(link.contentDescription.toString().contains("ready"))
            assertEquals("Opens status", link.tooltipText)
            instrumentation.runOnMainSync { link.performClick() }
            awaitText(activity, "native-link-status", "link pressed")
            click(activity, "toggle-link-accessibility")
            awaitText(activity, "native-link-status", "link accessibility disabled")
            assertTrue("accessibilityState.disabled should disable the link", !link.isEnabled)
            click(activity, "toggle-link-accessibility")
            awaitText(activity, "native-link-status", "link accessibility enabled")
            assertTrue("clearing accessibilityState.disabled should restore the link", link.isEnabled)
            instrumentation.runOnMainSync { link.performClick() }
            awaitText(activity, "native-link-status", "link pressed")
            val panel = awaitView(activity, "native-panel")
            instrumentation.runOnMainSync { panel.performClick() }
            awaitText(activity, "native-link-status", "panel pressed")
            click(activity, "toggle-panel-accessibility")
            awaitText(activity, "native-link-status", "panel accessibility disabled")
            assertFalse("accessibilityState.disabled should disable a generic pressable", panel.isEnabled)
            click(activity, "toggle-panel-accessibility")
            awaitText(activity, "native-link-status", "panel accessibility enabled")
            assertTrue("clearing accessibilityState.disabled should restore a generic pressable", panel.isEnabled)
            instrumentation.runOnMainSync { panel.performClick() }
            awaitText(activity, "native-link-status", "panel pressed")
            val pressable = awaitView(activity, "native-pressable")
            assertTrue("native Pressable should be a container", pressable is ViewGroup)
            instrumentation.runOnMainSync { pressable.performClick() }
            awaitText(activity, "native-link-status", "pressable pressed")
            instrumentation.runOnMainSync {
                val downTime = SystemClock.uptimeMillis()
                val x = pressable.width / 2f
                val y = pressable.height / 2f
                val down = MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, x, y, 0)
                val up = MotionEvent.obtain(downTime, downTime + 32, MotionEvent.ACTION_UP, x, y, 0)
                pressable.dispatchTouchEvent(down)
                pressable.dispatchTouchEvent(up)
                down.recycle()
                up.recycle()
            }
            awaitText(activity, "pressable-lifecycle", "Press lifecycle: 1/1")
            val disabledPressable = awaitView(activity, "disabled-pressable")
            assertFalse("disabled Pressable should be disabled", disabledPressable.isEnabled)
            instrumentation.runOnMainSync { disabledPressable.performClick() }
            assertEquals("pressable pressed", (awaitView(activity, "native-link-status") as TextView).text.toString())
            val longPressPanel = awaitView(activity, "long-press-panel")
            assertTrue("generic onLongPress view was not long-clickable", longPressPanel.performLongClick())
            awaitText(activity, "long-press-status", "panel long pressed")
            click(activity, "toggle-long-press-accessibility")
            awaitText(activity, "long-press-status", "long press disabled")
            assertTrue("disabled long-press view remained enabled", !longPressPanel.isEnabled)
            assertTrue("disabled long-press view still accepted a click", !longPressPanel.performLongClick())
            click(activity, "toggle-long-press-accessibility")
            awaitText(activity, "long-press-status", "long press enabled")
            assertTrue("re-enabled long-press view did not accept a click", longPressPanel.performLongClick())
            awaitText(activity, "long-press-status", "panel long pressed")
            click(activity, "toggle-image-tint")
            awaitText(activity, "image-tint-status", "image tint off")
            awaitImageTintCleared(activity, "native-image")
            val tintedUnsupported = awaitView(activity, "unsupported-image") as ImageView
            assertEquals(1, tintedUnsupported.contentDescription.toString().split("Unsupported image source").size - 1)
            val styleToggle = awaitView(activity, "toggle-button-style") as Button
            var styleInfo: AccessibilityNodeInfo? = null
            instrumentation.runOnMainSync { styleInfo = styleToggle.createAccessibilityNodeInfo() }
            assertTrue("selected accessibility state should start clear", styleInfo?.isSelected == false)
            click(activity, "toggle-button-style")
            awaitText(activity, "native-link-status", "button style accented")
            val accentedButton = awaitView(activity, "toggle-button-style") as Button
            assertEquals(Color.rgb(0xef, 0x44, 0x44), accentedButton.currentTextColor)
            instrumentation.runOnMainSync { styleInfo = accentedButton.createAccessibilityNodeInfo() }
            assertTrue("selected accessibility state was not exposed", styleInfo?.isSelected == true)
            val dynamicStyleBox = awaitView(activity, "dynamic-style-box")
            assertTrue("custom panel style should use a GradientDrawable", dynamicStyleBox.background is GradientDrawable)
            click(activity, "toggle-panel-style")
            awaitText(activity, "panel-style-status", "panel style off")
            assertTrue("removing panel style should restore the default background", dynamicStyleBox.background == null)
            click(activity, "toggle-panel-style")
            awaitText(activity, "panel-style-status", "panel style on")
            assertTrue("restoring panel style should recreate its drawable", dynamicStyleBox.background is GradientDrawable)
            val nullWidthText = awaitView(activity, "null-width-text")
            val explicitTextWidth = nullWidthText.width
            assertTrue("explicit text width was not applied", explicitTextWidth > (150 * density).toInt())
            click(activity, "toggle-null-width")
            awaitWidthDecrease(nullWidthText, explicitTextWidth, 20, density)
            val percentWidth = awaitView(activity, "percent-width")
            assertEquals((120 * density).toInt(), percentWidth.width)
            val percentBasisFirst = awaitView(activity, "percent-basis-first")
            val percentBasisSecond = awaitView(activity, "percent-basis-second")
            assertEquals((120 * density).toInt(), percentBasisFirst.width)
            assertEquals((120 * density).toInt(), percentBasisSecond.width)
            val independentGapFirst = awaitView(activity, "independent-gap-first")
            val independentGapSecond = awaitView(activity, "independent-gap-second")
            val independentGapThird = awaitView(activity, "independent-gap-third")
            assertEquals(
                "column gap was not shared through the native layout ABI",
                50.0 * density,
                (independentGapSecond.left - independentGapFirst.left).toDouble(),
                1.0,
            )
            assertEquals(
                "row gap was not shared through the native layout ABI",
                22.0 * density,
                (independentGapThird.top - independentGapFirst.top).toDouble(),
                1.0,
            )
            val nestedSharedColumn = awaitView(activity, "nested-shared-column")
            val nestedSharedFirst = awaitView(activity, "nested-shared-first")
            val nestedSharedSecond = awaitView(activity, "nested-shared-second")
            val nestedSharedSibling = awaitView(activity, "nested-shared-sibling")
            assertEquals(
                "nested column gap was not preserved",
                18.0 * density,
                (nestedSharedSecond.top - nestedSharedFirst.top).toDouble(),
                1.0,
            )
            assertEquals(
                "nested row gap was not preserved",
                80.0 * density,
                (nestedSharedSibling.left - nestedSharedColumn.left).toDouble(),
                1.0,
            )
            val nestedPercentParent = awaitView(activity, "nested-percent-parent")
            val nestedPercentChild = awaitView(activity, "nested-percent-child")
            assertEquals((80 * density).toInt(), nestedPercentParent.width)
            assertEquals(
                "nested percentage width used the outer parent",
                36.0 * density,
                nestedPercentChild.width.toDouble(),
                1.0,
            )
            assertEquals(
                "nested percentage height used the outer parent",
                26.0 * density,
                nestedPercentChild.height.toDouble(),
                1.0,
            )
            val nestedGrid = awaitView(activity, "nested-grid")
            val nestedGridFirst = awaitView(activity, "nested-grid-first")
            val nestedGridSecond = awaitView(activity, "nested-grid-second")
            val nestedGridThird = awaitView(activity, "nested-grid-third")
            val nestedGridSibling = awaitView(activity, "nested-grid-sibling")
            assertEquals(
                "nested grid columns were not shared through the tree ABI",
                52.0 * density,
                (nestedGridSecond.left - nestedGridFirst.left).toDouble(),
                1.0,
            )
            assertEquals(
                "nested grid rows were not shared through the tree ABI",
                26.0 * density,
                (nestedGridThird.top - nestedGridFirst.top).toDouble(),
                1.0,
            )
            assertEquals(
                "nested grid parent placement was not preserved",
                110.0 * density,
                (nestedGridSibling.left - nestedGrid.left).toDouble(),
                1.0,
            )
            val nestedReverse = awaitView(activity, "nested-reverse")
            val nestedReverseFirst = awaitView(activity, "nested-reverse-first")
            val nestedReverseSecond = awaitView(activity, "nested-reverse-second")
            val nestedReverseSibling = awaitView(activity, "nested-reverse-sibling")
            assertTrue("nested reverse flow did not use the shared v2 tree ABI", nestedReverseFirst.top > nestedReverseSecond.top)
            assertEquals("nested reverse parent placement was not preserved", (56 * density).toInt(), nestedReverseSibling.left - nestedReverse.left)
            val nestedWrapReverse = awaitView(activity, "nested-wrap-reverse")
            val nestedWrapReverseFirst = awaitView(activity, "nested-wrap-reverse-first")
            val nestedWrapReverseSecond = awaitView(activity, "nested-wrap-reverse-second")
            val nestedWrapReverseSibling = awaitView(activity, "nested-wrap-reverse-sibling")
            assertTrue("nested wrap-reverse flow did not use the shared v3 tree ABI", nestedWrapReverseFirst.top > nestedWrapReverseSecond.top)
            assertEquals("nested wrap-reverse parent placement was not preserved", (56 * density).toInt(), nestedWrapReverseSibling.left - nestedWrapReverse.left)
            val toggle = awaitView(activity, "native-switch")
            assertTrue("native switch should be an Android Switch", toggle is Switch)
            val nativeSwitch = toggle as Switch
            assertTrue("native switch should start off", !nativeSwitch.isChecked)
            assertTrue("native switch should apply track tint", nativeSwitch.trackTintList != null)
            assertTrue("native switch should apply thumb tint", nativeSwitch.thumbTintList != null)
            assertTrue("null switch value should fall back to checked", (awaitView(activity, "nullable-switch") as Switch).isChecked)
            val picker = awaitView(activity, "native-picker")
            assertTrue("native picker should be an Android Spinner", picker is Spinner)
            assertEquals("one", (awaitView(activity, "picker-value") as TextView).text.toString())
            assertEquals("initial picker selection must not emit onChange", "button style accented", (awaitView(activity, "native-link-status") as TextView).text.toString())
            instrumentation.runOnMainSync { (picker as Spinner).setSelection(1) }
            awaitText(activity, "picker-value", "two")
            assertEquals("picker two", (awaitView(activity, "native-link-status") as TextView).text.toString())
            val dateRoot = awaitView(activity, "native-date-picker")
            val nativeDatePicker = findType(dateRoot, DatePicker::class.java)
            assertTrue("native date picker should contain an Android DatePicker", nativeDatePicker != null)
            assertEquals("date picker minimum bound", "2026-10-01", java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date(nativeDatePicker!!.minDate)))
            assertEquals("date picker maximum bound", "2026-12-31", java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date(nativeDatePicker.maxDate)))
            instrumentation.runOnMainSync { nativeDatePicker.updateDate(2026, 10, 15) }
            awaitText(activity, "date-value", "2026-11-15")
            awaitText(activity, "date-event-status", "2026-11-15|event complete")
            val timeRoot = awaitView(activity, "native-time-picker")
            val nativeTimePicker = findType(timeRoot, TimePicker::class.java)
            assertTrue("native time picker should contain an Android TimePicker", nativeTimePicker != null)
            assertEquals(7, nativeTimePicker!!.hour)
            assertEquals(30, nativeTimePicker.minute)
            instrumentation.runOnMainSync { nativeTimePicker.minute = 33 }
            awaitText(activity, "time-value", "07:35")
            awaitText(activity, "date-event-status", "07:35|event complete")
            val countdownRoot = awaitView(activity, "native-countdown")
            val nativeCountdown = findType(countdownRoot, TimePicker::class.java)
            assertTrue("native countdown should contain an Android TimePicker", nativeCountdown != null)
            assertEquals(1, nativeCountdown!!.hour)
            assertEquals(30, nativeCountdown.minute)
            instrumentation.runOnMainSync { nativeCountdown.minute = 31 }
            awaitText(activity, "countdown-value", "01:31:45")
            awaitText(activity, "date-event-status", "01:31:45|duration complete")
            val checkbox = awaitView(activity, "native-checkbox")
            assertTrue("native checkbox should be an Android CheckBox", checkbox is CheckBox)
            assertFalse("native checkbox should start unchecked", (checkbox as CheckBox).isChecked)
            instrumentation.runOnMainSync { checkbox.performClick() }
            awaitText(activity, "checkbox-status", "checkbox on")
            // Prop updates must retain the dedicated change handler too.
            instrumentation.runOnMainSync { checkbox.performClick() }
            awaitText(activity, "checkbox-status", "checkbox off")
            instrumentation.runOnMainSync { checkbox.performClick() }
            awaitText(activity, "checkbox-status", "checkbox on")
            val indeterminateCheckbox = awaitView(activity, "native-checkbox-indeterminate") as CheckBox
            assertFalse("indeterminate checkbox should not report checked", indeterminateCheckbox.isChecked)
            assertTrue("indeterminate checkbox should retain its mixed state", indeterminateCheckbox.isActivated)
            assertEquals("mixed", ViewCompat.getStateDescription(indeterminateCheckbox))
            instrumentation.runOnMainSync { indeterminateCheckbox.performClick() }
            assertTrue("indeterminate checkbox should become checked on first toggle", indeterminateCheckbox.isChecked)
            val modal = awaitView(activity, "native-modal")
            assertTrue("native modal should be a container", modal is ViewGroup)
            assertEquals("modal should start hidden", View.GONE, modal.visibility)
            click(activity, "toggle-modal")
            repeat(20) {
                if (modal.visibility == View.VISIBLE) return@repeat
                SystemClock.sleep(100)
            }
            assertEquals("modal should become visible", View.VISIBLE, modal.visibility)
            assertEquals("Modal content", (awaitView(activity, "modal-content") as TextView).text.toString())
            // onShow is delivered after native reconciliation returns to the queue.
            awaitText(activity, "modal-status", "modal shown")
            assertEquals("1", (awaitView(activity, "modal-opacity") as TextView).text.toString())
            click(activity, "toggle-modal-opacity")
            awaitText(activity, "modal-opacity", "0.45")
            assertEquals("visible modal opacity should update in place", 0.45f, modal.alpha, 0.01f)
            click(activity, "toggle-modal")
            awaitText(activity, "modal-status", "modal dismissed")
            click(activity, "toggle-modal")
            awaitText(activity, "modal-status", "modal shown")
            instrumentation.runOnMainSync { activity.onBackPressed() }
            awaitText(activity, "modal-status", "modal requested")
            val justifiedText = awaitView(activity, "justified-text") as TextView
            assertEquals("justified text should use the Android inter-word mode", Layout.JUSTIFICATION_MODE_INTER_WORD, justifiedText.justificationMode)
            instrumentation.runOnMainSync { nativeSwitch.performClick() }
            awaitText(activity, "native-link-status", "switch on")
            var switchInfo: AccessibilityNodeInfo? = null
            instrumentation.runOnMainSync { switchInfo = nativeSwitch.createAccessibilityNodeInfo() }
            assertTrue("checked accessibility state was not exposed", switchInfo?.isChecked == true)
            val slider = awaitView(activity, "native-slider")
            assertTrue("native slider should be a SeekBar", slider is SeekBar)
            // One native position represents each authored 0.1 step.
            assertEquals("stepped slider should expose ten positions", 10, (slider as SeekBar).max)
            instrumentation.runOnMainSync { slider.progress = 8 }
            awaitText(activity, "native-link-status", "slider moved")
            assertEquals("0.8", (awaitView(activity, "slider-value") as TextView).text.toString())
            val nativeSlider = slider as SeekBar
            assertEquals("slider thumb should retain its selected step", 8, nativeSlider.progress)
            instrumentation.runOnMainSync {
                val downTime = SystemClock.uptimeMillis()
                val y = nativeSlider.height / 2f
                val end = nativeSlider.width.toFloat().coerceAtLeast(1f) * 0.8f
                val down = MotionEvent.obtain(downTime, downTime, MotionEvent.ACTION_DOWN, 0f, y, 0)
                val move = MotionEvent.obtain(downTime, downTime + 16, MotionEvent.ACTION_MOVE, end, y, 0)
                val up = MotionEvent.obtain(downTime, downTime + 32, MotionEvent.ACTION_UP, end, y, 0)
                try {
                    nativeSlider.dispatchTouchEvent(down)
                    nativeSlider.dispatchTouchEvent(move)
                    nativeSlider.dispatchTouchEvent(up)
                } finally {
                    down.recycle()
                    move.recycle()
                    up.recycle()
                }
            }
            awaitText(activity, "slider-completions", "Slider completions: 1")
            assertTrue("native indicator should be a ProgressBar", awaitView(activity, "native-indicator") is ProgressBar)
            val stoppedIndicator = awaitProgressBar(activity, "stopped-indicator", "visible and stopped") {
                it.isShown && !it.isIndeterminate
            }
            assertTrue("stopped indicator should stay visible when requested", stoppedIndicator.isShown)
            assertTrue("stopped indicator should not animate", !stoppedIndicator.isIndeterminate)
            assertEquals(0.75f, stoppedIndicator.scaleX)
            assertEquals(0.75f, stoppedIndicator.scaleY)
            click(activity, "toggle-indicator-size")
            val enlargedIndicator = awaitProgressBar(activity, "stopped-indicator", "large size") { it.scaleX == 1.35f }
            assertEquals(1.35f, enlargedIndicator.scaleY)
            click(activity, "toggle-indicator-size")
            val resizedIndicator = awaitProgressBar(activity, "stopped-indicator", "small size restored") { it.scaleX == 0.75f }
            assertEquals(0.75f, resizedIndicator.scaleY)
            val scaledIndicator = awaitProgressBar(activity, "scaled-indicator", "numeric size with authored transform") { it.isShown }
            assertEquals(1f, scaledIndicator.scaleX)
            assertEquals(1f, scaledIndicator.scaleY)
            val hiddenIndicator = awaitProgressBar(activity, "hidden-indicator", "hidden") { it.visibility == View.GONE }
            assertEquals("hidesWhenStopped should hide a stopped indicator", View.GONE, hiddenIndicator.visibility)
            val displayNoneIndicator = awaitProgressBar(activity, "display-none-indicator", "hidden") { it.visibility == View.GONE }
            assertEquals("display:none should hide an activity indicator", View.GONE, displayNoneIndicator.visibility)
            val wrapped = awaitView(activity, "layout-wrap") as LinearLayout
            awaitLayoutWidth(activity, "layout-status", 240.0)
            click(activity, "toggle-layout-width")
            val reportedWidth = awaitLayoutWidth(activity, "layout-status", 180.0)
            assertEquals("layout event must describe the actual native frame", wrapped.width.toDouble() / density.toDouble(), reportedWidth, 0.000001)
            assertEquals("native frame must resize within one physical pixel", 180.0 * density.toDouble(), wrapped.width.toDouble(), 1.0)
            awaitLayoutWidth(activity, "layout-transform-status", 100.0)
            awaitText(activity, "hidden-layout-status", "Hidden layout events: 0")
            val bounded = awaitView(activity, "layout-min")
            val absolute = awaitView(activity, "layout-absolute")
            assertEquals("constrained width should snap to the nearest physical pixel", 140.0 * density.toDouble(), bounded.width.toDouble(), 0.500001)
            assertTrue(
                "absolute child ignored its trailing insets",
                absolute.right <= wrapped.width - (8 * density).toInt() && absolute.bottom <= wrapped.height - (8 * density).toInt()
            )
            assertTrue("wrapped child did not wrap", bounded.top < awaitView(activity, "layout-stretch").top)
            val scroll = awaitView(activity, "native-scroll")
            val image = awaitView(activity, "native-image")
            assertTrue("Intrinsic image did not mount", awaitView(activity, "intrinsic-image") is ImageView)
            awaitText(activity, "intrinsic-image-status", "intrinsic image ready")
            click(activity, "toggle-intrinsic-image")
            awaitText(activity, "intrinsic-image-status", "intrinsic image resized")
            val imageBackground = awaitView(activity, "native-image-background")
            val unsupportedBackground = awaitView(activity, "unsupported-image-background")
            val keyboardAvoiding = awaitView(activity, "native-keyboard-avoiding")
            val svg = awaitView(activity, "native-svg")
            val icon = awaitView(activity, "native-icon")
            val video = awaitView(activity, "native-video")
            val sectionList = awaitView(activity, "native-section-list")
            assertTrue("ScrollView did not render an Android ScrollView", containsType(scroll, ScrollView::class.java))
            val nativeScroller = findType(scroll, ScrollView::class.java)!!
            assertTrue("ScrollView contentContainerStyle did not add top padding", image.top >= nativeScroller.top + (12 * density).toInt())
            assertScrolls(nativeScroller)
            assertTrue("Image did not render as ImageView", image is ImageView)
            assertEquals("CraftNativeImageBackgroundView", imageBackground.javaClass.simpleName)
            assertTrue("ImageBackground child did not reconcile", awaitView(activity, "native-image-background-label") is TextView)
            assertTrue("ImageBackground image did not decode", (imageBackground as ViewGroup).getChildAt(0) is ImageView)
            assertTrue("ImageBackground image is empty", (imageBackground.getChildAt(0) as ImageView).drawable != null)
            awaitText(activity, "image-background-error-status", "background failed")
            assertTrue("ImageBackground accessibility label was lost on failure", unsupportedBackground.contentDescription.toString().contains("Unsupported background"))
            assertTrue("ImageBackground error did not reach accessibility metadata", unsupportedBackground.contentDescription.toString().contains("Unsupported image source"))
            assertEquals("CraftNativeKeyboardAvoidingView", keyboardAvoiding.javaClass.simpleName)
            assertTrue("KeyboardAvoidingView child did not reconcile", awaitView(activity, "native-keyboard-avoiding-input") is EditText)
            assertEquals("CraftNativeSvgView", svg.javaClass.simpleName)
            assertEquals("SVG accessibility metadata did not survive native mounting", "Native vector", svg.contentDescription?.toString())
            assertEquals("CraftNativeIconView", icon.javaClass.simpleName)
            assertEquals("Native icon", icon.contentDescription?.toString())
            assertTrue("Icon fixture should expose a visible glyph", (icon as TextView).text.isNotBlank())
            var iconInfo: AccessibilityNodeInfo? = null
            instrumentation.runOnMainSync { iconInfo = icon.createAccessibilityNodeInfo() }
            assertEquals(ImageView::class.java.name, iconInfo?.className?.toString())
            assertTrue("SectionList did not render an Android ScrollView", containsType(sectionList, ScrollView::class.java))
            assertTrue("SectionList header did not reconcile", awaitView(activity, "native-section-header") is TextView)
            assertTrue("SectionList row did not reconcile", awaitView(activity, "native-section-row") is TextView)
            assertTrue("SectionList overflow content did not reconcile", awaitView(activity, "native-section-footer") is TextView)
            assertScrolls(findType(sectionList, ScrollView::class.java)!!)
            awaitText(activity, "section-scroll-status", "Section scrolls: 1")
            assertEquals("CraftNativeVideoView", video.javaClass.simpleName)
            assertTrue("Image data did not decode", (image as ImageView).drawable != null)
            assertEquals("Native pixel", image.contentDescription.toString())
            awaitText(activity, "image-status", "image loaded")
            awaitText(activity, "image-load-end-status", "image load ended")
            var imageInfo: AccessibilityNodeInfo? = null
            instrumentation.runOnMainSync { imageInfo = image.createAccessibilityNodeInfo() }
            assertEquals(ImageView::class.java.name, imageInfo?.className?.toString())
            instrumentation.runOnMainSync { image.performClick() }
            awaitText(activity, "native-caption", "Image taps: 1")
            val unsupported = awaitView(activity, "unsupported-image") as ImageView
            assertTrue(unsupported.drawable == null)
            assertTrue("image accessibility label was lost on failure", unsupported.contentDescription.toString().contains("Unsupported image"))
            assertTrue(unsupported.contentDescription.toString().contains("Unsupported image source"))
            awaitText(activity, "image-error-status", "image failed")
            click(activity, "toggle-image-source")
            awaitText(activity, "image-recovery-status", "image recovered")
            assertTrue("image source recovery did not decode", unsupported.drawable != null)
            assertEquals("image error metadata was not cleared on recovery", "Unsupported image", unsupported.contentDescription.toString())
            click(activity, "clear-image-source")
            awaitText(activity, "image-error-count", "2")
            click(activity, "toggle-image-tint")
            awaitText(activity, "image-tint-status", "image tint on")
            assertEquals("missing image errors should be deduplicated", "2", (awaitView(activity, "image-error-count") as TextView).text.toString())
            assertNoWebView(activity)

            instrumentation.runOnMainSync {
                name.requestFocus()
                (name as EditText).setText("Ada")
            }
            awaitText(activity, "name-focuses", "Focuses: 1")
            awaitText(activity, "greeting", "Hello Ada")
            assertTrue("TextInput lost focus after typing", name.isFocused)
            click(activity, "toggle-name-mode")
            val multilineName = awaitView(activity, "name-input") { it is EditText && !it.isSingleLine } as EditText
            assertSame("multiline mode replaced the retained input", name, multilineName)
            assertFalse("multiline mode was not applied", multilineName.isSingleLine)
            assertTrue("email keyboard lost its multiline flag", multilineName.inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE != 0)
            assertEquals(InputType.TYPE_CLASS_TEXT, multilineName.inputType and InputType.TYPE_MASK_CLASS)
            assertEquals(InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS, multilineName.inputType and InputType.TYPE_MASK_VARIATION)
            assertEquals("Ada", multilineName.text.toString())
            awaitText(activity, "name-mode", "multiline")
            click(activity, "toggle-name-mode")
            val singleLineName = awaitView(activity, "name-input") { it is EditText && it.isSingleLine } as EditText
            assertSame("single-line mode replaced the retained input", name, singleLineName)
            assertTrue("single-line mode did not restore the input", singleLineName.isSingleLine)
            assertEquals("Ada", singleLineName.text.toString())
            // The field's dashed underline, on what was typed (an empty field has nothing to underline).
            val inputDecorations = (singleLineName.text as? Spanned)?.getSpans(0, singleLineName.text.length, ReplacementSpan::class.java).orEmpty()
            assertTrue("TextInput decoration span was not applied", inputDecorations.isNotEmpty())
            awaitText(activity, "name-mode", "single-line")
            instrumentation.runOnMainSync { singleLineName.onEditorAction(EditorInfo.IME_ACTION_DONE) }
            awaitText(activity, "name-submits", "Submits: 1")
            instrumentation.runOnMainSync {
                notes.requestFocus()
            }
            awaitText(activity, "notes-focus-text", "Notes focus: Draft")
            awaitText(activity, "name-blurs", "Blurs: 1")
            awaitText(activity, "name-end-editings", "End edits: 1")
            instrumentation.runOnMainSync {
                (notes as EditText).setText("Note")
                (notes as EditText).onEditorAction(EditorInfo.IME_ACTION_DONE)
            }
            awaitText(activity, "name-submits", "Submits: 2")
            assertSame("View container was replaced after typing", root, awaitView(activity, "root"))
            assertSame("TextInput was replaced after typing", singleLineName, awaitView(activity, "name-input"))
            assertSame("multiline TextInput was replaced after typing", notes, awaitView(activity, "notes-input"))
            assertTrue("multiline TextInput lost focus after typing", notes.isFocused)
            assertFalse("blurred TextInput regained focus while typing in notes", singleLineName.isFocused)
            instrumentation.runOnMainSync {
                notes.requestFocus()
                notes.clearFocus()
            }
            awaitText(activity, "notes-blurs", "Notes blurs: 1")
            awaitText(activity, "notes-end-editings", "Notes end edits: 1")

            click(activity, "increment")
            click(activity, "increment")
            awaitText(activity, "count", "Count: 2")

            click(activity, "open-details")
            assertEquals("Details for Ada", (awaitView(activity, "details-title") as TextView).text.toString())
            assertEquals("Count: 2", (awaitView(activity, "details-count") as TextView).text.toString())
            click(activity, "details-increment")
            awaitText(activity, "details-count", "Count: 3")
            val peopleHost = awaitView(activity, "people-list") as SwipeRefreshLayout
            val people = findType(peopleHost, ScrollView::class.java)!!
            assertTrue("ScrollView refresh host did not enable pull-to-refresh", peopleHost.isEnabled)
            pullToRefresh(peopleHost)
            awaitText(activity, "people-count", "People: 40; events: 1")
            val peopleHeader = awaitView(activity, "people-header") as TextView
            assertTrue("ScrollView contentContainerStyle did not add top padding", peopleHeader.top >= people.top + (8 * density).toInt())
            val peopleLayouts = awaitView(activity, "people-layout-status") as TextView
            val initialRowLayouts = peopleLayouts.text.toString().substringAfterLast(": ").toInt()
            assertTrue("ScrollView rows did not report layout", initialRowLayouts > 0)
            var peopleHeaderInfo: AccessibilityNodeInfo? = null
            instrumentation.runOnMainSync { peopleHeaderInfo = peopleHeader.createAccessibilityNodeInfo() }
            assertTrue("FlatList header did not expose heading semantics", peopleHeaderInfo?.isHeading == true)
            val personZero = awaitView(activity, "person-label-person-0") as TextView
            val personInput = awaitView(activity, "person-input-person-0") as EditText
            instrumentation.runOnMainSync {
                personInput.requestFocus()
                personInput.setText("draft")
            }
            click(activity, "shuffle-people")
            awaitText(activity, "person-label-person-0", "1: Person zero updated")
            assertSame("keyed list update replaced a visible row", personZero, awaitView(activity, "person-label-person-0"))
            assertSame("keyed list update replaced a focused input", personInput, awaitView(activity, "person-input-person-0"))
            assertEquals("draft", personInput.text.toString())
            assertTrue("keyed list update dropped input focus", personInput.isFocused)
            click(activity, "load-more-people")
            awaitText(activity, "people-count", "People: 41; events: 3")
            awaitLayoutIncrease(activity, "people-layout-status", initialRowLayouts)
            click(activity, "clear-people")
            assertEquals("Nobody here", (awaitView(activity, "people-empty") as TextView).text.toString())
            assertEquals("End of people", (awaitView(activity, "people-footer") as TextView).text.toString())
            awaitText(activity, "people-count", "People: 0; events: 4")
            assertNoWebView(activity)

            instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK)
            assertSame("Returning rebuilt the home input", name, awaitView(activity, "name-input"))
            assertEquals("Ada", (name as EditText).text.toString())
            assertEquals("Count: 2", (awaitView(activity, "count") as TextView).text.toString())
            click(activity, "navigation-check-lifecycle")
            awaitText(activity, "navigation-lifecycle", "Disposed Ada/3")

            click(activity, "open-details")
            awaitView(activity, "details-title")
            assertEquals("Count: 2", (awaitView(activity, "details-count") as TextView).text.toString())
            click(activity, "details-back")
            assertSame(name, awaitView(activity, "name-input"))

            click(activity, "open-details")
            awaitView(activity, "details-title")
            click(activity, "open-summary")
            assertEquals("Summary for Ada", (awaitView(activity, "summary-title") as TextView).text.toString())
            assertNoWebView(activity)
            instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK)
            assertSame("Replace kept details on the stack", name, awaitView(activity, "name-input"))
            click(activity, "navigation-check-lifecycle")
            awaitText(activity, "navigation-lifecycle", "Disposed Ada/2")
        }
        finally {
            instrumentation.runOnMainSync { activity.finishAndRemoveTask() }
            instrumentation.waitForIdleSync()
        }
    }

    @Test
    fun nativePullToRefreshSurvivesViewReattachment() {
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ) as MainActivity
        try {
            click(activity, "open-details")
            val host = awaitView(activity, "people-list") { it.width > 0 && it.height > 0 } as SwipeRefreshLayout
            assertTrue("default refresh travel collapsed", host.progressViewEndOffset > host.progressViewStartOffset)
            assertTrue("native refresh indicator was detached", findType(host, ImageView::class.java) != null)
            instrumentation.runOnMainSync {
                val parent = host.parent as ViewGroup
                val index = parent.indexOfChild(host)
                parent.removeView(host)
                parent.addView(host, index)
            }
            pullToRefresh(host)
            awaitText(activity, "people-count", "People: 40; events: 1")
        } finally {
            instrumentation.runOnMainSync { activity.finishAndRemoveTask() }
            instrumentation.waitForIdleSync()
        }
    }

    @Test
    fun nativeLinkOpensRoute() {
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ) as MainActivity
        try {
            click(activity, "navigation-increment")
            awaitText(activity, "navigation-home-state", "Home state: Ada/1")
            val link = awaitView(activity, "native-route-link")
            instrumentation.runOnMainSync { link.performClick() }
            assertEquals("Details for ", (awaitView(activity, "details-title") as TextView).text.toString())
            click(activity, "details-back")
            awaitView(activity, "native-route-link")
        } finally {
            instrumentation.runOnMainSync { activity.finish() }
        }
    }

    @Test
    fun nativeAppearanceReconcilesTraitDefaults() {
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        ) as MainActivity
        try {
            val themeProbe = awaitView(activity, "theme-probe")
            val initialThemeColor = backgroundColor(themeProbe)
            assertTrue("theme probe did not receive a native background", initialThemeColor != null)
            // The way light and dark change for real: through AppCompat, which
            // owns the activity's night mode (a configuration set by hand is
            // put back by it). The manifest handles uiMode, so the activity
            // hears onConfigurationChanged rather than being recreated.
            val currentNight = activity.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            instrumentation.runOnMainSync {
                activity.delegate.localNightMode = if (currentNight == Configuration.UI_MODE_NIGHT_YES) {
                    androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_NO
                } else {
                    androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_YES
                }
            }
            awaitBackgroundColor(themeProbe, initialThemeColor)
            assertTrue("theme probe label disappeared during trait refresh", awaitView(activity, "theme-probe-label") is TextView)
        }
        finally {
            instrumentation.runOnMainSync { activity.finishAndRemoveTask() }
            instrumentation.waitForIdleSync()
        }
    }
}
