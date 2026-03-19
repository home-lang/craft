import { state, derived } from '../runtime'

export interface PlatformInfo {
  platform: 'macos' | 'linux' | 'windows' | 'ios' | 'android' | 'web'
  isDesktop: boolean
  isMobile: boolean
  isWeb: boolean
}

/**
 * Detect the current platform via signals.
 *
 * @example
 * const { platform, isDesktop, isMobile } = usePlatform()
 * if (isMobile()) { ... }
 */
export function usePlatform() {
  const platform = state<PlatformInfo>(detectPlatform())

  return {
    platform,
    isDesktop: derived(() => platform().isDesktop),
    isMobile: derived(() => platform().isMobile),
    isWeb: derived(() => platform().isWeb),
  }
}

function detectPlatform(): PlatformInfo {
  if (typeof window === 'undefined') {
    return { platform: 'web', isDesktop: false, isMobile: false, isWeb: true }
  }

  const ua = navigator.userAgent.toLowerCase()

  if (/iphone|ipad|ipod/.test(ua)) {
    return { platform: 'ios', isDesktop: false, isMobile: true, isWeb: false }
  }
  if (/android/.test(ua)) {
    return { platform: 'android', isDesktop: false, isMobile: true, isWeb: false }
  }
  if (/macintosh|mac os/.test(ua)) {
    return { platform: 'macos', isDesktop: true, isMobile: false, isWeb: false }
  }
  if (/windows/.test(ua)) {
    return { platform: 'windows', isDesktop: true, isMobile: false, isWeb: false }
  }
  if (/linux/.test(ua)) {
    return { platform: 'linux', isDesktop: true, isMobile: false, isWeb: false }
  }

  return { platform: 'web', isDesktop: false, isMobile: false, isWeb: true }
}
