/**
 * Craft Media API
 * Cross-platform camera and microphone access for desktop and mobile.
 *
 * @example
 * ```typescript
 * import { media } from '@aspect/craft'
 *
 * // List available cameras and microphones
 * const devices = await media.enumerateDevices()
 * const cameras = devices.filter(d => d.kind === 'videoinput')
 * const microphones = devices.filter(d => d.kind === 'audioinput')
 *
 * // Get camera stream
 * const stream = await media.getCamera()
 *
 * // Get microphone stream
 * const audioStream = await media.getMicrophone()
 *
 * // Get both camera and microphone
 * const avStream = await media.getMediaStream({ video: true, audio: true })
 *
 * // Check if media access is available
 * const hasCamera = await media.hasCameraAccess()
 * const hasMic = await media.hasMicrophoneAccess()
 * ```
 */

/**
 * Media device information
 */
export interface MediaDeviceInfo {
  /** Unique device identifier */
  deviceId: string
  /** Device group ID (devices sharing same physical device) */
  groupId: string
  /** Device type: 'audioinput' | 'audiooutput' | 'videoinput' */
  kind: 'audioinput' | 'audiooutput' | 'videoinput'
  /** Human-readable device label */
  label: string
}

/**
 * Camera options
 */
export interface CameraOptions {
  /** Preferred camera device ID */
  deviceId?: string
  /** Prefer front or back camera (mobile) */
  facingMode?: 'user' | 'environment'
  /** Preferred width */
  width?: number | { min?: number; ideal?: number; max?: number }
  /** Preferred height */
  height?: number | { min?: number; ideal?: number; max?: number }
  /** Preferred frame rate */
  frameRate?: number | { min?: number; ideal?: number; max?: number }
  /** Aspect ratio */
  aspectRatio?: number | { min?: number; ideal?: number; max?: number }
}

/**
 * Microphone options
 */
export interface MicrophoneOptions {
  /** Preferred microphone device ID */
  deviceId?: string
  /** Enable echo cancellation */
  echoCancellation?: boolean
  /** Enable noise suppression */
  noiseSuppression?: boolean
  /** Enable auto gain control */
  autoGainControl?: boolean
  /** Sample rate in Hz */
  sampleRate?: number
  /** Number of channels (1 = mono, 2 = stereo) */
  channelCount?: number
}

/**
 * Combined media stream options
 */
export interface MediaStreamOptions {
  /** Enable video capture */
  video?: boolean | CameraOptions
  /** Enable audio capture */
  audio?: boolean | MicrophoneOptions
}

/**
 * Media API for camera and microphone access.
 * Works across macOS, Linux, Windows, iOS, and Android.
 */
