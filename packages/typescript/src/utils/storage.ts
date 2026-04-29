/**
 * Storage utilities for Craft applications
 * Simple localStorage abstraction with type safety
 */

function hasLocalStorage(): boolean {
  return typeof globalThis !== 'undefined' && typeof (globalThis as any).localStorage !== 'undefined'
}

export class Storage<T> {
  constructor(private key: string, private defaults: T) {}

  /**
   * Load data from localStorage.
   *
   * Object-shaped saved values are merged on top of `defaults`, so newly
   * added keys in `defaults` still appear when an older payload is read.
   * Arrays and primitives are returned verbatim — the previous
   * implementation spread them into `defaults`, which silently corrupted
   * arrays (each numeric index turned into a key on an object) and
   * threw on primitives.
   */
  load(): T {
    if (!hasLocalStorage()) return this.defaults
    try {
      const saved = localStorage.getItem(this.key)
      if (saved) {
        const parsed = JSON.parse(saved) as T
        if (Array.isArray(parsed) || Array.isArray(this.defaults as unknown)) {
          return parsed
        }
        if (
          parsed !== null
          && typeof parsed === 'object'
          && this.defaults !== null
          && typeof this.defaults === 'object'
        ) {
          return { ...(this.defaults as object), ...(parsed as object) } as T
        }
        return parsed
      }
    }
    catch (e) {
      console.error(`Failed to load ${this.key}:`, e)
    }
    return this.defaults
  }

  /**
   * Save data to localStorage
   */
  save(data: T): void {
    if (!hasLocalStorage()) return
    try {
      localStorage.setItem(this.key, JSON.stringify(data))
    }
    catch (e) {
      console.error(`Failed to save ${this.key}:`, e)
    }
  }

  /**
   * Update partial data in localStorage. Merges only when both the
   * existing and incoming values are plain objects; otherwise replaces
   * outright (so this method never silently corrupts array data).
   */
  update(partial: Partial<T>): void {
    const current = this.load()
    if (
      current !== null
      && typeof current === 'object'
      && !Array.isArray(current)
      && partial !== null
      && typeof partial === 'object'
      && !Array.isArray(partial)
    ) {
      this.save({ ...(current as object), ...(partial as object) } as T)
      return
    }
    this.save(partial as T)
  }

  /**
   * Clear data from localStorage
   */
  clear(): void {
    if (!hasLocalStorage()) return
    try {
      localStorage.removeItem(this.key)
    }
    catch (e) {
      console.error(`Failed to clear ${this.key}:`, e)
    }
  }
}
