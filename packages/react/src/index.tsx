import { useEffect, useState, useCallback, useRef } from 'react'
import type {
  CraftBridgeAPI,
  CraftMobileAPI,
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
 * Main hook to access the Craft bridge
 */
export function useCraft() {
  return window.craft
}

/**
 * Hook for window management (desktop)
 */
export function useWindow() {
  const craft = useCraft()

  const show = useCallback(() => craft.window?.show(), [craft])
  const hide = useCallback(() => craft.window?.hide(), [craft])
  const toggle = useCallback(() => craft.window?.toggle(), [craft])
  const minimize = useCallback(() => craft.window?.minimize(), [craft])
  const close = useCallback(() => craft.window?.close(), [craft])

  return { show, hide, toggle, minimize, close }
}

/**
 * Hook for system tray management (desktop)
 */
export function useTray() {
  const craft = useCraft()

  const setTitle = useCallback((title: string) => craft.tray?.setTitle(title), [craft])
  const setTooltip = useCallback((tooltip: string) => craft.tray?.setTooltip(tooltip), [craft])

  const onClick = useCallback((callback: () => void) => {
    return craft.tray?.onClick(() => callback())
  }, [craft])

  const onClickToggleWindow = useCallback(() => {
    return craft.tray?.onClickToggleWindow()
  }, [craft])

  return { setTitle, setTooltip, onClick, onClickToggleWindow }
}

/**
 * Hook for notifications
 */
export function useNotification() {
  const craft = useCraft()

  const notify = useCallback((options: NotificationOptions) => {
    return craft.app.notify(options)
  }, [craft])

  return { notify }
}

/**
 * Hook for mobile device information
 */
export function useDeviceInfo() {
  const [deviceInfo, setDeviceInfo] = useState<DeviceInfo | null>(null)
  const craft = useCraft()

  useEffect(() => {
    if (craft.mobile) {
      craft.mobile.getDeviceInfo().then(setDeviceInfo)
    }
  }, [craft])

  return deviceInfo
}

/**
 * Hook for mobile permissions
 */
export function usePermission(permission: Permission) {
  const [status, setStatus] = useState<PermissionStatus>('notDetermined')
  const craft = useCraft()

  const request = useCallback(async () => {
    if (!craft.mobile) return
    const newStatus = await craft.mobile.requestPermission(permission)
    setStatus(newStatus)
    return newStatus
  }, [craft, permission])

  const check = useCallback(async () => {
    if (!craft.mobile) return
    const currentStatus = await craft.mobile.checkPermission(permission)
    setStatus(currentStatus)
    return currentStatus
  }, [craft, permission])

  useEffect(() => {
    check()
  }, [check])

  return { status, request, check }
}

/**
 * Hook for mobile haptics
 */
export function useHaptic() {
  const craft = useCraft()

  const trigger = useCallback((type: HapticType) => {
    return craft.mobile?.haptic(type)
  }, [craft])

  return { trigger }
}

/**
 * Hook for mobile vibration
 */
export function useVibrate() {
  const craft = useCraft()

  const vibrate = useCallback((duration: number) => {
    return craft.mobile?.vibrate(duration)
  }, [craft])

  return { vibrate }
}

/**
 * Hook for mobile toast messages
 */
export function useToast() {
  const craft = useCraft()

  const show = useCallback((message: string, duration?: number) => {
    return craft.mobile?.toast(message, duration)
  }, [craft])

  return { show }
}

/**
 * Hook for camera access
 */
export function useCamera() {
  const craft = useCraft()

  const open = useCallback((options?: { type?: 'front' | 'back', mediaType?: 'photo' | 'video' }) => {
    return craft.mobile?.openCamera(options)
  }, [craft])

  return { open }
}

/**
 * Hook for photo picker
 */
export function usePhotoPicker() {
  const craft = useCraft()

  const pick = useCallback((options?: { maxSelections?: number, mediaType?: 'photo' | 'video' | 'all' }) => {
    return craft.mobile?.pickPhoto(options)
  }, [craft])

  return { pick }
}

/**
 * Hook for sharing
 */
export function useShare() {
  const craft = useCraft()

  const share = useCallback((options: { text?: string, url?: string, title?: string }) => {
    return craft.mobile?.share(options)
  }, [craft])

  return { share }
}

/**
 * Hook for biometric authentication
 */
export function useBiometric() {
  const [available, setAvailable] = useState(false)
  const craft = useCraft()

  useEffect(() => {
    if (craft.mobile) {
      craft.mobile.isBiometricAvailable().then(setAvailable)
    }
  }, [craft])

  const authenticate = useCallback((reason: string) => {
    return craft.mobile?.authenticateBiometric(reason)
  }, [craft])

  return { available, authenticate }
}

/**
 * Hook for secure storage
 */
export function useSecureStorage() {
  const craft = useCraft()

  const store = useCallback((key: string, value: string) => {
    return craft.mobile?.secureStore(key, value)
  }, [craft])

  const retrieve = useCallback((key: string) => {
    return craft.mobile?.secureRetrieve(key)
  }, [craft])

  const remove = useCallback((key: string) => {
    return craft.mobile?.secureDelete(key)
  }, [craft])

  return { store, retrieve, remove }
}

/**
 * Hook for file system operations
 */
export function useFileSystem() {
  const craft = useCraft()

  const readFile = useCallback((path: string) => {
    return craft.fs?.readFile(path)
  }, [craft])

  const writeFile = useCallback((path: string, content: string) => {
    return craft.fs?.writeFile(path, content)
  }, [craft])

  const readDir = useCallback((path: string) => {
    return craft.fs?.readDir(path)
  }, [craft])

  const mkdir = useCallback((path: string) => {
    return craft.fs?.mkdir(path)
  }, [craft])

  const remove = useCallback((path: string) => {
    return craft.fs?.remove(path)
  }, [craft])

  const exists = useCallback((path: string) => {
    return craft.fs?.exists(path)
  }, [craft])

  return { readFile, writeFile, readDir, mkdir, remove, exists }
}

/**
 * Hook for database operations
 */
export function useDatabase() {
  const craft = useCraft()

  const execute = useCallback((sql: string, params?: unknown[]) => {
    return craft.db?.execute(sql, params)
  }, [craft])

  const query = useCallback((sql: string, params?: unknown[]) => {
    return craft.db?.query(sql, params)
  }, [craft])

  const transaction = useCallback((callback: () => Promise<void>) => {
    return craft.db?.beginTransaction()
      .then(() => callback())
      .then(() => craft.db?.commit())
      .catch((err) => {
        craft.db?.rollback()
        throw err
      })
  }, [craft])

  return { execute, query, transaction }
}

/**
 * Component for Craft provider
 */
export function CraftProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false)

  useEffect(() => {
    // Wait for craft bridge to be ready
    if (window.craft) {
      setReady(true)
    } else {
      const checkInterval = setInterval(() => {
        if (window.craft) {
          setReady(true)
          clearInterval(checkInterval)
        }
      }, 100)

      return () => clearInterval(checkInterval)
    }
  }, [])

  if (!ready) {
    return null // or a loading component
  }

  return <>{children}</>
}
