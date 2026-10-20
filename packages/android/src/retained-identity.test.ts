/** Execute the shipped lookup and registration across keyed replacements and reparenting. */
import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('retains authored keys and protocol identities without conflating sibling selectors', async () => {
  const template = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const lookup = template.match(/        val protocolId = node\.optString\("id"\)[\s\S]*?(?=        val reusableInput =)/)?.[0]
  const registration = template.match(/        next\[identity\] = control[\s\S]*?(?=        applyViewStyle\(control, style\))/)?.[0]
  const authoredKey = template.match(/    private fun authoredKey\(node: JSONObject, props: JSONObject\): String\? \{[\s\S]*?\n    \}/)?.[0]
  if (!lookup || !registration || !authoredKey) throw new Error('Native retained identity implementation is missing')
  await runKotlinFixture(`
class JSONObject(private val values: Map<String, String>) {
    fun optString(name: String): String = values[name].orEmpty()
}
class View(var draft: String = "typed", var selection: Int = 3)
class MutationDocument(var ids: Set<String> = emptySet()) {
    fun containsNode(id: String): Boolean = id in ids
}
class Screen {
    val protocolIds = mutableMapOf<View, String>()
    val mutations = MutationDocument()
}
${authoredKey}

fun retain(screen: Screen, id: String, key: String?, testID: String, path: String, previousControls: Map<String, View>, next: MutableMap<String, View>): Pair<View, String> {
    val node = JSONObject(mapOf("id" to id, "key" to key.orEmpty()))
    val props = JSONObject(mapOf("testID" to testID))
${lookup}
    val control = previous ?: View()
${registration}
    return control to identity
}

fun main() {
    val screen = Screen()
    val first = mutableMapOf<String, View>()
    val plain = retain(screen, "plain-node", "container", "shared-selector", "root.0", emptyMap(), first).first
    plain.draft = "kept draft"
    plain.selection = 7
    val second = mutableMapOf<String, View>()
    screen.mutations.ids = setOf("safe-node")
    val safe = retain(screen, "safe-node", "container", "shared-selector", "root.0", first, second).first
    check(safe === plain) { "A keyed conditional replacement lost the retained view" }
    check(safe.draft == "kept draft" && safe.selection == 7)
    val third = mutableMapOf<String, View>()
    val moved = retain(screen, "safe-node", "container", "shared-selector", "popup.1", second, third).first
    check(moved === safe) { "A protocol node lost its view when reparented" }
    val duplicateSelector = retain(screen, "other-node", null, "shared-selector", "popup.2", second, third).first
    check(duplicateSelector !== safe) { "A repeated selector conflated distinct protocol nodes" }
    val otherParent = retain(screen, "other-parent-node", "container", "shared-selector", "other.0", second, third).first
    check(otherParent !== safe) { "An authored key escaped its parent scope" }
    val restored = retain(screen, "safe-node", "container", "shared-selector", "root.0", third, mutableMapOf()).first
    check(restored === safe) { "Returning to a keyed branch replaced the native view" }
    val removed = retain(screen, "fresh-node", "container", "shared-selector", "root.0", emptyMap(), mutableMapOf()).first
    check(removed !== safe) { "A removed tree leaked a stale retained alias" }
    for (moveFirst in listOf(true, false)) {
        val scene = Screen()
        val old = mutableMapOf<String, View>()
        val original = retain(scene, "moving", "container", "shared-selector", "root.0", emptyMap(), old).first
        scene.mutations.ids = setOf("moving", "replacement")
        val next = mutableMapOf<String, View>()
        var reparented: View? = null
        var replacement: View? = null
        val move = { reparented = retain(scene, "moving", "container", "shared-selector", "popup.0", old, next).first }
        val refill = { replacement = retain(scene, "replacement", "container", "shared-selector", "root.0", old, next).first }
        if (moveFirst) { move(); refill() } else { refill(); move() }
        check(reparented === original) { "Reparenting lost the protocol view (moveFirst=$moveFirst)" }
        check(replacement !== original) { "Refilling a vacated keyed slot stole a surviving protocol view (moveFirst=$moveFirst)" }
        check(next["id:moving"] === original) { "Reparenting lost the protocol alias (moveFirst=$moveFirst)" }
        check(next["id:replacement"] === replacement) { "Replacement was not registered under its protocol alias (moveFirst=$moveFirst)" }
        check(next["id:moving"] !== next["id:replacement"])
    }
    println("PASS keyed replacement, protocol reparenting, selector isolation, parent scoping, return, removal and both refill traversal orders")
}
`)
}, 180_000)
