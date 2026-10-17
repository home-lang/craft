import { expect, test } from 'bun:test'
import { verifyMobileMediaCache } from '../mobile-testing'

test('media cache tests reject an unknown platform before creating a probe', async () => {
  await expect(verifyMobileMediaCache({ platform: 'desktop' as any })).rejects.toThrow('Choose ios or android')
})

test('media cache tests refuse physical and implicit Android devices', async () => {
  await expect(verifyMobileMediaCache({ platform: 'android' })).rejects.toThrow('explicit disposable Android emulator')
  await expect(verifyMobileMediaCache({ platform: 'android', device: 'phone-123' })).rejects.toThrow('explicit disposable Android emulator')
})

test('media cache tests refuse implicit iOS device selectors', async () => {
  await expect(verifyMobileMediaCache({ platform: 'ios', device: 'booted' })).rejects.toThrow('simulator UUID')
})

test('media cache source overrides must be explicit local paths', async () => {
  await expect(verifyMobileMediaCache({ platform: 'ios', sourceRoot: 'https://example.invalid' })).rejects.toThrow('absolute local path')
})
