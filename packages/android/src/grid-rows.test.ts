/** Execute the shipped grid track allocation with fractional native spacing. */
import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('sizes occupied and empty explicit grid rows after padding and fractional gaps', async () => {
  const template = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const allocation = template.match(/        val rowHeights = if \(gridRows != null\) \{[\s\S]*?\n        \} else naturalRowHeights/)?.[0]
  if (!allocation) throw new Error('Native grid track allocation is missing')
  await runKotlinFixture(`
import kotlin.math.abs
import kotlin.math.max

fun allocate(naturalRowHeights: List<Float>, gridRows: Int?, height: Int, rowGap: Float, paddingTop: Int = 0, paddingBottom: Int = 0): List<Float> {
    val rows = naturalRowHeights.map { mutableListOf<Int>() }.toMutableList()
${allocation}
    return rowHeights
}

fun expectTracks(expected: List<Float>, actual: List<Float>) {
    check(actual.size == expected.size) { "Expected tracks $expected, got $actual" }
    expected.zip(actual).forEach { (wanted, measured) ->
        check(abs(wanted - measured) < 0.001f) { "Expected tracks $expected, got $actual" }
    }
}

fun main() {
    expectTracks(listOf(40f, 40f), allocate(listOf(12f, 12f), 2, 84, 4f))
    expectTracks(listOf(40f, 40f), allocate(listOf(12f), 2, 84, 4f))
    expectTracks(listOf(30f, 30f, 30f), allocate(listOf(12f, 12f, 12f), 2, 98, 4f))
    expectTracks(listOf(31.25f, 31.25f), allocate(listOf(12f, 12f), 2, 84, 1.5f, 10, 10))
    expectTracks(listOf(0f, 0f), allocate(emptyList(), 2, 0, 4f))
    expectTracks(listOf(12f, 18f), allocate(listOf(12f, 18f), null, 84, 4f))
    println("PASS explicit grid rows allocate occupied and empty tracks with padding, fractional gaps and overflow rows")
}
`)
}, 180_000)


test('encodes shared grid counts as the unsigned integer fields in the native ABI', async () => {
  const template = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const columns = template.match(/^[^\n]*put(?:Enum)?\(base, 29, node\.gridColumns[^\n]*$/m)?.[0]
  const rows = template.match(/^[^\n]*if \(explicitRowsAware\) put(?:Enum)?\(base, 34, [^\n]*$/m)?.[0]
  if (!columns || !rows) throw new Error('Shared grid count serialization is missing')
  await runKotlinFixture(`
data class GridNode(val gridColumns: Int, val gridRows: Int?)

fun main() {
    val base = 0
    val node = GridNode(2, 3)
    val explicitRowsAware = true
    val nodeData = FloatArray(35) { Float.NaN }
    fun put(base: Int, index: Int, value: Float) { nodeData[base + index] = value }
    fun putEnum(base: Int, index: Int, value: Int) { put(base, index, Float.fromBits(value)) }
${columns}
${rows}
    check(nodeData[29].toRawBits() == 2) { "grid_columns is not encoded as u32" }
    check(nodeData[34].toRawBits() == 3) { "grid_rows is not encoded as u32" }
    println("PASS native grid counts retain the integer bit patterns consumed by Zig")
}
`)
}, 180_000)
