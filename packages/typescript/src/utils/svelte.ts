/**
 * Svelte bindings for Craft
 * @module @craft/svelte
 */

import { writable, derived, readable, get, type Writable, type Readable } from 'svelte/store';
import { onMount, onDestroy } from 'svelte';

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
// Core Stores
// ============================================

function createCraftStore() {
  const { subscribe, update, set } = writable<CraftContext>({
    platform: 'web',
    isDarkMode: false,
    isOnline: true,
    appVersion: '1.0.0',
  });

  // Initialize on browser
  if (typeof window !== 'undefined') {
    // Detect platform
    const ua = navigator.userAgent.toLowerCase();
    let platform: CraftContext['platform'] = 'web';
    if (/iphone|ipad|ipod/.test(ua)) platform = 'ios';
    else if (/android/.test(ua)) platform = 'android';
    else if (/macintosh|mac os x/.test(ua)) platform = 'macos';
    else if (/windows/.test(ua)) platform = 'windows';
    else if (/linux/.test(ua)) platform = 'linux';

    // Detect dark mode
    const isDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;

    // Detect online
    const isOnline = navigator.onLine;

    update((state) => ({ ...state, platform, isDarkMode, isOnline }));

    // Listen for dark mode changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      update((state) => ({ ...state, isDarkMode: e.matches }));
    });

    // Listen for online/offline
    window.addEventListener('online', () => {
      update((state) => ({ ...state, isOnline: true }));
    });
    window.addEventListener('offline', () => {
      update((state) => ({ ...state, isOnline: false }));
    });
  }

  return {
    subscribe,
    setDarkMode: (dark: boolean) => update((state) => ({ ...state, isDarkMode: dark })),
    setAppVersion: (version: string) => update((state) => ({ ...state, appVersion: version })),
  };
}

