/** Execute the shipped padding conversion at fractional Android densities. */
import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('snaps authored padding to the nearest physical pixel without truncating content insets', async () => {
  const source = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const number = source.match(/private fun craftNativeNumber\(value: Any\?\): Double\? =[\s\S]*?(?=\n\n)/)?.[0]
  const padding = source.match(/internal fun craftNativePadding\([\s\S]*?\n\}/)?.[0]
  if (!number || !padding) throw new Error('Native padding conversion is missing')
  await runKotlinFixture(`
import kotlin.math.roundToInt

class JSONObject(private val values: Map<String, Any?>) {
    fun opt(name: String): Any? = values[name]
}
${number}
${padding}

fun main() {
    fun pixels(value: Any?, density: Float = 2.625f, fallback: Int = 7): Int =
        craftNativePadding(JSONObject(mapOf("padding" to value)), "padding", fallback, density)

    // The API 34/35 fixture's 4dp padding is 10.5px. Truncating both sides
    // makes its anchored 156dp child 411px wide instead of within one pixel.
    check(pixels(4) == 11) { "Expected 4dp padding at 2.625 density to snap to 11px, got " + pixels(4) }
    check(pixels(8) == 21)
    check(pixels(1, 1.5f) == 2)
    check(pixels(1, 2.5f) == 3)
    check(pixels(3, 2.625f) == 8)
    check(pixels(0) == 0)
    check(pixels(-1) == 7)
    check(pixels("4") == 7)
    check(pixels(true) == 7)
    check(pixels(Double.NaN) == 7)
    check(pixels(Double.POSITIVE_INFINITY) == 7)
    check(pixels(4, Float.POSITIVE_INFINITY) == 7)
    check(craftNativePadding(null, "padding", 9, 2.625f) == 9)
    println("PASS fractional-density padding snaps to physical pixels and preserves invalid-value fallbacks")
}
`)
}, 180_000)
