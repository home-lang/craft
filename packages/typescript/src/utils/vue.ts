/**
 * Vue bindings for Craft
 * @module @craft/vue
 */

import {
  computed,
  inject,
  onMounted,
  onUnmounted,
  provide,
  reactive,
  readonly,
  ref,
  shallowRef,
  watch,
  type App,
  type ComputedRef,
  type InjectionKey,
  type Ref,
} from 'vue';

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

export interface TrayMenuItem {
  id: string;
  label: string;
  type?: 'normal' | 'separator' | 'checkbox' | 'submenu';
  checked?: boolean;
  enabled?: boolean;
  submenu?: TrayMenuItem[];
  onClick?: () => void;
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
// Injection Keys
// ============================================

export const CRAFT_KEY: InjectionKey<ReturnType<typeof createCraftContext>> = Symbol('craft');
export const WINDOW_KEY: InjectionKey<ReturnType<typeof createWindowContext>> = Symbol('window');
export const TRAY_KEY: InjectionKey<ReturnType<typeof createTrayContext>> = Symbol('tray');

// ============================================
// Context Creators
// ============================================

function createCraftContext() {
  const state = reactive<CraftContext>({
    platform: 'web',
    isDarkMode: false,
    isOnline: true,
    appVersion: '1.0.0',
  });

  // Detect platform
  if (typeof navigator !== 'undefined') {
    const ua = navigator.userAgent.toLowerCase();
    if (/iphone|ipad|ipod/.test(ua)) state.platform = 'ios';
    else if (/android/.test(ua)) state.platform = 'android';
    else if (/macintosh|mac os x/.test(ua)) state.platform = 'macos';
    else if (/windows/.test(ua)) state.platform = 'windows';
    else if (/linux/.test(ua)) state.platform = 'linux';
  }

  // Detect dark mode
  if (typeof window !== 'undefined') {
    state.isDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  // Detect online status
  if (typeof navigator !== 'undefined') {
    state.isOnline = navigator.onLine;
  }

  const setDarkMode = (dark: boolean) => {
    state.isDarkMode = dark;
    // Would call native API
  };

  return {
    state: readonly(state),
    setDarkMode,
  };
}

function createWindowContext() {
  const state = reactive<WindowState>({
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

  const setTitle = (title: string) => {
    state.title = title;
    if (typeof document !== 'undefined') {
      document.title = title;
    }
  };

  const setSize = (width: number, height: number) => {
    state.width = width;
    state.height = height;
  };

  const setPosition = (x: number, y: number) => {
    state.x = x;
    state.y = y;
  };

  const minimize = () => {
    state.isMinimized = true;
    state.isMaximized = false;
  };

  const maximize = () => {
    state.isMaximized = true;
    state.isMinimized = false;
  };

  const restore = () => {
    state.isMaximized = false;
    state.isMinimized = false;
  };

  const close = () => {
    // Would call native API
  };

  const toggleFullscreen = () => {
    state.isFullscreen = !state.isFullscreen;
  };

  const show = () => {
    state.isVisible = true;
  };

  const hide = () => {
    state.isVisible = false;
  };

  const focus = () => {
    state.isFocused = true;
  };

  return {
    state: readonly(state),
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

function createTrayContext() {
  const state = reactive<TrayState>({
    isVisible: false,
    tooltip: '',
    icon: '',
  });

  const menu = shallowRef<TrayMenuItem[]>([]);

  const setIcon = (icon: string) => {
    state.icon = icon;
  };

  const setTooltip = (tooltip: string) => {
    state.tooltip = tooltip;
  };

  const setMenu = (items: TrayMenuItem[]) => {
    menu.value = items;
  };

  const show = () => {
    state.isVisible = true;
  };

  const hide = () => {
    state.isVisible = false;
  };

  return {
    state: readonly(state),
    menu: readonly(menu),
    setIcon,
    setTooltip,
    setMenu,
    show,
    hide,
  };
}

// ============================================
// Vue Plugin
// ============================================

export interface CraftPluginOptions {
  appVersion?: string;
}

export const CraftPlugin = {
  install(app: App, options: CraftPluginOptions = {}) {
    const craftContext = createCraftContext();
    const windowContext = createWindowContext();
    const trayContext = createTrayContext();

    if (options.appVersion) {
      (craftContext.state as CraftContext).appVersion = options.appVersion;
    }

    app.provide(CRAFT_KEY, craftContext);
    app.provide(WINDOW_KEY, windowContext);
    app.provide(TRAY_KEY, trayContext);

    // Global properties
    app.config.globalProperties.$craft = craftContext;
    app.config.globalProperties.$window = windowContext;
    app.config.globalProperties.$tray = trayContext;
  },
};

// ============================================
// Composables
// ============================================

/**
 * Composable to access the Craft context
 */
export function useCraft() {
  const context = inject(CRAFT_KEY);
  if (!context) {
    // Return a fallback for when not using the plugin
    return createCraftContext();
  }
  return context;
}

/**
 * Composable to manage the application window
 */
export function useWindow() {
  const context = inject(WINDOW_KEY);
  if (!context) {
    return createWindowContext();
  }
  return context;
}

/**
 * Composable to manage the system tray
 */
export function useTray() {
  const context = inject(TRAY_KEY);
  if (!context) {
    return createTrayContext();
  }
  return context;
}

/**
 * Composable for native notifications
 */
export function useNotification() {
  const hasPermission = ref(false);

  onMounted(() => {
    if (typeof Notification !== 'undefined') {
      hasPermission.value = Notification.permission === 'granted';
    }
  });

  const requestPermission = async () => {
    if (typeof Notification !== 'undefined') {
      const result = await Notification.requestPermission();
      hasPermission.value = result === 'granted';
      return hasPermission.value;
    }
    return false;
  };

  const show = async (options: NotificationOptions): Promise<string> => {
    const id = `notification-${Date.now()}`;

    if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
      new Notification(options.title, {
        body: options.body,
        icon: options.icon,
        silent: !options.sound,
      });
    }

    return id;
  };

  const close = (id: string) => {
    console.log('Close notification:', id);
  };

  return {
    hasPermission: readonly(hasPermission),
    requestPermission,
    show,
    close,
  };
}

/**
 * Composable to detect dark mode preference
 */
export function useDarkMode() {
  const isDark = ref(false);

  onMounted(() => {
    if (typeof window !== 'undefined') {
      isDark.value = window.matchMedia('(prefers-color-scheme: dark)').matches;

      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handler = (e: MediaQueryListEvent) => {
        isDark.value = e.matches;
      };
      mediaQuery.addEventListener('change', handler);

      onUnmounted(() => {
        mediaQuery.removeEventListener('change', handler);
      });
    }
  });

  const setDarkMode = (dark: boolean) => {
    isDark.value = dark;
  };

  return {
    isDark: readonly(isDark),
    setDarkMode,
  };
}

/**
 * Composable to detect online status
 */
export function useOnline() {
  const isOnline = ref(true);

  onMounted(() => {
    if (typeof navigator !== 'undefined') {
      isOnline.value = navigator.onLine;
    }

    if (typeof window !== 'undefined') {
      const handleOnline = () => {
        isOnline.value = true;
      };
      const handleOffline = () => {
        isOnline.value = false;
      };

      window.addEventListener('online', handleOnline);
      window.addEventListener('offline', handleOffline);

      onUnmounted(() => {
        window.removeEventListener('online', handleOnline);
        window.removeEventListener('offline', handleOffline);
      });
    }
  });

  return readonly(isOnline);
}

/**
 * Composable for keyboard shortcuts
 */
export function useShortcut(
  shortcut: string | Ref<string>,
  callback: () => void,
  options: { preventDefault?: boolean; enabled?: Ref<boolean> | boolean } = {}
) {
  const { preventDefault = true, enabled = true } = options;

  onMounted(() => {
    if (typeof window === 'undefined') return;

    const handler = (e: KeyboardEvent) => {
      const isEnabled = typeof enabled === 'boolean' ? enabled : enabled.value;
      if (!isEnabled) return;

      const shortcutValue = typeof shortcut === 'string' ? shortcut : shortcut.value;
      const parts = shortcutValue.toLowerCase().split('+');
      const key = parts[parts.length - 1];
      const modifiers = {
        ctrl: parts.includes('ctrl') || parts.includes('control'),
        shift: parts.includes('shift'),
        alt: parts.includes('alt') || parts.includes('option'),
        meta: parts.includes('meta') || parts.includes('cmd') || parts.includes('command'),
      };

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
        callback();
      }
    };

    window.addEventListener('keydown', handler);

    onUnmounted(() => {
      window.removeEventListener('keydown', handler);
    });
  });
}

/**
 * Composable for file drag and drop
 */
export function useFileDrop(options: {
  onDrop: (files: File[]) => void;
  onDragEnter?: () => void;
  onDragLeave?: () => void;
  accept?: string[];
}) {
  const isDragging = ref(false);
  const dropRef = ref<HTMLElement | null>(null);
  let dragCounter = 0;

  onMounted(() => {
    const element = dropRef.value;
    if (!element) return;

    const handleDragEnter = (e: DragEvent) => {
      e.preventDefault();
      dragCounter++;
      if (dragCounter === 1) {
        isDragging.value = true;
        options.onDragEnter?.();
      }
    };

    const handleDragLeave = (e: DragEvent) => {
      e.preventDefault();
      dragCounter--;
      if (dragCounter === 0) {
        isDragging.value = false;
        options.onDragLeave?.();
      }
    };

    const handleDragOver = (e: DragEvent) => {
      e.preventDefault();
    };

    const handleDrop = (e: DragEvent) => {
      e.preventDefault();
      dragCounter = 0;
      isDragging.value = false;

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

    onUnmounted(() => {
      element.removeEventListener('dragenter', handleDragEnter);
      element.removeEventListener('dragleave', handleDragLeave);
      element.removeEventListener('dragover', handleDragOver);
      element.removeEventListener('drop', handleDrop);
    });
  });

  return {
    isDragging: readonly(isDragging),
    dropRef,
  };
}

/**
 * Composable for clipboard operations
 */
export function useClipboard() {
  const copy = async (text: string) => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      await navigator.clipboard.writeText(text);
    }
  };

  const paste = async () => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      return navigator.clipboard.readText();
    }
    return '';
  };

  const readImage = async (): Promise<Blob | null> => {
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
  };

  return { copy, paste, readImage };
}

/**
 * Composable for local storage with reactivity
 */
export function useLocalStorage<T>(key: string, initialValue: T) {
  const storedValue = ref<T>(initialValue) as Ref<T>;

  onMounted(() => {
    if (typeof window === 'undefined') return;

    try {
      const item = window.localStorage.getItem(key);
      if (item) {
        storedValue.value = JSON.parse(item);
      }
    } catch {
      // Ignore errors
    }

    // Listen for changes from other tabs
    const handleStorage = (e: StorageEvent) => {
      if (e.key === key && e.newValue) {
        storedValue.value = JSON.parse(e.newValue);
      }
    };

    window.addEventListener('storage', handleStorage);

    onUnmounted(() => {
      window.removeEventListener('storage', handleStorage);
    });
  });

  watch(
    storedValue,
    (newValue: T) => {
      if (typeof window !== 'undefined') {
        window.localStorage.setItem(key, JSON.stringify(newValue));
      }
    },
    { deep: true }
  );

  return storedValue;
}

/**
 * Composable to detect platform
 */
export function usePlatform() {
  const platform = computed(() => {
    if (typeof navigator === 'undefined') return 'web' as const;

    const ua = navigator.userAgent.toLowerCase();

    if (/iphone|ipad|ipod/.test(ua)) return 'ios' as const;
    if (/android/.test(ua)) return 'android' as const;
    if (/macintosh|mac os x/.test(ua)) return 'macos' as const;
    if (/windows/.test(ua)) return 'windows' as const;
    if (/linux/.test(ua)) return 'linux' as const;

    return 'web' as const;
  });

  const isMobile = computed(() => platform.value === 'ios' || platform.value === 'android');
  const isDesktop = computed(
    () => platform.value === 'macos' || platform.value === 'windows' || platform.value === 'linux'
  );
  const isWeb = computed(() => platform.value === 'web');

  return {
    platform,
    isMobile,
    isDesktop,
    isWeb,
  };
}

// ============================================
// Exports
// ============================================

export {
  createCraftContext,
  createWindowContext,
  createTrayContext,
};
