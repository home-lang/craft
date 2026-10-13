import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import vm from 'node:vm'
import { describe, expect, it } from 'bun:test'

// The Web Audio API native screens get (CraftWebAudio.swift), run here
// against a fake native side. The simulator's NativeAudioUnitTests render
// what it sends; this checks what it sends and how it behaves as a browser's
// AudioContext does.

const swift = readFileSync(join(import.meta.dir, '../templates/CraftWebAudio.swift'), 'utf8')

function webAudioScript(): string {
  const start = swift.indexOf('static let script = #"""')
  if (start === -1) throw new Error('CraftWebAudio.swift no longer has `static let script = #"""`')
  const end = swift.indexOf('"""#', start)
  return swift.slice(swift.indexOf('\n', start) + 1, end)
}

type Command = [string, ...unknown[]]

/** A screen's script context with the native half faked. */
function screen() {
  const sent: Command[][] = []
  const buffers = new Map<number, { rate: number, length: number, channels: (Float32Array | null)[] }>()
  const states: [number, string][] = []
  let time = 0
  const reads = new Map<string, number>()
  const sandbox: Record<string, any> = {
    console: { log() {}, warn() {}, error() {} },
    craftNativeAudioOpen: (_id: number, rate: number) => ({ sampleRate: rate || 48000, outputLatency: 0.01 }),
    craftNativeAudioSend: (batch: Command[]) => { sent.push(batch) },
    craftNativeAudioTime: () => time,
    craftNativeAudioRead: (context: number, node: number, key: string) => reads.get(`${context}/${node}/${key}`) ?? Number.NaN,
    craftNativeAudioState: (id: number, state: string) => { states.push([id, state]); return true },
    craftNativeAudioBuffer: (id: number, rate: number, length: number, channels: (Float32Array | null)[]) => {
      buffers.set(id, { rate, length, channels: channels.map(channel => channel && channel.slice()) })
      return true
    },
  }
  vm.createContext(sandbox)
  vm.runInContext(webAudioScript(), sandbox)
  return {
    global: sandbox,
    run: (code: string) => vm.runInContext(code, sandbox),
    sent,
    commands: () => sent.flat(),
    buffers,
    states,
    reads,
    setTime: (seconds: number) => { time = seconds },
    /** Lets the queued commands go, as the end of a JavaScriptCore turn does. */
    settle: () => new Promise(resolve => setTimeout(resolve, 0)),
  }
}