function createWindowStore() {
  const { subscribe, update, set } = writable<WindowState>({
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

  return {
    subscribe,
    setTitle: (title: string) => {
      update((state) => ({ ...state, title }));
      if (typeof document !== 'undefined') {
        document.title = title;
      }
    },
    setSize: (width: number, height: number) => {
      update((state) => ({ ...state, width, height }));
    },
    setPosition: (x: number, y: number) => {
      update((state) => ({ ...state, x, y }));
    },
    minimize: () => {
      update((state) => ({ ...state, isMinimized: true, isMaximized: false }));
    },
    maximize: () => {
      update((state) => ({ ...state, isMaximized: true, isMinimized: false }));
    },
    restore: () => {
      update((state) => ({ ...state, isMaximized: false, isMinimized: false }));
    },
    close: () => {
      // Would call native API
    },
    toggleFullscreen: () => {
      update((state) => ({ ...state, isFullscreen: !state.isFullscreen }));
    },
    show: () => {
      update((state) => ({ ...state, isVisible: true }));
    },
    hide: () => {
      update((state) => ({ ...state, isVisible: false }));
    },
    focus: () => {
      update((state) => ({ ...state, isFocused: true }));
    },
  };
}

function createTrayStore() {
  const { subscribe, update, set } = writable<TrayState>({
    isVisible: false,
    tooltip: '',
    icon: '',
  });

  const menu = writable<TrayMenuItem[]>([]);

  return {
    subscribe,
    menu,
    setIcon: (icon: string) => {
      update((state) => ({ ...state, icon }));
    },
    setTooltip: (tooltip: string) => {
      update((state) => ({ ...state, tooltip }));
    },
    setMenu: (items: TrayMenuItem[]) => {
      menu.set(items);
    },
    show: () => {
      update((state) => ({ ...state, isVisible: true }));
    },
    hide: () => {
      update((state) => ({ ...state, isVisible: false }));
    },
  };
}

// Create singleton stores
export const craftStore = createCraftStore();
export const windowStore = createWindowStore();
export const trayStore = createTrayStore();

// ============================================
// Derived Stores
// ============================================

export const platform = derived(craftStore, ($craft) => $craft.platform);
export const isDarkMode = derived(craftStore, ($craft) => $craft.isDarkMode);
export const isOnline = derived(craftStore, ($craft) => $craft.isOnline);

export const isMobile = derived(
  craftStore,
  ($craft) => $craft.platform === 'ios' || $craft.platform === 'android'
);

export const isDesktop = derived(
  craftStore,
  ($craft) =>
    $craft.platform === 'macos' || $craft.platform === 'windows' || $craft.platform === 'linux'
);

export const isWeb = derived(craftStore, ($craft) => $craft.platform === 'web');

// ============================================
// Notification Store
// ============================================

function createNotificationStore() {
  const hasPermission = writable(false);

  // Check permission on browser
  if (typeof Notification !== 'undefined') {
    hasPermission.set(Notification.permission === 'granted');
  }

  const requestPermission = async () => {
    if (typeof Notification !== 'undefined') {
      const result = await Notification.requestPermission();
      const granted = result === 'granted';
      hasPermission.set(granted);
      return granted;
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
    hasPermission: { subscribe: hasPermission.subscribe },
    requestPermission,
    show,
    close,
  };
}

export const notificationStore = createNotificationStore();

// ============================================
// Utility Stores
// ============================================

/**
 * Create a persistent store backed by localStorage
 */
export function persistentStore<T>(key: string, initialValue: T): Writable<T> {
  let storedValue = initialValue;

  if (typeof localStorage !== 'undefined') {
    const stored = localStorage.getItem(key);
    if (stored) {
      try {
        storedValue = JSON.parse(stored);
      } catch {
        // Ignore parse errors
      }
    }
  }

  const { subscribe, set, update } = writable<T>(storedValue);

  // Sync to localStorage
  subscribe((value) => {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(key, JSON.stringify(value));
    }
  });

  // Listen for changes from other tabs
  if (typeof window !== 'undefined') {
    window.addEventListener('storage', (e) => {
      if (e.key === key && e.newValue) {
        set(JSON.parse(e.newValue));
      }
    });
  }

  return { subscribe, set, update };
}

/**
 * Create a store for clipboard operations
 */
export function createClipboardStore() {
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

export const clipboardStore = createClipboardStore();

// ============================================
// Actions (Svelte use: directives)
// ============================================

/**
 * Action for keyboard shortcuts
 * Usage: <div use:shortcut={{ key: 'ctrl+s', callback: save }}>
 */
export function shortcut(
  node: HTMLElement,
  params: {
    key: string;
    callback: () => void;
    preventDefault?: boolean;
  }
) {
  const { key, callback, preventDefault = true } = params;

  const handler = (e: KeyboardEvent) => {
    const parts = key.toLowerCase().split('+');
    const keyPart = parts[parts.length - 1];
    const modifiers = {
      ctrl: parts.includes('ctrl') || parts.includes('control'),
      shift: parts.includes('shift'),
      alt: parts.includes('alt') || parts.includes('option'),
      meta: parts.includes('meta') || parts.includes('cmd') || parts.includes('command'),
    };

    if (
      e.key.toLowerCase() === keyPart &&
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

  return {
    destroy() {
      window.removeEventListener('keydown', handler);
    },
    update(newParams: typeof params) {
      // Remove old listener and add new one
      window.removeEventListener('keydown', handler);
      Object.assign(params, newParams);
      window.addEventListener('keydown', handler);
    },
  };
}

/**
 * Action for file drop zones
 * Usage: <div use:fileDrop={{ onDrop: handleFiles }}>
 */
export function fileDrop(
  node: HTMLElement,
  params: {
    onDrop: (files: File[]) => void;
    onDragEnter?: () => void;
    onDragLeave?: () => void;
    accept?: string[];
  }
) {
  let dragCounter = 0;

  const handleDragEnter = (e: DragEvent) => {
    e.preventDefault();
    dragCounter++;
    if (dragCounter === 1) {
      node.classList.add('drag-over');
      params.onDragEnter?.();
    }
  };

  const handleDragLeave = (e: DragEvent) => {
    e.preventDefault();
    dragCounter--;
    if (dragCounter === 0) {
      node.classList.remove('drag-over');
      params.onDragLeave?.();
    }
  };

  const handleDragOver = (e: DragEvent) => {
    e.preventDefault();
  };

  const handleDrop = (e: DragEvent) => {
    e.preventDefault();
    dragCounter = 0;
    node.classList.remove('drag-over');

    const files = Array.from(e.dataTransfer?.files || []);
    const filteredFiles = params.accept
      ? files.filter((f) => params.accept!.some((type) => f.type.match(type)))
      : files;

    if (filteredFiles.length > 0) {
      params.onDrop(filteredFiles);
    }
  };

  node.addEventListener('dragenter', handleDragEnter);
  node.addEventListener('dragleave', handleDragLeave);
  node.addEventListener('dragover', handleDragOver);
  node.addEventListener('drop', handleDrop);

  return {
    destroy() {
      node.removeEventListener('dragenter', handleDragEnter);
      node.removeEventListener('dragleave', handleDragLeave);
      node.removeEventListener('dragover', handleDragOver);
      node.removeEventListener('drop', handleDrop);
    },
    update(newParams: typeof params) {
      Object.assign(params, newParams);
    },
  };
}

/**
 * Action for click outside detection
 * Usage: <div use:clickOutside={() => close()}>
 */
export function clickOutside(node: HTMLElement, callback: () => void) {
  const handleClick = (e: MouseEvent) => {
    if (!node.contains(e.target as Node)) {
      callback();
    }
  };

  document.addEventListener('click', handleClick, true);

  return {
    destroy() {
      document.removeEventListener('click', handleClick, true);
    },
    update(newCallback: () => void) {
      callback = newCallback;
    },
  };
}

/**
 * Action for intersection observer
 * Usage: <div use:inView={{ callback: handleVisible }}>
 */
export function inView(
  node: HTMLElement,
  params: {
    callback: (isVisible: boolean) => void;
    threshold?: number;
    rootMargin?: string;
  }
) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        params.callback(entry.isIntersecting);
      });
    },
    {
      threshold: params.threshold ?? 0,
      rootMargin: params.rootMargin ?? '0px',
    }
  );

  observer.observe(node);

  return {
    destroy() {
      observer.disconnect();
    },
    update(newParams: typeof params) {
      Object.assign(params, newParams);
    },
  };
}

