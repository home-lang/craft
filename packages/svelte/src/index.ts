import { writable, derived, get } from 'svelte/store'
import type { Readable, Writable } from 'svelte/store'
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
 * Store for Craft bridge
 */
export const craft = writable<CraftBridgeAPI | null>(null)

// Initialize craft store when available
if (typeof window !== 'undefined') {
  if (window.craft) {
    craft.set(window.craft)
  } else {
    const interval = setInterval(() => {
      if (window.craft) {
        craft.set(window.craft)
        clearInterval(interval)
      }
    }, 100)
  }
}

/**
 * Window management store (desktop)
 */
export function createWindowStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    show: () => $craft?.window?.show(),
    hide: () => $craft?.window?.hide(),
    toggle: () => $craft?.window?.toggle(),
    minimize: () => $craft?.window?.minimize(),
    close: () => $craft?.window?.close(),
  }))

  return { subscribe }
}

/**
 * Tray management store (desktop)
 */
export function createTrayStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    setTitle: (title: string) => $craft?.tray?.setTitle(title),
    setTooltip: (tooltip: string) => $craft?.tray?.setTooltip(tooltip),
    onClick: (callback: () => void) => $craft?.tray?.onClick(() => callback()),
    onClickToggleWindow: () => $craft?.tray?.onClickToggleWindow(),
  }))

  return { subscribe }
}

/**
 * Notification store
 */
export function createNotificationStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    notify: (options: NotificationOptions) => $craft?.app.notify(options),
  }))

  return { subscribe }
}

/**
 * Device information store (mobile)
 */
export function createDeviceInfoStore() {
  const store = writable<DeviceInfo | null>(null)

  craft.subscribe(($craft) => {
    if ($craft?.mobile) {
      $craft.mobile.getDeviceInfo().then((info) => store.set(info))
    }
  })

  return { subscribe: store.subscribe }
}

/**
 * Permission store (mobile)
 */
export function createPermissionStore(permission: Permission) {
  const status = writable<PermissionStatus>('notDetermined')
  let craftInstance: CraftBridgeAPI | null = null

  craft.subscribe(($craft) => {
    craftInstance = $craft
    if ($craft?.mobile) {
      $craft.mobile.checkPermission(permission).then((s) => status.set(s))
    }
  })

  const request = async () => {
    if (!craftInstance?.mobile) return
    const newStatus = await craftInstance.mobile.requestPermission(permission)
    status.set(newStatus)
    return newStatus
  }

  const check = async () => {
    if (!craftInstance?.mobile) return
    const currentStatus = await craftInstance.mobile.checkPermission(permission)
    status.set(currentStatus)
    return currentStatus
  }

  return {
    subscribe: status.subscribe,
    request,
    check,
  }
}

/**
 * Haptic feedback store (mobile)
 */
export function createHapticStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    trigger: (type: HapticType) => $craft?.mobile?.haptic(type),
  }))

  return { subscribe }
}

/**
 * Vibration store (mobile)
 */
export function createVibrateStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    vibrate: (duration: number) => $craft?.mobile?.vibrate(duration),
  }))

  return { subscribe }
}

/**
 * Toast store (mobile)
 */
export function createToastStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    show: (message: string, duration?: number) => $craft?.mobile?.toast(message, duration),
  }))

  return { subscribe }
}

/**
 * Camera store (mobile)
 */
export function createCameraStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    open: (options?: { type?: 'front' | 'back', mediaType?: 'photo' | 'video' }) =>
      $craft?.mobile?.openCamera(options),
  }))

  return { subscribe }
}

/**
 * Photo picker store (mobile)
 */
export function createPhotoPickerStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    pick: (options?: { maxSelections?: number, mediaType?: 'photo' | 'video' | 'all' }) =>
      $craft?.mobile?.pickPhoto(options),
  }))

  return { subscribe }
}

/**
 * Share store (mobile)
 */
export function createShareStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    share: (options: { text?: string, url?: string, title?: string }) =>
      $craft?.mobile?.share(options),
  }))

  return { subscribe }
}

/**
 * Biometric authentication store (mobile)
 */
export function createBiometricStore() {
  const available = writable(false)
  let craftInstance: CraftBridgeAPI | null = null

  craft.subscribe(($craft) => {
    craftInstance = $craft
    if ($craft?.mobile) {
      $craft.mobile.isBiometricAvailable().then((a) => available.set(a))
    }
  })

  const authenticate = (reason: string) => {
    return craftInstance?.mobile?.authenticateBiometric(reason)
  }

  return {
    subscribe: available.subscribe,
    authenticate,
  }
}

/**
 * Secure storage store (mobile)
 */
export function createSecureStorageStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    store: (key: string, value: string) => $craft?.mobile?.secureStore(key, value),
    retrieve: (key: string) => $craft?.mobile?.secureRetrieve(key),
    remove: (key: string) => $craft?.mobile?.secureDelete(key),
  }))

  return { subscribe }
}

/**
 * File system store
 */
export function createFileSystemStore() {
  const { subscribe } = derived(craft, ($craft) => ({
    readFile: (path: string) => $craft?.fs?.readFile(path),
    writeFile: (path: string, content: string) => $craft?.fs?.writeFile(path, content),
    readDir: (path: string) => $craft?.fs?.readDir(path),
    mkdir: (path: string) => $craft?.fs?.mkdir(path),
    remove: (path: string) => $craft?.fs?.remove(path),
    exists: (path: string) => $craft?.fs?.exists(path),
  }))

  return { subscribe }
}

/**
 * Database store
 */
export function createDatabaseStore() {
  let craftInstance: CraftBridgeAPI | null = null

  craft.subscribe(($craft) => {
    craftInstance = $craft
  })

  const execute = (sql: string, params?: unknown[]) => {
    return craftInstance?.db?.execute(sql, params)
  }

  const query = (sql: string, params?: unknown[]) => {
    return craftInstance?.db?.query(sql, params)
  }

  const transaction = async (callback: () => Promise<void>) => {
    await craftInstance?.db?.beginTransaction()
    try {
      await callback()
      await craftInstance?.db?.commit()
    } catch (err) {
      await craftInstance?.db?.rollback()
      throw err
    }
  }

  return { execute, query, transaction }
}

// Action for use in Svelte components
export function craft_action(node: HTMLElement) {
  // Custom action that can be used in Svelte components
  // Example: <div use:craft_action>

  return {
    destroy() {
      // Cleanup
    },
  }
}
