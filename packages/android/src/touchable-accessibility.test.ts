/** Execute the shipped accessibility role selection with authored and changing destinations. */
import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('infers link and button roles for touchables while preserving authored roles', async () => {
  const source = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const inference = source.match(/        val hasLinkTarget = listOf\("href", "to"\)[\s\S]*?(?=        val state = props\.optJSONObject\("accessibilityState"\))/)?.[0]
  if (!inference) throw new Error('Native accessibility role inference is missing')
  await runKotlinFixture(`
class JSONObject(private val values: Map<String, Any?>) {
    fun opt(name: String): Any? = values[name]
}
fun craftNativeOptionalString(value: Any?): String? = value as? String
fun role(type: String, values: Map<String, Any?>): String {
    val props = JSONObject(values)
${inference}
    return role
}
fun main() {
    for (type in listOf("Pressable", "TouchableOpacity", "TouchableHighlight")) {
        check(role(type, emptyMap()) == "button")
        check(role(type, mapOf("href" to "/details")) == "link")
        check(role(type, mapOf("to" to "/details")) == "link")
        check(role(type, mapOf("href" to null)) == "button")
        check(role(type, mapOf("href" to "  ")) == "button")
        check(role(type, mapOf("href" to "/details", "accessibilityRole" to "button")) == "button")
        check(role(type, mapOf("href" to "/details", "accessibilityRole" to "header")) == "header")
    }
    check(role("Text", emptyMap()) == "text")
    check(role("Icon", emptyMap()) == "image")
    println("PASS touchable link/button roles, href/to changes, authored overrides and ordinary native roles")
}
`)
}, 180_000)