describe('Web Audio on a native screen', () => {
  it('installs the browser\'s constructors and leaves a real AudioContext alone', () => {
    const page = screen()
    for (const name of ['AudioContext', 'webkitAudioContext', 'BaseAudioContext', 'AudioNode', 'AudioParam', 'AudioBuffer', 'GainNode', 'OscillatorNode', 'AudioBufferSourceNode', 'BiquadFilterNode', 'DelayNode', 'DynamicsCompressorNode', 'ConvolverNode'])
      expect(typeof page.global[name]).toBe('function')
    const marker = function AudioContext() {}
    const sandbox: Record<string, any> = { AudioContext: marker, craftNativeAudioOpen() {} }
    vm.createContext(sandbox)
    vm.runInContext(webAudioScript(), sandbox)
    expect(sandbox.AudioContext).toBe(marker)
  })

  it('builds a chained graph, sends it once per turn and schedules on the context clock', async () => {
    const page = screen()
    page.setTime(2)
    page.run(`
      var context = new AudioContext();
      var oscillator = context.createOscillator();
      oscillator.type = 'sawtooth';
      oscillator.frequency.setValueAtTime(220, context.currentTime);
      oscillator.frequency.exponentialRampToValueAtTime(440, context.currentTime + 1);
      var gain = context.createGain();
      gain.gain.value = 0.25;
      globalThis.chained = oscillator.connect(gain).connect(context.destination) === context.destination;
      oscillator.start(2.5);
      oscillator.stop(4);
    `)
    expect(page.global.chained).toBe(true)
    expect(page.sent).toHaveLength(0)
    await page.settle()
    expect(page.sent).toHaveLength(1)
    const commands = page.commands()
    const context = page.run('context._id')
    const oscillator = page.run('oscillator._id')
    const gain = page.run('gain._id')
    const destination = page.run('context.destination._id')
    expect(commands).toContainEqual(['create', context, destination, 'destination', 0])
    expect(commands).toContainEqual(['create', context, oscillator, 'oscillator', 0])
    expect(commands).toContainEqual(['type', context, oscillator, 2])
    expect(commands).toContainEqual(['param', context, oscillator, 'frequency', 'set', 220, 2, 0])
    // A ramp carries the time it was asked for: where a ramp after setTarget starts.
    expect(commands).toContainEqual(['param', context, oscillator, 'frequency', 'exponential', 440, 3, 2])
    // Setting `value` is setValueAtTime at the context's current time.
    expect(commands).toContainEqual(['param', context, gain, 'gain', 'set', 0.25, 2, 0])
    expect(commands).toContainEqual(['connect', context, oscillator, gain])
    expect(commands).toContainEqual(['connect', context, gain, destination])
    expect(commands).toContainEqual(['start', context, oscillator, 2.5, 0, -1])
    expect(commands).toContainEqual(['stop', context, oscillator, 4])
  })

  it('throws where a browser throws', () => {
    const page = screen()
    page.run('var context = new AudioContext(); var o = context.createOscillator(); var g = context.createGain();')
    expect(() => page.run('o.stop()')).toThrow('stop() needs start() first')
    page.run('o.start()')
    expect(() => page.run('o.start()')).toThrow('start() may be called only once')
    // The script's realm has its own RangeError and TypeError.
    const rangeError = (code: string) => page.run(`try { ${code}; 'none' } catch (error) { error instanceof RangeError ? 'RangeError' : String(error) }`)
    expect(rangeError('g.gain.exponentialRampToValueAtTime(0, 1)')).toBe('RangeError')
    expect(rangeError('g.gain.setValueAtTime(1, -1)')).toBe('RangeError')
    expect(rangeError('g.gain.setTargetAtTime(1, 0, -1)')).toBe('RangeError')
    expect(() => page.run('o.type = "custom"')).toThrow('setPeriodicWave')
    expect(() => page.run('context.createDelay(200)')).toThrow('maxDelayTime')
    expect(() => page.run('o.connect({})')).toThrow('connect needs an AudioNode or an AudioParam')
    expect(() => page.run('o.connect(new AudioContext().destination)')).toThrow('another AudioContext')
    // An unknown enum value is ignored, as WebIDL does.
    page.run('o.type = "noise"')
    expect(page.run('o.type')).toBe('sine')
  })

  it('connects a node into a param and disconnects every way', async () => {
    const page = screen()
    page.run(`
      var context = new AudioContext();
      var lfo = context.createOscillator();
      var depth = context.createGain();
      var gain = context.createGain();
      globalThis.returned = lfo.connect(depth).connect(gain.gain);
      depth.disconnect(gain.gain);
      depth.disconnect(gain);
      depth.disconnect();
    `)
    await page.settle()
    const [context, depth, gain] = ['context._id', 'depth._id', 'gain._id'].map(page.run)
    expect(page.global.returned).toBeUndefined()
    expect(page.commands()).toContainEqual(['connectParam', context, depth, gain, 'gain'])
    expect(page.commands()).toContainEqual(['disconnect', context, depth, gain, 'gain'])
    expect(page.commands()).toContainEqual(['disconnect', context, depth, gain, null])
    expect(page.commands()).toContainEqual(['disconnect', context, depth, null, null])
  })

  it('hands a buffer\'s samples over once, and again after the script writes to it', async () => {
    const page = screen()
    page.run(`
      var context = new AudioContext();
      var buffer = context.createBuffer(2, 4, context.sampleRate);
      buffer.getChannelData(0).set([0.5, -0.5, 0.25, 0]);
      var first = context.createBufferSource();
      first.buffer = buffer;
      first.loop = true;
      first.start(0, 0.5, 2);
      var second = context.createBufferSource();
      second.buffer = buffer;
      second.start();
    `)
    await page.settle()
    const id = page.run('buffer._id')
    expect(page.buffers.get(id)?.length).toBe(4)
    expect([...page.buffers.get(id)!.channels[0]!]).toEqual([0.5, -0.5, 0.25, 0])
    // A channel never touched goes over as nothing: native fills zeros.
    expect(page.buffers.get(id)!.channels[1]).toBeNull()
    const commands = page.commands()
    const first = page.run('first._id')
    expect(commands).toContainEqual(['loop', page.run('context._id'), first, true, 0, 0])
    expect(commands).toContainEqual(['buffer', page.run('context._id'), first, id])
    expect(commands).toContainEqual(['start', page.run('context._id'), first, 0, 0.5, 2])
    let uploads = 0
    const upload = page.global.craftNativeAudioBuffer
    page.global.craftNativeAudioBuffer = (...args: any[]) => { uploads++; return upload(...args) }
    page.run('var third = context.createBufferSource(); third.buffer = buffer; third.start();')
    expect(uploads).toBe(0)
    page.run('buffer.getChannelData(1)[0] = 1; var fourth = context.createBufferSource(); fourth.buffer = buffer; fourth.start();')
    expect(uploads).toBe(1)
    expect(() => page.run('fourth.buffer = buffer')).toThrow('only once')
  })

  it('checks a convolver\'s impulse response and sends its normalisation', async () => {
    const page = screen()
    page.run(`
      var context = new AudioContext();
      var reverb = context.createConvolver();
      var impulse = context.createBuffer(2, 64, context.sampleRate);
      reverb.normalize = false;
      reverb.buffer = impulse;
    `)
    await page.settle()
    expect(page.commands()).toContainEqual(['convolver', page.run('context._id'), page.run('reverb._id'), page.run('impulse._id'), false])
    expect(page.buffers.has(page.run('impulse._id'))).toBe(true)
    expect(() => page.run('context.createConvolver().buffer = context.createBuffer(3, 8, context.sampleRate)')).toThrow('1, 2 or 4')
    expect(() => page.run('context.createConvolver().buffer = context.createBuffer(1, 8, 22050)')).toThrow('sample rate')
  })

  it('fires onended and ended listeners once the host says a source ended, then lets it go', async () => {
    const page = screen()
    page.run(`
      var context = new AudioContext();
      var heard = [];
      var tone = context.createOscillator();
      tone.onended = function(event) { heard.push('onended:' + (event.target === tone)); };
      tone.addEventListener('ended', function() { heard.push('listener'); });
      tone.start(0);
      tone.stop(0.1);
    `)
    await page.settle()
    const [context, tone] = ['context._id', 'tone._id'].map(page.run)
    expect(page.run(`Object.keys(context._playing).length`)).toBe(1)
    page.run(`__craftNativeAudioEvents([[${context}, ${tone}, 'ended'], [${context}, 999, 'ended']])`)
    expect(page.run('heard.join("|")')).toBe('onended:true|listener')
    expect(page.run(`Object.keys(context._playing).length`)).toBe(0)
    // Only once, as the node is no longer playing.
    page.run(`__craftNativeAudioEvents([[${context}, ${tone}, 'ended']])`)
    expect(page.run('heard.length')).toBe(2)
  })

  it('suspends, resumes and closes, with statechange, and reads the clock from the host', async () => {
    const page = screen()
    page.setTime(1.5)
    page.run(`
      var context = new AudioContext({ sampleRate: 44100 });
      var changes = [];
      context.onstatechange = function() { changes.push(context.state); };
    `)
    expect(page.run('context.sampleRate')).toBe(44100)
    expect(page.run('context.currentTime')).toBe(1.5)
    expect(page.run('context.state')).toBe('running')
    await page.run('context.suspend()')
    await page.run('context.resume()')
    await page.run('context.close()')
    await page.settle()
    expect(page.run('changes.join(",")')).toBe('suspended,running,closed')
    const id = page.run('context._id')
    expect(page.states).toEqual([[id, 'suspended'], [id, 'running'], [id, 'closed']])
    page.setTime(9)
    // A closed context's clock stops where it closed.
    expect(page.run('context.currentTime')).toBe(1.5)
    await expect(page.run('context.resume()')).rejects.toThrow('closed')
    expect(() => page.run('new AudioContext({ sampleRate: 100 })')).toThrow('sampleRate')
  })

  it('reads automated params and the compressor\'s reduction from the host', async () => {
    const page = screen()
    page.run(`
      var context = new AudioContext();
      var gain = context.createGain();
      var squeeze = context.createDynamicsCompressor();
      squeeze.threshold.value = -18;
      gain.gain.value = 0.5;
    `)
    expect(page.run('gain.gain.value')).toBe(0.5)
    expect(page.run('squeeze.threshold.value')).toBe(-18)
    expect(page.run('squeeze.ratio.value')).toBe(12)
    const [context, gain, squeeze] = ['context._id', 'gain._id', 'squeeze._id'].map(page.run)
    page.run('gain.gain.linearRampToValueAtTime(1, 2)')
    page.reads.set(`${context}/${gain}/gain`, 0.75)
    page.reads.set(`${context}/${squeeze}/reduction`, -3.5)
    expect(page.run('gain.gain.value')).toBe(0.75)
    expect(page.run('squeeze.reduction')).toBe(-3.5)
    // Reading flushes what was queued, so the host reads its newest state.
    expect(page.sent.length).toBeGreaterThan(0)
  })

  it('releases nodes and buffers the script lets go of', async () => {
    const page = screen()
    page.run(`
      var context = new AudioContext();
      (function() {
        for (var i = 0; i < 50; i++) {
          var gain = context.createGain();
          gain.connect(context.destination);
          context.createBuffer(1, 128, context.sampleRate);
        }
      })();
    `)
    let released: Command[] = []
    for (let attempt = 0; attempt < 50 && released.length < 10; attempt++) {
      Bun.gc(true)
      await new Promise(resolve => setTimeout(resolve, 10))
      released = page.commands().filter(command => command[0] === 'release' || command[0] === 'releaseBuffer')
    }
    expect(released.length).toBeGreaterThan(0)
    // The destination is never released.
    const destination = page.run('context.destination._id')
    expect(released.some(command => command[0] === 'release' && command[2] === destination)).toBe(false)
  })

  it('refuses audio files with a clear error, since there is nothing to decode them', async () => {
    const page = screen()
    let callback: unknown
    page.global.onError = (error: unknown) => { callback = error }
    await expect(page.run('new AudioContext().decodeAudioData(new ArrayBuffer(8), null, onError)')).rejects.toThrow('craft.audio')
    expect(String(callback)).toContain('NotSupportedError')
  })
})
