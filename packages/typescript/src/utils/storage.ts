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
   * Load data from localStorage
   */
  load(): T {
    if (!hasLocalStorage()) return this.defaults
    try {
      const saved = localStorage.getItem(this.key)
      if (saved) {
        return { ...this.defaults, ...JSON.parse(saved) }
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
   * Update partial data in localStorage
   */
  update(partial: Partial<T>): void {
    const current = this.load()
    this.save({ ...current, ...partial })
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
