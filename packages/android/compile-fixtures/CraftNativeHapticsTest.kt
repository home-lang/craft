package {{PACKAGE_NAME}}

import android.os.VibrationEffect
import android.view.HapticFeedbackConstants
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CraftNativeHapticsTest {
    @Test
    fun readsTheStyleEachMethodPlays() {
        assertEquals("medium", CraftNativeHaptics.style("impact", null))
        assertEquals("rigid", CraftNativeHaptics.style("impact", "rigid"))
        // stx's bridge sends every kind through impact, as iOS accepts.
        assertEquals("error", CraftNativeHaptics.style("impact", "error"))
        assertEquals("warning", CraftNativeHaptics.style("notification", "warning"))
        assertEquals("success", CraftNativeHaptics.style("notification", "heavy"))
        assertEquals("selection", CraftNativeHaptics.style("selection", "ignored"))
        assertNull(CraftNativeHaptics.style("prepare", "impact"))
    }

    @Test
    fun usesViewFeedbackWhereTheApiLevelHasIt() {
        assertEquals(HapticFeedbackConstants.KEYBOARD_TAP, CraftNativeHaptics.feedbackConstant("light", 26))
        assertEquals(HapticFeedbackConstants.VIRTUAL_KEY, CraftNativeHaptics.feedbackConstant("medium", 26))
        assertEquals(HapticFeedbackConstants.LONG_PRESS, CraftNativeHaptics.feedbackConstant("heavy", 26))
        assertEquals(HapticFeedbackConstants.CLOCK_TICK, CraftNativeHaptics.feedbackConstant("soft", 26))
        assertEquals(HapticFeedbackConstants.TEXT_HANDLE_MOVE, CraftNativeHaptics.feedbackConstant("soft", 27))
        assertEquals(HapticFeedbackConstants.CONTEXT_CLICK, CraftNativeHaptics.feedbackConstant("rigid", 26))
        assertEquals(HapticFeedbackConstants.CLOCK_TICK, CraftNativeHaptics.feedbackConstant("selection", 33))
        assertEquals(HapticFeedbackConstants.SEGMENT_TICK, CraftNativeHaptics.feedbackConstant("selection", 34))
        assertNull(CraftNativeHaptics.feedbackConstant("success", 29))
        assertEquals(HapticFeedbackConstants.CONFIRM, CraftNativeHaptics.feedbackConstant("success", 30))
        assertEquals(HapticFeedbackConstants.REJECT, CraftNativeHaptics.feedbackConstant("error", 30))
        assertNull(CraftNativeHaptics.feedbackConstant("warning", 36))
        assertEquals(HapticFeedbackConstants.VIRTUAL_KEY, CraftNativeHaptics.feedbackConstant("unknown", 26))
    }

    @Test
    fun fallsBackToTheVibrator() {
        assertEquals(VibrationEffect.EFFECT_TICK, CraftNativeHaptics.predefinedEffect("selection"))
        assertEquals(VibrationEffect.EFFECT_DOUBLE_CLICK, CraftNativeHaptics.predefinedEffect("warning"))
        assertEquals(VibrationEffect.EFFECT_HEAVY_CLICK, CraftNativeHaptics.predefinedEffect("error"))
        assertEquals(VibrationEffect.EFFECT_CLICK, CraftNativeHaptics.predefinedEffect("medium"))
        assertArrayEquals(longArrayOf(0, 50, 100, 50), CraftNativeHaptics.timings("warning"))
        assertArrayEquals(longArrayOf(20), CraftNativeHaptics.timings("unknown"))
    }
}
