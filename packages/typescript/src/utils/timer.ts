/**
 * Timer utilities for Craft applications
 * Simple interval-based timer with callbacks
 */

export type TimerCallback = (timeRemaining: number) => void

export class Timer {
  private intervalId: ReturnType<typeof setInterval> | null = null
  private timeRemaining: number = 0
  private isRunning: boolean = false

  constructor(
    private duration: number,
    private onTick: TimerCallback,
    private onComplete?: () => void,
  ) {
    this.timeRemaining = duration
  }

  /**
   * Start the timer
   */
  start(): void {
    if (this.isRunning)
      return

    this.isRunning = true
    this.intervalId = setInterval(() => {
      this.timeRemaining--
      this.onTick(this.timeRemaining)

      if (this.timeRemaining <= 0) {
        this.pause()
        this.onComplete?.()
      }
    }, 1000)
  }

  /**
   * Pause the timer
   */
  pause(): void {
    if (!this.isRunning)
      return

    this.isRunning = false
    if (this.intervalId) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }
  }

  /**
   * Reset the timer to initial duration
   */
  reset(): void {
    this.pause()
    this.timeRemaining = this.duration
    this.onTick(this.timeRemaining)
  }

  /**
   * Set a new duration
   */
  setDuration(duration: number): void {
    this.duration = duration
    this.timeRemaining = duration
  }

  /**
   * Get current time remaining
   */
  getTimeRemaining(): number {
    return this.timeRemaining
  }

  /**
   * Check if timer is running
   */
  running(): boolean {
    return this.isRunning
  }

  /**
   * Format time as MM:SS
   */
  static formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}
