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

function createCraftContext(): {
  state: Readonly<CraftContext>;
  setDarkMode: (dark: boolean) => void;
} {
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

  const setDarkMode = (dark: boolean): void => {
    state.isDarkMode = dark;
    // Would call native API
  };

  return {
    state: readonly(state),
    setDarkMode: setDarkMode,
  };
}

function createWindowContext(): {
  state: Readonly<WindowState>;
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

  const setTitle = (title: string): void => {
    state.title = title;
    if (typeof document !== 'undefined') {
      document.title = title;
    }
  };

  const setSize = (width: number, height: number): void => {
    state.width = width;
    state.height = height;
  };

  const setPosition = (x: number, y: number): void => {
    state.x = x;
    state.y = y;
  };

  const minimize = (): void => {
    state.isMinimized = true;
    state.isMaximized = false;
  };

  const maximize = (): void => {
    state.isMaximized = true;
    state.isMinimized = false;
  };

  const restore = (): void => {
    state.isMaximized = false;
    state.isMinimized = false;
  };

  const close = (): void => {
    // Would call native API
  };

  const toggleFullscreen = (): void => {
    state.isFullscreen = !state.isFullscreen;
  };

  const show = (): void => {
    state.isVisible = true;
  };

  const hide = (): void => {
    state.isVisible = false;
  };

  const focus = (): void => {
    state.isFocused = true;
  };

  return {
    state: readonly(state),
    setTitle: setTitle,
    setSize: setSize,
    setPosition: setPosition,
    minimize: minimize,
    maximize: maximize,
    restore: restore,
    close: close,
    toggleFullscreen: toggleFullscreen,
    show: show,
    hide: hide,
    focus: focus,
  };
}

function createTrayContext(): {
  state: Readonly<TrayState>;
  menu: Readonly<Ref<readonly TrayMenuItem[]>>;
  setIcon: (icon: string) => void;
  setTooltip: (tooltip: string) => void;
  setMenu: (items: TrayMenuItem[]) => void;
  show: () => void;
  hide: () => void;
} {
  const state = reactive<TrayState>({
    isVisible: false,
    tooltip: '',
    icon: '',
  });

  const menu = shallowRef<TrayMenuItem[]>([]);

  const setIcon = (icon: string): void => {
    state.icon = icon;
  };

  const setTooltip = (tooltip: string): void => {
    state.tooltip = tooltip;
  };

  const setMenu = (items: TrayMenuItem[]): void => {
    menu.value = items;
  };

  const show = (): void => {
    state.isVisible = true;
  };

  const hide = (): void => {
    state.isVisible = false;
  };

  return {
    state: readonly(state),
    menu: readonly(menu),
    setIcon: setIcon,
    setTooltip: setTooltip,
    setMenu: setMenu,
    show: show,
    hide: hide,
  };
}

// ============================================
// Vue Plugin
// ============================================

export interface CraftPluginOptions {
  appVersion?: string;
}

export const CraftPlugin = {
  install(app: App, options: CraftPluginOptions = {}): void {
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
export function useCraft(): ReturnType<typeof createCraftContext> {
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
export function useWindow(): ReturnType<typeof createWindowContext> {
  const context = inject(WINDOW_KEY);
  if (!context) {
    return createWindowContext();
  }
  return context;
}

/**
 * Composable to manage the system tray
 */
export function useTray(): ReturnType<typeof createTrayContext> {
  const context = inject(TRAY_KEY);
  if (!context) {
    return createTrayContext();
  }
  return context;
}

/**
 * Composable for native notifications
 */
export function useNotification(): {
  hasPermission: Readonly<Ref<boolean>>;
  requestPermission: () => Promise<boolean>;
  show: (options: NotificationOptions) => Promise<string>;
  close: (id: string) => void;
} {
  const hasPermission = ref(false);

  onMounted(() => {
    if (typeof Notification !== 'undefined') {
      hasPermission.value = Notification.permission === 'granted';
    }
  });

  const requestPermission = async (): Promise<boolean> => {
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

  const close = (id: string): void => {
    console.log('Close notification:', id);
  };

  return {
    hasPermission: readonly(hasPermission),
    requestPermission: requestPermission,
    show: show,
    close: close,
  };
}

/**
 * Composable to detect dark mode preference
 */
export function useDarkMode(): {
  isDark: Readonly<Ref<boolean>>;
  setDarkMode: (dark: boolean) => void;
} {
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

  const setDarkMode = (dark: boolean): void => {
    isDark.value = dark;
  };

  return {
    isDark: readonly(isDark),
    setDarkMode: setDarkMode,
  };
}

/**
 * Composable to detect online status
 */
export function useOnline(): Readonly<Ref<boolean>> {
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
): void {
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
}): {
  isDragging: Readonly<Ref<boolean>>;
  dropRef: Ref<HTMLElement | null>;
} {
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
    dropRef: dropRef,
  };
}

/**
 * Composable for clipboard operations
 */
export function useClipboard(): {
  copy: (text: string) => Promise<void>;
  paste: () => Promise<string>;
  readImage: () => Promise<Blob | null>;
} {
  const copy = async (text: string): Promise<void> => {
    if (typeof navigator !== 'undefined' && navigator.clipboard) {
      await navigator.clipboard.writeText(text);
    }
  };

  const paste = async (): Promise<string> => {
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

  return { copy: copy, paste: paste, readImage: readImage };
}

/**
 * Composable for local storage with reactivity
 */
export function useLocalStorage<T>(key: string, initialValue: T): Ref<T> {
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
export function usePlatform(): {
  platform: ComputedRef<'ios' | 'android' | 'macos' | 'windows' | 'linux' | 'web'>;
  isMobile: ComputedRef<boolean>;
  isDesktop: ComputedRef<boolean>;
  isWeb: ComputedRef<boolean>;
} {
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
    platform: platform,
    isMobile: isMobile,
    isDesktop: isDesktop,
    isWeb: isWeb,
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
