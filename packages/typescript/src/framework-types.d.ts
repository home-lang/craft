/**
 * Type declarations for optional framework peer dependencies.
 * These modules are NOT bundled with this package - users bring their own.
 * These minimal declarations allow TypeScript to compile without errors
 * when the framework packages are not installed.
 */

declare module 'react' {
  export function useState<T>(_initialState: T | (() => T)): [T, (value: T | ((prev: T) => T)) => void];
  export function useEffect(_effect: () => void | (() => void), deps?: readonly unknown[]): void;
  export function useCallback<T extends (..._args: any[]) => any>(_callback: T, deps: readonly unknown[]): T;
  export function useMemo<T>(_factory: () => T, deps: readonly unknown[]): T;
  export function useRef<T>(_initialValue: T): { current: T };
  export function useRef<T>(_initialValue: T | null): RefObject<T>;
  export function useSyncExternalStore<T>(
    _subscribe: (onStoreChange: () => void) => () => void,
    getSnapshot: () => T,
    getServerSnapshot?: () => T,
  ): T;

  export interface RefObject<T> {
    readonly current: T | null;
  }
}

declare module 'vue' {
  export function computed<T>(_getter: () => T): ComputedRef<T>;
  export function inject<T>(_key: InjectionKey<T>): T | undefined;
  export function onMounted(_callback: () => void): void;
  export function onUnmounted(_callback: () => void): void;
  export function provide<T>(_key: InjectionKey<T>, _value: T): void;
  export function reactive<T extends object>(_target: T): T;
  export function readonly<T>(_target: T): T;
  export function ref<T>(_value: T): Ref<T>;
  export function shallowRef<T>(_value: T): Ref<T>;
  export function watch<T>(
    _source: Ref<T>,
    _callback: (newValue: T, oldValue: T) => void,
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

  export function writable<T>(_value: T): Writable<T>;
  export function derived<T, S>(_store: Readable<S>, _fn: (value: S) => T): Readable<T>;
  export function readable<T>(_value: T, _start?: (set: (value: T) => void) => void | (() => void)): Readable<T>;
  export function get<T>(_store: Readable<T>): T;
}

declare module 'svelte' {
  export function onMount(_callback: () => void | (() => void)): void;
  export function onDestroy(_callback: () => void): void;
}
