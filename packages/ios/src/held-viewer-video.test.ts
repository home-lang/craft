import { expect, test } from 'bun:test'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { selectHeldVideoFrame, validateHeldVideoFrame } from '../scripts/held-viewer-video'
import { createTempDir, removeTempDir } from '../../typescript/src/temp-dir'

const window = { recordSpawnWall: 100, recordingStartedObservedWall: 100.5, synthesisWall: 102, releasedWall: 108 }
const firstPTS = { value: 0, timescale: 600 }
const selectedPTS = { value: 2400, timescale: 600 }

test('actual decoded frame qualifies only when both first-frame wall bounds fit inside the real hold', () => {
  expect(validateHeldVideoFrame({ ...window, firstPTS, selectedPTS, actualPTS: { value: 4000, timescale: 1000 } }))
    .toEqual({ frameWallEarliest: 104, frameWallLatest: 104.5, frameOffsetFromFirstPTS: 4 })
  expect(selectHeldVideoFrame(window, [firstPTS, { value: 600, timescale: 600 }, selectedPTS])).toEqual(selectedPTS)
})

test('static frame zero cannot qualify as a middle-of-recording image', () => {
  expect(() => selectHeldVideoFrame(window, [firstPTS])).toThrow('No decoded frame')
  expect(() => validateHeldVideoFrame({ ...window, firstPTS, selectedPTS: firstPTS, actualPTS: firstPTS })).toThrow('whole frame capture interval')
})

test('requested time cannot replace extractor actualTime or exact rational equivalence', () => {
  expect(() => validateHeldVideoFrame({ ...window, firstPTS, selectedPTS, actualPTS: firstPTS })).toThrow('actual PTS differs')
  expect(() => validateHeldVideoFrame({ ...window, firstPTS, selectedPTS, actualPTS: { value: 2401, timescale: 600 } })).toThrow('actual PTS differs')
})

test('first-frame uncertainty must fit completely, with strict synthesis and release boundaries', () => {
  const input = { ...window, firstPTS, selectedPTS, actualPTS: selectedPTS }
  expect(() => validateHeldVideoFrame({ ...input, recordingStartedObservedWall: 102, releasedWall: 106 })).toThrow('six-second')
  expect(() => validateHeldVideoFrame({ ...input, recordSpawnWall: 98 })).toThrow('whole frame')
  expect(() => validateHeldVideoFrame({ ...input, recordingStartedObservedWall: 102, releasedWall: 108, selectedPTS: { value: 3600, timescale: 600 }, actualPTS: { value: 3600, timescale: 600 } })).toThrow('whole frame')
  expect(() => validateHeldVideoFrame({ ...input, recordingStartedObservedWall: 102.1 })).toThrow('before')
})

test('invalid clocks and media times fail closed, including unsafe integers and nonzero source origins', () => {
  const input = { ...window, firstPTS, selectedPTS, actualPTS: selectedPTS }
  for (const bad of [Number.NaN, Number.POSITIVE_INFINITY, -1])
    expect(() => validateHeldVideoFrame({ ...input, synthesisWall: bad })).toThrow()
  for (const bad of [{ value: 1, timescale: 0 }, { value: 1.5, timescale: 600 }, { value: Number.MAX_SAFE_INTEGER + 1, timescale: 600 }])
    expect(() => validateHeldVideoFrame({ ...input, actualPTS: bad })).toThrow('rational')
  expect(validateHeldVideoFrame({ ...input, firstPTS: { value: 6000, timescale: 600 }, selectedPTS: { value: 8400, timescale: 600 }, actualPTS: { value: 14000, timescale: 1000 } }).frameOffsetFromFirstPTS).toBe(4)
  expect(() => selectHeldVideoFrame(window, [])).toThrow('no decoded')
})

test('sparse viewer frame before 750ms remains valid when its whole interval is strictly within the hold', () => {
  const frame = { value: 1350, timescale: 600 }
  expect(validateHeldVideoFrame({ ...window, firstPTS, selectedPTS: frame, actualPTS: frame }))
    .toEqual({ frameWallEarliest: 102.25, frameWallLatest: 102.75, frameOffsetFromFirstPTS: 2.25 })
})

test.skipIf(process.platform !== 'darwin')('public AVFoundation extractor verifies actual media frames and rejects static footage', () => {
  const dir = createTempDir('craft-held-video-test-')
  const run = (args: string[]) => Bun.spawnSync(args, { stdout: 'pipe', stderr: 'pipe', timeout: 20_000 })
  try {
    const generator = join(dir, 'media.swift'), movieTool = join(dir, 'media'), extractor = join(dir, 'extract')
    // Synthetic media only: these pixels test source-frame identity, not a
    // native Large Content Viewer, an app, a gesture, or simulator acceptance.
    writeFileSync(generator, `import AVFoundation
import CoreVideo
import Foundation
let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: CommandLine.arguments[1]), fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64])
writer.add(input)
guard writer.startWriting() else { fatalError("Cannot write synthetic media") }
writer.startSession(atSourceTime: .zero)
for index in 0..<(CommandLine.arguments[2] == "static" ? 1 : 7) {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.001) }
    var buffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer) == kCVReturnSuccess, let buffer else { fatalError("No pixel buffer") }
    CVPixelBufferLockBaseAddress(buffer, [])
    memset(CVPixelBufferGetBaseAddress(buffer), Int32(20 + index * 30), CVPixelBufferGetDataSize(buffer))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 1)) else { fatalError("Cannot append synthetic frame") }
}
writer.endSession(atSourceTime: CMTime(value: 7, timescale: 1))
input.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fatalError("Synthetic movie incomplete") }
`)
    for (const args of [['xcrun', 'swiftc', generator, '-o', movieTool], ['xcrun', 'swiftc', join(import.meta.dir, '../scripts/held-viewer-frame.swift'), '-o', extractor]]) {
      const result = run(args)
      expect(result.exitCode, result.stderr.toString()).toBe(0)
    }
    for (const mode of ['moving', 'static']) {
      const movie = join(dir, `${mode}.mov`), png = join(dir, `${mode}.png`), receipt = join(dir, `${mode}.json`)
      const media = run([movieTool, movie, mode])
      expect(media.exitCode, media.stderr.toString()).toBe(0)
      const result = run([extractor, movie, png, receipt, '100', '100.25', '101', '107'])
      const evidence = JSON.parse(readFileSync(receipt, 'utf8'))
      if (mode === 'moving') {
        expect(result.exitCode, result.stderr.toString()).toBe(0)
        expect(evidence.verified).toBe(true)
        expect(validateHeldVideoFrame(evidence)).toMatchObject({ frameWallEarliest: 104, frameWallLatest: 104.25 })
        expect(evidence.actualPTS.value / evidence.actualPTS.timescale).toBe(4)
        expect(evidence.pngSha256).toBe(new Bun.CryptoHasher('sha256').update(readFileSync(png)).digest('hex'))
        expect(evidence.movieSha256).toBe(new Bun.CryptoHasher('sha256').update(readFileSync(movie)).digest('hex'))
      }
      else {
        expect(result.exitCode).toBe(1)
        expect(evidence.verified).toBe(false)
        expect(evidence.error).toContain('No decoded frame')
        expect(existsSync(png)).toBe(false)
      }
    }
  }
  finally { removeTempDir(dir) }
}, 45_000)
