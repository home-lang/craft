/**
 * Timer utilities for Craft applications
 * Simple interval-based timer with callbacks
 */

export type TimerCallback = (_timeRemaining: number) => void

export class Timer {
  private intervalId: ReturnType<typeof setInterval> | null = null
  private timeRemaining: number = 0
  private isRunning: boolean = false
  /** Wallclock deadline (ms epoch). Used to recompute timeRemaining each
   * tick so the timer doesn't drift under load or tab throttling — a
   * simple `--` counter loses minutes over hours. */
  private endAt: number = 0
  /** Reference to a clock for testability — overridable so tests can
   * advance time deterministically. Defaults to `Date.now`. */
  private static now: () => number = () => Date.now()

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
    this.endAt = Timer.now() + this.timeRemaining * 1000
    this.intervalId = setInterval(() => {
      const ms = Math.max(0, this.endAt - Timer.now())
      this.timeRemaining = Math.ceil(ms / 1000)
      this.onTick(this.timeRemaining)

      if (this.timeRemaining <= 0) {
        this.pause()
        this.onComplete?.()
      }
    }, 250)
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
    this.endAt = Timer.now() + this.duration * 1000
    this.onTick(this.timeRemaining)
  }

  /**
   * Set a new duration
   */
  setDuration(duration: number): void {
    this.duration = duration
    this.timeRemaining = duration
    if (this.isRunning) {
      this.endAt = Timer.now() + duration * 1000
    }
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
   * Format time as MM:SS. Negative values are clamped to zero since the
   * timer should never display "negative time remaining" in a UI.
   */
  static formatTime(seconds: number): string {
    const clamped = Math.max(0, Math.floor(seconds))
    const mins = Math.floor(clamped / 60)
    const secs = clamped % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  /**
   * Override the wallclock used by `start()`/`reset()` for the lifetime
   * of the process. Intended for tests that need to advance time
   * deterministically. Pass `null` to restore `Date.now`.
   */
  static _setClockForTests(clock: (() => number) | null): void {
    Timer.now = clock ?? (() => Date.now())
  }
}
