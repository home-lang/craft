import { ref, computed, onMounted, onUnmounted } from 'vue'
import type {
  CraftBridgeAPI,
  DeviceInfo,
  Permission,
  PermissionStatus,
  HapticType,
  NotificationOptions,
} from '@craft/types'

declare global {
  interface Window {
    craft: CraftBridgeAPI
  }
}

/**
 * Composable to access the Craft bridge
 */
export function useCraft() {
  return window.craft
}

/**
 * Composable for window management (desktop)
 */
export function useWindow() {
  const craft = useCraft()

  const show = () => craft.window?.show()
  const hide = () => craft.window?.hide()
  const toggle = () => craft.window?.toggle()
  const minimize = () => craft.window?.minimize()
  const close = () => craft.window?.close()

  return { show, hide, toggle, minimize, close }
}

/**
 * Composable for system tray management (desktop)
 */
export function useTray() {
  const craft = useCraft()

  const setTitle = (title: string) => craft.tray?.setTitle(title)
  const setTooltip = (tooltip: string) => craft.tray?.setTooltip(tooltip)

  const onClick = (callback: () => void) => {
    return craft.tray?.onClick(() => callback())
  }

  const onClickToggleWindow = () => {
    return craft.tray?.onClickToggleWindow()
  }

  return { setTitle, setTooltip, onClick, onClickToggleWindow }
}

/**
 * Composable for notifications
 */
export function useNotification() {
  const craft = useCraft()

  const notify = (options: NotificationOptions) => {
    return craft.app.notify(options)
  }

  return { notify }
}

/**
 * Composable for mobile device information
 */
export function useDeviceInfo() {
  const deviceInfo = ref<DeviceInfo | null>(null)
  const craft = useCraft()

  onMounted(async () => {
    if (craft.mobile) {
      deviceInfo.value = await craft.mobile.getDeviceInfo()
    }
  })

  return { deviceInfo: computed(() => deviceInfo.value) }
}

/**
 * Composable for mobile permissions
 */
export function usePermission(permission: Permission) {
  const status = ref<PermissionStatus>('notDetermined')
  const craft = useCraft()

  const request = async () => {
    if (!craft.mobile) return
    const newStatus = await craft.mobile.requestPermission(permission)
    status.value = newStatus
    return newStatus
  }

  const check = async () => {
    if (!craft.mobile) return
    const currentStatus = await craft.mobile.checkPermission(permission)
    status.value = currentStatus
    return currentStatus
  }

  onMounted(() => {
    check()
  })

  return { status: computed(() => status.value), request, check }
}

/**
 * Composable for mobile haptics
 */
export function useHaptic() {
  const craft = useCraft()

  const trigger = (type: HapticType) => {
    return craft.mobile?.haptic(type)
  }

  return { trigger }
}

/**
 * Composable for mobile vibration
 */
export function useVibrate() {
  const craft = useCraft()

  const vibrate = (duration: number) => {
    return craft.mobile?.vibrate(duration)
  }

  return { vibrate }
}

/**
 * Composable for mobile toast messages
 */
export function useToast() {
  const craft = useCraft()

  const show = (message: string, duration?: number) => {
    return craft.mobile?.toast(message, duration)
  }

  return { show }
}

/**
 * Composable for camera access
 */
export function useCamera() {
  const craft = useCraft()

  const open = (options?: { type?: 'front' | 'back', mediaType?: 'photo' | 'video' }) => {
    return craft.mobile?.openCamera(options)
  }

  return { open }
}

/**
 * Composable for photo picker
 */
export function usePhotoPicker() {
  const craft = useCraft()

  const pick = (options?: { maxSelections?: number, mediaType?: 'photo' | 'video' | 'all' }) => {
    return craft.mobile?.pickPhoto(options)
  }

  return { pick }
}

/**
 * Composable for sharing
 */
export function useShare() {
  const craft = useCraft()

  const share = (options: { text?: string, url?: string, title?: string }) => {
    return craft.mobile?.share(options)
  }

  return { share }
}

/**
 * Composable for biometric authentication
 */
export function useBiometric() {
  const available = ref(false)
  const craft = useCraft()

  onMounted(async () => {
    if (craft.mobile) {
      available.value = await craft.mobile.isBiometricAvailable()
    }
  })

  const authenticate = (reason: string) => {
    return craft.mobile?.authenticateBiometric(reason)
  }

  return { available: computed(() => available.value), authenticate }
}

/**
 * Composable for secure storage
 */
export function useSecureStorage() {
  const craft = useCraft()

  const store = (key: string, value: string) => {
    return craft.mobile?.secureStore(key, value)
  }

  const retrieve = (key: string) => {
    return craft.mobile?.secureRetrieve(key)
  }

  const remove = (key: string) => {
    return craft.mobile?.secureDelete(key)
  }

  return { store, retrieve, remove }
}

/**
 * Composable for file system operations
 */
export function useFileSystem() {
  const craft = useCraft()

  const readFile = (path: string) => {
    return craft.fs?.readFile(path)
  }

  const writeFile = (path: string, content: string) => {
    return craft.fs?.writeFile(path, content)
  }

  const readDir = (path: string) => {
    return craft.fs?.readDir(path)
  }

  const mkdir = (path: string) => {
    return craft.fs?.mkdir(path)
  }

  const remove = (path: string) => {
    return craft.fs?.remove(path)
  }

  const exists = (path: string) => {
    return craft.fs?.exists(path)
  }

  return { readFile, writeFile, readDir, mkdir, remove, exists }
}

/**
 * Composable for database operations
 */
export function useDatabase() {
  const craft = useCraft()

  const execute = (sql: string, params?: unknown[]) => {
    return craft.db?.execute(sql, params)
  }

  const query = (sql: string, params?: unknown[]) => {
    return craft.db?.query(sql, params)
  }

  const transaction = async (callback: () => Promise<void>) => {
    await craft.db?.beginTransaction()
    try {
      await callback()
      await craft.db?.commit()
    } catch (err) {
      await craft.db?.rollback()
      throw err
    }
  }

  return { execute, query, transaction }
}

/**
 * Vue plugin for Craft
 */
export default {
  install: (app: any) => {
    app.config.globalProperties.$craft = window.craft
  },
}
