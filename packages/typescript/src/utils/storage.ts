/**
 * Storage utilities for Craft applications
 * Simple localStorage abstraction with type safety
 */

export class Storage<T> {
  constructor(private key: string, private defaults: T) {}

  /**
   * Load data from localStorage
   */
  load(): T {
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
    try {
      localStorage.removeItem(this.key)
    }
    catch (e) {
      console.error(`Failed to clear ${this.key}:`, e)
    }
  }
}
