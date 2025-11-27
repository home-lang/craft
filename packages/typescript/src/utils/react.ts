/**
 * React bindings for Craft
 * @module @craft/react
 */

import { useCallback, useEffect, useMemo, useRef, useState, useSyncExternalStore } from 'react';

// ============================================
// Types
// ============================================

export interface WindowState {
  isVisible: boolean;
  isFullscreen: boolean;
  isMaximized: boolean;
  isMinimized: boolean;
  isFocused: boolean;
  title: string;
  width: number;
  height: number;
  x: number;
  y: number;
}

export interface TrayState {
  isVisible: boolean;
  tooltip: string;
  icon: string;
}

export interface NotificationOptions {
  title: string;
  body: string;
  icon?: string;
  sound?: boolean;
  actions?: Array<{ id: string; title: string }>;
}

export interface CraftContext {
  platform: 'ios' | 'android' | 'macos' | 'windows' | 'linux' | 'web';
  isDarkMode: boolean;
  isOnline: boolean;
  appVersion: string;
}

// ============================================
// Craft Store (for external state sync)
// ============================================

type Listener = () => void;

class CraftStore<T> {
  private state: T;
  private listeners = new Set<Listener>();

  constructor(initialState: T) {
    this.state = initialState;
  }

  getState = (): T => this.state;

  setState = (newState: Partial<T> | ((prev: T) => T)): void => {
    if (typeof newState === 'function') {
      this.state = newState(this.state);
    } else {
      this.state = { ...this.state, ...newState };
    }
    this.listeners.forEach((listener) => listener());
  };

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };
}

// Global stores
const windowStore = new CraftStore<WindowState>({
  isVisible: true,
  isFullscreen: false,
  isMaximized: false,
  isMinimized: false,
  isFocused: true,
  title: '',
  width: 800,
  height: 600,
  x: 0,
  y: 0,
});

const trayStore = new CraftStore<TrayState>({
  isVisible: false,
  tooltip: '',
  icon: '',
});

const contextStore = new CraftStore<CraftContext>({
  platform: 'web',
  isDarkMode: false,
  isOnline: true,
  appVersion: '1.0.0',
});

// ============================================
// Core Hooks
// ============================================

/**
 * Hook to access the Craft context (platform, dark mode, etc.)
 */
export function useCraft(): CraftContext & {
  setDarkMode: (dark: boolean) => void;
} {
  const context = useSyncExternalStore(
    contextStore.subscribe,
    contextStore.getState,
    contextStore.getState
  );

  const setDarkMode = useCallback((dark: boolean) => {
    contextStore.setState({ isDarkMode: dark });
    // Would also call native API
  }, []);

  return { ...context, setDarkMode };
}

/**
 * Hook to manage the application window
 */
export function useWindow(): WindowState & {
  setTitle: (title: string) => void;
  setSize: (width: number, height: number) => void;
  setPosition: (x: number, y: number) => void;
  minimize: () => void;
  maximize: () => void;
  restore: () => void;
  close: () => void;
  toggleFullscreen: () => void;
  show: () => void;
  hide: () => void;
  focus: () => void;
} {
  const state = useSyncExternalStore(
    windowStore.subscribe,
    windowStore.getState,
    windowStore.getState
  );

  const setTitle = useCallback((title: string) => {
    windowStore.setState({ title });
    if (typeof document !== 'undefined') {
      document.title = title;
    }
    // Would also call native API: window.craft?.setTitle(title)
  }, []);

  const setSize = useCallback((width: number, height: number) => {
    windowStore.setState({ width, height });
    // Would call native API
  }, []);

  const setPosition = useCallback((x: number, y: number) => {
    windowStore.setState({ x, y });
    // Would call native API
  }, []);

  const minimize = useCallback(() => {
    windowStore.setState({ isMinimized: true, isMaximized: false });
    // Would call native API
  }, []);

  const maximize = useCallback(() => {
    windowStore.setState({ isMaximized: true, isMinimized: false });
    // Would call native API
  }, []);

  const restore = useCallback(() => {
    windowStore.setState({ isMaximized: false, isMinimized: false });
    // Would call native API
  }, []);

  const close = useCallback(() => {
    // Would call native API
  }, []);

  const toggleFullscreen = useCallback(() => {
    windowStore.setState((prev) => ({ ...prev, isFullscreen: !prev.isFullscreen }));
    // Would call native API
  }, []);

  const show = useCallback(() => {
    windowStore.setState({ isVisible: true });
    // Would call native API
  }, []);

  const hide = useCallback(() => {
    windowStore.setState({ isVisible: false });
    // Would call native API
  }, []);

  const focus = useCallback(() => {
    windowStore.setState({ isFocused: true });
    // Would call native API
  }, []);

  return {
    ...state,
    setTitle,
    setSize,
    setPosition,
    minimize,
    maximize,
    restore,
    close,
    toggleFullscreen,
    show,
    hide,
    focus,
  };
}

