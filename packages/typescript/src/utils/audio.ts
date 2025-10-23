/**
 * Audio utilities for Zyte applications
 * Provides simple abstractions for common audio tasks
 */

export type NoiseType = 'whitenoise' | 'brownnoise' | 'ocean' | 'rain' | 'forest'
export type ToneType = 'bell' | 'chime' | 'gong' | 'gentle'

interface AudioInstance {
  source?: AudioBufferSourceNode
  source2?: OscillatorNode
  context: AudioContext
  gain: GainNode
}

/**
 * Audio Manager - Handles all audio generation and playback
 */
export class AudioManager {
  private backgroundAudio: AudioInstance | null = null

  private readonly toneFrequencies: Record<ToneType, number> = {
    bell: 880, // A5
    chime: 1046.5, // C6
    gong: 440, // A4
    gentle: 523.25, // C5
  }

  /**
   * Play a tone sound (bell, chime, gong, gentle)
   */
  playTone(type: ToneType, duration: number = 1.5): void {
    try {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
      const oscillator = audioContext.createOscillator()
      const gainNode = audioContext.createGain()

      oscillator.connect(gainNode)
      gainNode.connect(audioContext.destination)

      oscillator.frequency.value = this.toneFrequencies[type]
      oscillator.type = 'sine'

      // Envelope for a pleasant bell-like sound
      const now = audioContext.currentTime
      gainNode.gain.setValueAtTime(0.3, now)
      gainNode.gain.exponentialRampToValueAtTime(0.01, now + duration)

      oscillator.start(now)
      oscillator.stop(now + duration)
    }
    catch (e) {
      console.error('Failed to play tone:', e)
    }
  }

  /**
   * Generate and play background noise
   */
  playBackgroundNoise(type: NoiseType, volume: number = 0.5): void {
    this.stopBackgroundNoise()

    try {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
      const gainNode = audioContext.createGain()
      gainNode.gain.value = volume

      switch (type) {
        case 'whitenoise':
          this.generateWhiteNoise(audioContext, gainNode)
          break
        case 'brownnoise':
          this.generateBrownNoise(audioContext, gainNode)
          break
        case 'ocean':
          this.generateOceanWaves(audioContext, gainNode)
          break
        case 'rain':
          this.generateRain(audioContext, gainNode)
          break
        case 'forest':
          this.generateForest(audioContext, gainNode)
          break
      }
    }
    catch (e) {
      console.error('Failed to generate background noise:', e)
    }
  }

  /**
   * Stop background noise
   */
  stopBackgroundNoise(): void {
    if (this.backgroundAudio) {
      try {
        if (this.backgroundAudio.source)
          this.backgroundAudio.source.stop()
        if (this.backgroundAudio.source2)
          this.backgroundAudio.source2.stop()
        if (this.backgroundAudio.context)
          this.backgroundAudio.context.close()
        this.backgroundAudio = null
      }
      catch (e) {
        console.error('Failed to stop background noise:', e)
      }
    }
  }

  /**
   * Update background noise volume
   */
  setVolume(volume: number): void {
    if (this.backgroundAudio && this.backgroundAudio.gain) {
      this.backgroundAudio.gain.gain.value = volume
    }
  }

  private generateWhiteNoise(audioContext: AudioContext, gainNode: GainNode): void {
    const bufferSize = 2 * audioContext.sampleRate
    const noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
    const output = noiseBuffer.getChannelData(0)

    for (let i = 0; i < bufferSize; i++) {
      output[i] = Math.random() * 2 - 1
    }

    const source = audioContext.createBufferSource()
    source.buffer = noiseBuffer
    source.loop = true
    source.connect(gainNode)
    gainNode.connect(audioContext.destination)
    source.start(0)

    this.backgroundAudio = { source, context: audioContext, gain: gainNode }
  }

