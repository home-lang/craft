import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

test('matches association path wildcards without treating regex syntax as patterns', async () => {
  const template = await Bun.file(new URL('../templates/CraftAppLinks.kt.template', import.meta.url)).text()
  const helper = template.match(/internal fun craftAppLinkPathMatches\([\s\S]*?\n\}/)?.[0]
  if (!helper) throw new Error('Craft Android App Link matcher is missing')
  const fixture = await Bun.file(new URL('./fixtures/app-links.kt', import.meta.url)).text()
  await runKotlinFixture(`${helper}\n${fixture}`)
}, 180_000)
