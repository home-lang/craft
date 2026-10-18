import { afterEach, expect, test } from 'bun:test'
import { heartRate, location } from '../api/mobile'

const originalWindow = Object.getOwnPropertyDescriptor(globalThis, 'window')
afterEach(() => {
  if (originalWindow) Object.defineProperty(globalThis, 'window', originalWindow)
  else Reflect.deleteProperty(globalThis, 'window')
})

function host(capable: boolean) {
  const calls: unknown[][] = []
  const namespace = Object.fromEntries(['pauseRecording', 'resumeRecording', 'stopRecording', 'readRecording', 'getRecordingState', 'acknowledgeRecording'].map(method => [method, async (...args: unknown[]) => {
    calls.push([method, ...args])
    return method === 'acknowledgeRecording' ? true : method === 'readRecording' ? [] : { id: 'owned', active: true, paused: false, startedAt: 1 }
  }]))
  Object.defineProperty(globalThis, 'window', { configurable: true, value: { craft: {
    capabilities: { geolocation: true, heartRate: true, locationRecordingOwnership: capable, heartRateRecordingOwnership: capable },
    location: namespace, heartRate: namespace,
  } } })
  return calls
}

for (const [name, api] of [['GPS', location], ['heart rate', heartRate]] as const) {
  test(`${name} refuses guarded calls on an old host before any native operation`, async () => {
    const calls = host(false)
    expect(api.supportsRecordingOwnership()).toBe(false)
    for (const method of ['pauseRecording', 'resumeRecording', 'stopRecording', 'readRecording', 'getRecordingState', 'acknowledgeRecording'] as const)
      await expect(api[method]({ expectedId: 'owned' })).rejects.toMatchObject({ code: 'RECORDING_OWNERSHIP_UNSUPPORTED' })
    expect(calls).toEqual([])
  })

  test(`${name} forwards the expected recording ID through every guarded operation`, async () => {
    const calls = host(true)
    expect(api.supportsRecordingOwnership()).toBe(true)
    for (const method of ['pauseRecording', 'resumeRecording', 'stopRecording', 'readRecording', 'getRecordingState', 'acknowledgeRecording'] as const)
      await api[method]({ expectedId: 'owned' })
    expect(calls).toEqual(['pauseRecording', 'resumeRecording', 'stopRecording', 'readRecording', 'getRecordingState', 'acknowledgeRecording'].map(method => [method, { expectedId: 'owned' }]))
  })

  test(`${name} rejects malformed identities without turning them into an unfenced operation`, async () => {
    const calls = host(true)
    for (const expectedId of ['', '  ', null, undefined, 42]) {
      // Exercise JavaScript callers at the native boundary as well as typed callers.
      await expect(api.pauseRecording({ expectedId } as never)).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' })
    }
    expect(calls).toEqual([])
  })
}

test('heart-rate guarded reads preserve the existing since filter', async () => {
  const calls = host(true)
  await heartRate.readRecording({ expectedId: 'owned', since: 125 })
  expect(calls).toEqual([['readRecording', { expectedId: 'owned', since: 125 }]])
})