  private generateBrownNoise(audioContext: AudioContext, gainNode: GainNode): void {
    const bufferSize = 2 * audioContext.sampleRate
    const noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
    const output = noiseBuffer.getChannelData(0)
    let lastOut = 0

    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1
      output[i] = (lastOut + (0.02 * white)) / 1.02
      lastOut = output[i]
      output[i] *= 3.5
    }

    const source = audioContext.createBufferSource()
    source.buffer = noiseBuffer
    source.loop = true
    source.connect(gainNode)
    gainNode.connect(audioContext.destination)
    source.start(0)

    this.backgroundAudio = { source, context: audioContext, gain: gainNode }
  }

  private generateOceanWaves(audioContext: AudioContext, gainNode: GainNode): void {
    const bufferSize = 2 * audioContext.sampleRate
    const noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
    const output = noiseBuffer.getChannelData(0)

    // Generate brown noise for wave texture
    let lastOut = 0
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1
      output[i] = (lastOut + (0.02 * white)) / 1.02
      lastOut = output[i]
      output[i] *= 2.0
    }

    const source = audioContext.createBufferSource()
    source.buffer = noiseBuffer
    source.loop = true

    // Low-pass filter for muffled wave sound
    const filter = audioContext.createBiquadFilter()
    filter.type = 'lowpass'
    filter.frequency.value = 800
    filter.Q.value = 1

    // LFO for wave motion
    const lfo = audioContext.createOscillator()
    lfo.frequency.value = 0.15
    const lfoGain = audioContext.createGain()
    lfoGain.gain.value = 0.3

    source.connect(filter)
    filter.connect(gainNode)
    lfo.connect(lfoGain)
    lfoGain.connect(gainNode.gain)
    gainNode.connect(audioContext.destination)

    source.start(0)
    lfo.start(0)

    this.backgroundAudio = { source, source2: lfo, context: audioContext, gain: gainNode }
  }

  private generateRain(audioContext: AudioContext, gainNode: GainNode): void {
    const bufferSize = 2 * audioContext.sampleRate
    const noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
    const output = noiseBuffer.getChannelData(0)

    // Generate white noise with random intensity (raindrops)
    for (let i = 0; i < bufferSize; i++) {
      const intensity = Math.random() > 0.98 ? 2.0 : 1.0
      output[i] = (Math.random() * 2 - 1) * intensity
    }

    const source = audioContext.createBufferSource()
    source.buffer = noiseBuffer
    source.loop = true

    // High-pass filter for rain texture
    const filter = audioContext.createBiquadFilter()
    filter.type = 'highpass'
    filter.frequency.value = 400
    filter.Q.value = 0.5

    source.connect(filter)
    filter.connect(gainNode)
    gainNode.connect(audioContext.destination)
    source.start(0)

    this.backgroundAudio = { source, context: audioContext, gain: gainNode }
  }

  private generateForest(audioContext: AudioContext, gainNode: GainNode): void {
    const bufferSize = 2 * audioContext.sampleRate
    const noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
    const output = noiseBuffer.getChannelData(0)

    // Gentle rustling (pink-ish noise)
    let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1
      b0 = 0.99886 * b0 + white * 0.0555179
      b1 = 0.99332 * b1 + white * 0.0750759
      b2 = 0.96900 * b2 + white * 0.1538520
      b3 = 0.86650 * b3 + white * 0.3104856
      b4 = 0.55000 * b4 + white * 0.5329522
      b5 = -0.7616 * b5 - white * 0.0168980
      output[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
      b6 = white * 0.115926
    }

    const source = audioContext.createBufferSource()
    source.buffer = noiseBuffer
    source.loop = true

    // Band-pass filter for natural forest ambience
    const filter = audioContext.createBiquadFilter()
    filter.type = 'bandpass'
    filter.frequency.value = 1200
    filter.Q.value = 0.8

    source.connect(filter)
    filter.connect(gainNode)
    gainNode.connect(audioContext.destination)
    source.start(0)

    this.backgroundAudio = { source, context: audioContext, gain: gainNode }
  }
}
