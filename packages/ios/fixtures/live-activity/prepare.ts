import { join, resolve } from 'node:path'
import { build, init } from '../../src/index'

const output = resolve(process.argv[2] || '/tmp/craft-live-activity-layout')
const stxCli = process.env.STX_CLI
if (!stxCli) throw new Error('Set STX_CLI to the @stacksjs/stx CLI entrypoint')
const bundle = join(output, 'fixture.js')
await init({
  name: 'LiveActivityLayout',
  bundleId: 'dev.craft.liveactivitylayout',
  teamId: process.env.APPLE_TEAM_ID,
  output,
  runtimeDir: null,
  config: {
    renderer: 'native',
    enableLiveActivities: true,
    enableDeepLinks: true,
    urlSchemes: ['craft-live-layout'],
  },
})
const compile = Bun.spawnSync([process.execPath, resolve(stxCli), 'native', 'compile', join(import.meta.dir, 'Screen.stx'), '--format', 'bundle', '--output', bundle], { stdout: 'inherit', stderr: 'inherit' })
if (compile.exitCode !== 0) throw new Error('Fixture compilation failed')
await build({ output, nativeBundlePath: bundle, generateProject: false, runtimeDir: null })
console.log(`Prepared ${output}; generate its project.yml with XcodeGen, then build for a simulator or signed device.`)
