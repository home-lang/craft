/** Run the Android heart-rate core (CraftHeartRateCore.kt) on the JVM against iOS's HeartRateUnitTests vectors. */
import { test } from 'bun:test'
import { runKotlinFixture } from './testing'

/** The core template and the fixture as one file: one package-less source, its imports first. */
async function heartRateFixtureSource(): Promise<string> {
  const core = await Bun.file(new URL('../templates/CraftHeartRateCore.kt.template', import.meta.url)).text()
  const fixture = await Bun.file(new URL('./fixtures/heart-rate.kt', import.meta.url)).text()
  if (!core.startsWith('package {{PACKAGE_NAME}}\n')) throw new Error('CraftHeartRateCore.kt.template no longer starts with its package')
  const lines = `${core.replace('package {{PACKAGE_NAME}}\n', '')}\n${fixture}`.split('\n')
  const imports = [...new Set(lines.filter(line => line.startsWith('import ')))]
  return [...imports, ...lines.filter(line => !line.startsWith('import '))].join('\n')
}

test('decodes 0x2A37 payloads and keeps the recording exactly as iOS does', async () => {
  await runKotlinFixture(await heartRateFixtureSource())
}, 240_000)