export const media = {
  /**
   * Enumerate all available media devices (cameras, microphones, speakers).
   *
   * @returns Promise resolving to array of media devices
   * @example
   * ```typescript
   * const devices = await media.enumerateDevices()
   * const cameras = devices.filter(d => d.kind === 'videoinput')
   * console.log('Available cameras:', cameras.map(c => c.label))
   * ```
   */
  async enumerateDevices(): Promise<MediaDeviceInfo[]> {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      return []
    }

    try {
      const devices = await navigator.mediaDevices.enumerateDevices()
      return devices.map((d) => ({
        deviceId: d.deviceId,
        groupId: d.groupId,
        kind: d.kind as 'audioinput' | 'audiooutput' | 'videoinput',
        label: d.label || `${d.kind} (${d.deviceId.slice(0, 8)}...)`,
      }))
    } catch {
      return []
    }
  },

  /**
   * Get list of available cameras.
   *
   * @returns Promise resolving to array of camera devices
   */
  async getCameras(): Promise<MediaDeviceInfo[]> {
    const devices = await this.enumerateDevices()
    return devices.filter((d) => d.kind === 'videoinput')
  },

  /**
   * Get list of available microphones.
   *
   * @returns Promise resolving to array of microphone devices
   */
  async getMicrophones(): Promise<MediaDeviceInfo[]> {
    const devices = await this.enumerateDevices()
    return devices.filter((d) => d.kind === 'audioinput')
  },

  /**
   * Get list of available audio output devices (speakers/headphones).
   *
   * @returns Promise resolving to array of speaker devices
   */
  async getSpeakers(): Promise<MediaDeviceInfo[]> {
    const devices = await this.enumerateDevices()
    return devices.filter((d) => d.kind === 'audiooutput')
  },

  /**
   * Get a camera video stream.
   *
   * @param options - Camera options
   * @returns Promise resolving to MediaStream
   * @example
   * ```typescript
   * // Get default camera
   * const stream = await media.getCamera()
   *
   * // Get specific camera with HD resolution
   * const hdStream = await media.getCamera({
   *   deviceId: 'abc123',
   *   width: { ideal: 1920 },
   *   height: { ideal: 1080 }
   * })
   *
   * // Use in video element
   * videoElement.srcObject = stream
   * ```
   */
  async getCamera(options?: CameraOptions): Promise<MediaStream> {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      throw new Error('Media devices not available')
    }

    const constraints: MediaStreamConstraints = {
      video: options
        ? {
            deviceId: options.deviceId ? { exact: options.deviceId } : undefined,
            facingMode: options.facingMode,
            width: options.width,
            height: options.height,
            frameRate: options.frameRate,
            aspectRatio: options.aspectRatio,
          }
        : true,
      audio: false,
    }

    return navigator.mediaDevices.getUserMedia(constraints)
  },

  /**
   * Get a microphone audio stream.
   *
   * @param options - Microphone options
   * @returns Promise resolving to MediaStream
   * @example
   * ```typescript
   * // Get default microphone
   * const stream = await media.getMicrophone()
   *
   * // Get microphone with noise suppression
   * const cleanStream = await media.getMicrophone({
   *   echoCancellation: true,
   *   noiseSuppression: true
   * })
   * ```
   */
  async getMicrophone(options?: MicrophoneOptions): Promise<MediaStream> {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      throw new Error('Media devices not available')
    }

    const constraints: MediaStreamConstraints = {
      video: false,
      audio: options
        ? {
            deviceId: options.deviceId ? { exact: options.deviceId } : undefined,
            echoCancellation: options.echoCancellation,
            noiseSuppression: options.noiseSuppression,
            autoGainControl: options.autoGainControl,
            sampleRate: options.sampleRate,
            channelCount: options.channelCount,
          }
        : true,
    }

    return navigator.mediaDevices.getUserMedia(constraints)
  },

  /**
   * Get a combined audio/video stream.
   *
   * @param options - Media stream options
   * @returns Promise resolving to MediaStream
   * @example
   * ```typescript
   * // Get both camera and microphone
   * const stream = await media.getMediaStream({ video: true, audio: true })
   *
   * // Get camera with specific settings and microphone with noise suppression
   * const stream = await media.getMediaStream({
   *   video: { width: 1280, height: 720 },
   *   audio: { noiseSuppression: true }
   * })
   * ```
   */
  async getMediaStream(options: MediaStreamOptions): Promise<MediaStream> {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      throw new Error('Media devices not available')
    }

    const constraints: MediaStreamConstraints = {
      video: options.video === true ? true : options.video ? this._buildVideoConstraints(options.video) : false,
      audio: options.audio === true ? true : options.audio ? this._buildAudioConstraints(options.audio) : false,
    }

    return navigator.mediaDevices.getUserMedia(constraints)
  },

  /**
   * Check if camera access is available (permission granted or can be requested).
   *
   * @returns Promise resolving to boolean
   */
  async hasCameraAccess(): Promise<boolean> {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      return false
    }

    try {
      // Try to get permissions state
      if (navigator.permissions) {
        const result = await navigator.permissions.query({ name: 'camera' as PermissionName })
        if (result.state === 'denied') return false
      }

      // Try to enumerate devices - if we have labels, we have permission
      const devices = await navigator.mediaDevices.enumerateDevices()
      const cameras = devices.filter((d) => d.kind === 'videoinput')
      return cameras.length > 0
    } catch {
      return false
    }
  },

  /**
   * Check if microphone access is available (permission granted or can be requested).
   *
   * @returns Promise resolving to boolean
   */
  async hasMicrophoneAccess(): Promise<boolean> {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      return false
    }

    try {
      // Try to get permissions state
      if (navigator.permissions) {
        const result = await navigator.permissions.query({ name: 'microphone' as PermissionName })
        if (result.state === 'denied') return false
      }

      // Try to enumerate devices - if we have labels, we have permission
      const devices = await navigator.mediaDevices.enumerateDevices()
      const mics = devices.filter((d) => d.kind === 'audioinput')
      return mics.length > 0
    } catch {
      return false
    }
  },

  /**
   * Request camera and/or microphone permission.
   * This will prompt the user for permission if not already granted.
   *
   * @param options - What to request (camera, microphone, or both)
   * @returns Promise resolving to true if granted
   */
  async requestPermission(options: { camera?: boolean; microphone?: boolean } = {}): Promise<boolean> {
    const { camera = false, microphone = false } = options

    if (!camera && !microphone) {
      return true
    }

    try {
      const stream = await this.getMediaStream({
        video: camera,
        audio: microphone,
      })
      // Stop all tracks immediately - we just needed to trigger the permission
      stream.getTracks().forEach((track) => track.stop())
      return true
    } catch {
      return false
    }
  },

  /**
   * Stop all tracks in a media stream.
   *
   * @param stream - MediaStream to stop
   */
  stopStream(stream: MediaStream): void {
    stream.getTracks().forEach((track) => track.stop())
  },

  /**
   * Listen for device changes (camera/microphone plugged in or removed).
   *
   * @param callback - Function called when devices change
   * @returns Cleanup function to remove listener
   */
  onDeviceChange(callback: () => void): () => void {
    if (typeof navigator === 'undefined' || !navigator.mediaDevices) {
      return () => {}
    }

    navigator.mediaDevices.addEventListener('devicechange', callback)
    return () => navigator.mediaDevices.removeEventListener('devicechange', callback)
  },

  // Internal helper to build video constraints
  _buildVideoConstraints(options: CameraOptions): MediaTrackConstraints {
    return {
      deviceId: options.deviceId ? { exact: options.deviceId } : undefined,
      facingMode: options.facingMode,
      width: options.width,
      height: options.height,
      frameRate: options.frameRate,
      aspectRatio: options.aspectRatio,
    }
  },

  // Internal helper to build audio constraints
  _buildAudioConstraints(options: MicrophoneOptions): MediaTrackConstraints {
    return {
      deviceId: options.deviceId ? { exact: options.deviceId } : undefined,
      echoCancellation: options.echoCancellation,
      noiseSuppression: options.noiseSuppression,
      autoGainControl: options.autoGainControl,
      sampleRate: options.sampleRate,
      channelCount: options.channelCount,
    }
  },
}

export default media
