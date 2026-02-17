/**
 * Type declarations for optional framework peer dependencies.
 * These modules are NOT bundled with this package - users bring their own.
 * These minimal declarations allow TypeScript to compile without errors
 * when the framework packages are not installed.
 */

declare module 'react' {
  export function useState<T>(initialState: T | (() => T)): [T, (value: T | ((prev: T) => T)) => void];
  export function useEffect(effect: () => void | (() => void), deps?: readonly unknown[]): void;
  export function useCallback<T extends (...args: any[]) => any>(callback: T, deps: readonly unknown[]): T;
  export function useMemo<T>(factory: () => T, deps: readonly unknown[]): T;
  export function useRef<T>(initialValue: T): { current: T };
  export function useRef<T>(initialValue: T | null): RefObject<T>;
  export function useSyncExternalStore<T>(
    subscribe: (onStoreChange: () => void) => () => void,
    getSnapshot: () => T,
    getServerSnapshot?: () => T,
  ): T;

  export interface RefObject<T> {
    readonly current: T | null;
  }
}

declare module 'vue' {
  export function computed<T>(getter: () => T): ComputedRef<T>;
  export function inject<T>(key: InjectionKey<T>): T | undefined;
  export function onMounted(callback: () => void): void;
  export function onUnmounted(callback: () => void): void;
  export function provide<T>(key: InjectionKey<T>, value: T): void;
  export function reactive<T extends object>(target: T): T;
  export function readonly<T>(target: T): T;
  export function ref<T>(value: T): Ref<T>;
  export function shallowRef<T>(value: T): Ref<T>;
  export function watch<T>(
    source: Ref<T>,
    callback: (newValue: T, oldValue: T) => void,
    options?: { deep?: boolean },
  ): void;

  export interface App {
    provide<T>(key: InjectionKey<T>, value: T): this;
    config: {
      globalProperties: Record<string, any>;
    };
  }

  export interface ComputedRef<T> {
    readonly value: T;
  }

  export interface InjectionKey<T> extends Symbol {}

  export interface Ref<T> {
    value: T;
  }
}

declare module 'svelte/store' {
  export interface Writable<T> {
    subscribe(run: (value: T) => void): () => void;
    set(value: T): void;
    update(updater: (value: T) => T): void;
  }

  export interface Readable<T> {
    subscribe(run: (value: T) => void): () => void;
  }

  export function writable<T>(value: T): Writable<T>;
  export function derived<T, S>(store: Readable<S>, fn: (value: S) => T): Readable<T>;
  export function readable<T>(value: T, start?: (set: (value: T) => void) => void | (() => void)): Readable<T>;
  export function get<T>(store: Readable<T>): T;
}

declare module 'svelte' {
  export function onMount(callback: () => void | (() => void)): void;
  export function onDestroy(callback: () => void): void;
}
