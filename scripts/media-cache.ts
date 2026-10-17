import { resolve } from 'node:path'

const packaged = process.env.CRAFT_PROBE_PACKAGED === '1'
const { verifyMobileMediaCache } = await import(packaged ? '../packages/typescript/dist/mobile-testing.js' : '../packages/typescript/src/mobile-testing.ts')

await verifyMobileMediaCache({
  platform: process.argv[2] as 'ios' | 'android',
  device: process.argv[2] === 'ios' ? process.env.IOS_SIMULATOR_UDID : process.env.ANDROID_SERIAL,
  sourceRoot: packaged ? undefined : resolve(import.meta.dir, '../packages'),
  storageOnly: process.argv.includes('--storage'),
  online: process.env.PROBE_GRADLE_ONLINE === '1',
})
