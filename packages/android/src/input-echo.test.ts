/** Execute the native input reconciler using the Android builder's Kotlin toolchain. */
import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('keeps newer keystrokes while earlier props are acknowledged', async () => {
  const template = await Bun.file(new URL('../templates/MainActivityNative.kt.template', import.meta.url)).text()
  const helper = template.match(/internal class CraftNativeInputEcho \{[\s\S]*?\n\}/)?.[0]
  if (!helper) throw new Error('Craft Android input reconciler is missing')
  const fixture = await Bun.file(new URL('./fixtures/input-echo.kt', import.meta.url)).text()
  await runKotlinFixture(`${helper}\n${fixture}`)
}, 180_000)