/**
 * Hook to manage the system tray
 */
export function useTray(): TrayState & {
  setIcon: (icon: string) => void;
  setTooltip: (tooltip: string) => void;
  setMenu: (items: TrayMenuItem[]) => void;
  show: () => void;
  hide: () => void;
} {
  const state = useSyncExternalStore(
    trayStore.subscribe,
    trayStore.getState,
    trayStore.getState
  );

  const menuRef = useRef<TrayMenuItem[]>([]);

  const setIcon = useCallback((icon: string) => {
    trayStore.setState({ icon });
    // Would call native API
  }, []);

  const setTooltip = useCallback((tooltip: string) => {
    trayStore.setState({ tooltip });
    // Would call native API
  }, []);

  const setMenu = useCallback((items: TrayMenuItem[]) => {
    menuRef.current = items;
    // Would call native API
  }, []);

  const show = useCallback(() => {
    trayStore.setState({ isVisible: true });
    // Would call native API
  }, []);

  const hide = useCallback(() => {
    trayStore.setState({ isVisible: false });
    // Would call native API
  }, []);

  return {
    ...state,
    setIcon,
    setTooltip,
    setMenu,
    show,
    hide,
  };
}

export interface TrayMenuItem {
  id: string;
  label: string;
  type?: 'normal' | 'separator' | 'checkbox' | 'submenu';
  checked?: boolean;
  enabled?: boolean;
  submenu?: TrayMenuItem[];
  onClick?: () => void;
}

/**
 * Hook to show native notifications
 */
export function useNotification(): {
  show: (options: NotificationOptions) => Promise<string>;
  close: (id: string) => void;
  requestPermission: () => Promise<boolean>;
  hasPermission: boolean;
} {
  const [hasPermission, setHasPermission] = useState(false);

  useEffect(() => {
    if (typeof Notification !== 'undefined') {
      setHasPermission(Notification.permission === 'granted');
    }
  }, []);

  const requestPermission = useCallback(async () => {
    if (typeof Notification !== 'undefined') {
      const result = await Notification.requestPermission();
      const granted = result === 'granted';
      setHasPermission(granted);
      return granted;
    }
    return false;
  }, []);

  const show = useCallback(async (options: NotificationOptions): Promise<string> => {
    const id = `notification-${Date.now()}`;

    if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
      new Notification(options.title, {
        body: options.body,
        icon: options.icon,
        silent: !options.sound,
      });
    }

    // Would also call native notification API
    return id;
  }, []);

  const close = useCallback((id: string) => {
    // Would call native API to close notification
    console.log('Close notification:', id);
  }, []);

  return { show, close, requestPermission, hasPermission };
}

// ============================================
// Utility Hooks
// ============================================

/**
 * Hook to detect dark mode preference
 */
export function useDarkMode(): [boolean, (dark: boolean) => void] {
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    return false;
  });

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = (e: MediaQueryListEvent) => setIsDark(e.matches);

    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  }, []);

  const setDarkMode = useCallback((dark: boolean) => {
    setIsDark(dark);
    contextStore.setState({ isDarkMode: dark });
  }, []);

  return [isDark, setDarkMode];
}

/**
 * Hook to detect online status
 */