/**
 * Action for auto-focus
 * Usage: <input use:autoFocus>
 */
export function autoFocus(node: HTMLElement) {
  node.focus();

  return {
    destroy() {},
  };
}

/**
 * Action for tooltip
 * Usage: <button use:tooltip={'Click me'}>
 */
export function tooltip(node: HTMLElement, text: string) {
  let tooltipEl: HTMLDivElement | null = null;

  const show = () => {
    tooltipEl = document.createElement('div');
    tooltipEl.className = 'craft-tooltip';
    tooltipEl.textContent = text;
    tooltipEl.style.cssText = `
      position: fixed;
      background: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      z-index: 9999;
    `;
    document.body.appendChild(tooltipEl);

    const rect = node.getBoundingClientRect();
    tooltipEl.style.left = `${rect.left + rect.width / 2 - tooltipEl.offsetWidth / 2}px`;
    tooltipEl.style.top = `${rect.top - tooltipEl.offsetHeight - 8}px`;
  };

  const hide = () => {
    if (tooltipEl) {
      tooltipEl.remove();
      tooltipEl = null;
    }
  };

  node.addEventListener('mouseenter', show);
  node.addEventListener('mouseleave', hide);

  return {
    destroy() {
      node.removeEventListener('mouseenter', show);
      node.removeEventListener('mouseleave', hide);
      hide();
    },
    update(newText: string) {
      text = newText;
      if (tooltipEl) {
        tooltipEl.textContent = text;
      }
    },
  };
}

/**
 * Action for long press
 * Usage: <button use:longPress={{ callback: handleLongPress, duration: 500 }}>
 */
export function longPress(
  node: HTMLElement,
  params: {
    callback: () => void;
    duration?: number;
  }
) {
  const { callback, duration = 500 } = params;
  let timer: ReturnType<typeof setTimeout>;

  const start = () => {
    timer = setTimeout(callback, duration);
  };

  const cancel = () => {
    clearTimeout(timer);
  };

  node.addEventListener('mousedown', start);
  node.addEventListener('mouseup', cancel);
  node.addEventListener('mouseleave', cancel);
  node.addEventListener('touchstart', start);
  node.addEventListener('touchend', cancel);
  node.addEventListener('touchcancel', cancel);

  return {
    destroy() {
      cancel();
      node.removeEventListener('mousedown', start);
      node.removeEventListener('mouseup', cancel);
      node.removeEventListener('mouseleave', cancel);
      node.removeEventListener('touchstart', start);
      node.removeEventListener('touchend', cancel);
      node.removeEventListener('touchcancel', cancel);
    },
    update(newParams: typeof params) {
      Object.assign(params, newParams);
    },
  };
}

// ============================================
// Lifecycle Helpers
// ============================================

/**
 * Run callback on mount and return cleanup function
 */
export function onMountWithCleanup(callback: () => void | (() => void)) {
  let cleanup: void | (() => void);

  onMount(() => {
    cleanup = callback();
  });

  onDestroy(() => {
    if (typeof cleanup === 'function') {
      cleanup();
    }
  });
}

/**
 * Subscribe to a store only when component is mounted
 */
export function subscribeOnMount<T>(store: Readable<T>, callback: (value: T) => void) {
  let unsubscribe: () => void;

  onMount(() => {
    unsubscribe = store.subscribe(callback);
  });

  onDestroy(() => {
    unsubscribe?.();
  });
}