export function useOnline(): boolean {
  const [isOnline, setIsOnline] = useState(() => {
    if (typeof navigator !== 'undefined') {
      return navigator.onLine;
    }
    return true;
  });

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const handleOnline = () => {
      setIsOnline(true);
      contextStore.setState({ isOnline: true });
    };
    const handleOffline = () => {
      setIsOnline(false);
      contextStore.setState({ isOnline: false });
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  return isOnline;
}

/**
 * Hook to handle keyboard shortcuts
 */
export function useShortcut(
  shortcut: string,
  callback: () => void,
  options: { preventDefault?: boolean; enabled?: boolean } = {}
): void {
  const { preventDefault = true, enabled = true } = options;
  const callbackRef = useRef(callback);
  callbackRef.current = callback;

  useEffect(() => {
    if (!enabled || typeof window === 'undefined') return;

    const parts = shortcut.toLowerCase().split('+');
    const key = parts[parts.length - 1];
    const modifiers = {
      ctrl: parts.includes('ctrl') || parts.includes('control'),
      shift: parts.includes('shift'),
      alt: parts.includes('alt') || parts.includes('option'),
      meta: parts.includes('meta') || parts.includes('cmd') || parts.includes('command'),
    };

    const handler = (e: KeyboardEvent) => {
      if (
        e.key.toLowerCase() === key &&
        e.ctrlKey === modifiers.ctrl &&
        e.shiftKey === modifiers.shift &&
        e.altKey === modifiers.alt &&
        e.metaKey === modifiers.meta
      ) {
        if (preventDefault) {
          e.preventDefault();
        }
        callbackRef.current();
      }
    };

    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [shortcut, preventDefault, enabled]);
}

/**
 * Hook to handle file drag and drop
 */
export function useFileDrop(options: {
  onDrop: (files: File[]) => void;
  onDragEnter?: () => void;
  onDragLeave?: () => void;
  accept?: string[];
}): {
  isDragging: boolean;
  dropRef: React.RefObject<HTMLElement>;
} {
  const [isDragging, setIsDragging] = useState(false);
  const dropRef = useRef<HTMLElement>(null);
  const dragCounter = useRef(0);

  useEffect(() => {
    const element = dropRef.current;
    if (!element) return;

    const handleDragEnter = (e: DragEvent) => {
      e.preventDefault();
      dragCounter.current++;
      if (dragCounter.current === 1) {
        setIsDragging(true);
        options.onDragEnter?.();
      }
    };

    const handleDragLeave = (e: DragEvent) => {
      e.preventDefault();
      dragCounter.current--;
      if (dragCounter.current === 0) {
        setIsDragging(false);
        options.onDragLeave?.();
      }
    };

    const handleDragOver = (e: DragEvent) => {
      e.preventDefault();
    };

    const handleDrop = (e: DragEvent) => {
      e.preventDefault();
      dragCounter.current = 0;
      setIsDragging(false);

      const files = Array.from(e.dataTransfer?.files || []);
      const filteredFiles = options.accept
        ? files.filter((f) => options.accept!.some((type) => f.type.match(type)))
        : files;

      if (filteredFiles.length > 0) {
        options.onDrop(filteredFiles);
      }
    };

    element.addEventListener('dragenter', handleDragEnter);
    element.addEventListener('dragleave', handleDragLeave);
    element.addEventListener('dragover', handleDragOver);
    element.addEventListener('drop', handleDrop);

    return () => {
      element.removeEventListener('dragenter', handleDragEnter);
      element.removeEventListener('dragleave', handleDragLeave);
      element.removeEventListener('dragover', handleDragOver);
      element.removeEventListener('drop', handleDrop);
    };
  }, [options.onDrop, options.onDragEnter, options.onDragLeave, options.accept]);

  return { isDragging, dropRef: dropRef as React.RefObject<HTMLElement> };
}

/**
 * Hook for clipboard operations
 */
export function useClipboard(): {
  copy: (text: string) => Promise<void>;
  paste: () => Promise<string>;
  readImage: () => Promise<Blob | null>;
} {
  const copy = useCallback(async (text: string) => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      await navigator.clipboard.writeText(text);
    }
  }, []);

  const paste = useCallback(async () => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      return navigator.clipboard.readText();
    }
    return '';
  }, []);

  const readImage = useCallback(async () => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      try {
        const items = await navigator.clipboard.read();
        for (const item of items) {
          if (item.types.includes('image/png')) {
            return item.getType('image/png');
          }
        }
      } catch {
        return null;
      }
    }
    return null;
  }, []);

  return { copy, paste, readImage };
}

/**
 * Hook for local storage with sync across tabs
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((prev: T) => T)) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === 'undefined') return initialValue;

    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch {
      return initialValue;
    }
  });

  const setValue = useCallback(
    (value: T | ((prev: T) => T)) => {
      setStoredValue((prev) => {
        const newValue = value instanceof Function ? value(prev) : value;
        if (typeof window !== 'undefined') {
          window.localStorage.setItem(key, JSON.stringify(newValue));
        }
        return newValue;
      });
    },
    [key]
  );

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const handleStorage = (e: StorageEvent) => {
      if (e.key === key && e.newValue) {
        setStoredValue(JSON.parse(e.newValue));
      }
    };

    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, [key]);

  return [storedValue, setValue];
}

/**
 * Hook to detect platform
 */
export function usePlatform(): {
  platform: 'ios' | 'android' | 'macos' | 'windows' | 'linux' | 'web';
  isMobile: boolean;
  isDesktop: boolean;
  isWeb: boolean;
} {
  const platform = useMemo(() => {
    if (typeof navigator === 'undefined') return 'web';

    const ua = navigator.userAgent.toLowerCase();

    if (/iphone|ipad|ipod/.test(ua)) return 'ios' as const;
    if (/android/.test(ua)) return 'android' as const;
    if (/macintosh|mac os x/.test(ua)) return 'macos' as const;
    if (/windows/.test(ua)) return 'windows' as const;
    if (/linux/.test(ua)) return 'linux' as const;

    return 'web' as const;
  }, []);

  return {
    platform,
    isMobile: platform === 'ios' || platform === 'android',
    isDesktop: platform === 'macos' || platform === 'windows' || platform === 'linux',
    isWeb: platform === 'web',
  };
}

// ============================================
// Exports
// ============================================

export {
  windowStore,
  trayStore,
  contextStore,
  CraftStore,
};
