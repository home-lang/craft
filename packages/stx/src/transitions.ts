/**
 * STX Transitions
 *
 * CSS-based enter/leave transitions for elements.
 * Supports built-in presets and custom transition names.
 *
 * Built-in: fade, slide-up, slide-down, slide-left, slide-right,
 * scale, scale-up, bounce, flip, zoom, collapse
 */

import { effect } from './runtime'
import type { State } from './runtime'

export interface TransitionOptions {
  name?: string
  duration?: number
  mode?: 'in-out' | 'out-in' | 'default'
}

const BUILTIN_TRANSITIONS: Record<string, { enter: string; leave: string }> = {
  fade: {
    enter: 'opacity: 0 -> opacity: 1',
    leave: 'opacity: 1 -> opacity: 0',
  },
  'slide-up': {
    enter: 'transform: translateY(16px); opacity: 0 -> transform: translateY(0); opacity: 1',
    leave: 'transform: translateY(0); opacity: 1 -> transform: translateY(-16px); opacity: 0',
  },
  'slide-down': {
    enter: 'transform: translateY(-16px); opacity: 0 -> transform: translateY(0); opacity: 1',
    leave: 'transform: translateY(0); opacity: 1 -> transform: translateY(16px); opacity: 0',
  },
  'slide-left': {
    enter: 'transform: translateX(16px); opacity: 0 -> transform: translateX(0); opacity: 1',
    leave: 'transform: translateX(0); opacity: 1 -> transform: translateX(-16px); opacity: 0',
  },
  'slide-right': {
    enter: 'transform: translateX(-16px); opacity: 0 -> transform: translateX(0); opacity: 1',
    leave: 'transform: translateX(0); opacity: 1 -> transform: translateX(16px); opacity: 0',
  },
  scale: {
    enter: 'transform: scale(0.95); opacity: 0 -> transform: scale(1); opacity: 1',
    leave: 'transform: scale(1); opacity: 1 -> transform: scale(0.95); opacity: 0',
  },
  'scale-up': {
    enter: 'transform: scale(0.5); opacity: 0 -> transform: scale(1); opacity: 1',
    leave: 'transform: scale(1); opacity: 1 -> transform: scale(1.1); opacity: 0',
  },
  bounce: {
    enter: 'transform: scale(0); opacity: 0 -> transform: scale(1); opacity: 1',
    leave: 'transform: scale(1); opacity: 1 -> transform: scale(0); opacity: 0',
  },
  flip: {
    enter: 'transform: rotateY(90deg); opacity: 0 -> transform: rotateY(0); opacity: 1',
    leave: 'transform: rotateY(0); opacity: 1 -> transform: rotateY(90deg); opacity: 0',
  },
  zoom: {
    enter: 'transform: scale(0.3); opacity: 0 -> transform: scale(1); opacity: 1',
    leave: 'transform: scale(1); opacity: 1 -> transform: scale(0.3); opacity: 0',
  },
  collapse: {
    enter: 'max-height: 0; opacity: 0; overflow: hidden -> max-height: 500px; opacity: 1; overflow: hidden',
    leave: 'max-height: 500px; opacity: 1; overflow: hidden -> max-height: 0; opacity: 0; overflow: hidden',
  },
}

let stylesInjected = false

function injectTransitionStyles(): void {
  if (stylesInjected || typeof document === 'undefined') return
  stylesInjected = true

  const css = Object.entries(BUILTIN_TRANSITIONS).map(([name, { enter, leave }]) => {
    const [enterFrom, enterTo] = enter.split(' -> ')
    const [leaveFrom, leaveTo] = leave.split(' -> ')
    return `
.stx-${name}-enter-from { ${enterFrom} }
.stx-${name}-enter-to { ${enterTo} }
.stx-${name}-leave-from { ${leaveFrom} }
.stx-${name}-leave-to { ${leaveTo} }
.stx-${name}-enter-active, .stx-${name}-leave-active { transition: all var(--stx-transition-duration, 300ms) ease; }
`
  }).join('\n')

  const style = document.createElement('style')
  style.setAttribute('data-stx-transitions', '')
  style.textContent = css
  document.head.appendChild(style)
}

/**
 * Apply a transition to an element reactively based on a show signal.
 *
 * @example
 * const visible = state(false)
 * const el = h('div', {}, 'Hello')
 * transition(el, visible, { name: 'fade', duration: 200 })
 */
export function transition(el: HTMLElement, show: State<boolean>, options: TransitionOptions = {}): void {
  const name = options.name ?? 'fade'
  const duration = options.duration ?? 300

  injectTransitionStyles()
  el.style.setProperty('--stx-transition-duration', `${duration}ms`)

  let isFirst = true

  effect(() => {
    const visible = show()

    if (isFirst) {
      el.style.display = visible ? '' : 'none'
      isFirst = false
      return
    }

    if (visible) {
      // Enter transition
      el.style.display = ''
      el.classList.add(`stx-${name}-enter-from`)
      el.classList.add(`stx-${name}-enter-active`)

      requestAnimationFrame(() => {
        el.classList.remove(`stx-${name}-enter-from`)
        el.classList.add(`stx-${name}-enter-to`)

        setTimeout(() => {
          el.classList.remove(`stx-${name}-enter-active`)
          el.classList.remove(`stx-${name}-enter-to`)
        }, duration)
      })
    }
    else {
      // Leave transition
      el.classList.add(`stx-${name}-leave-from`)
      el.classList.add(`stx-${name}-leave-active`)

      requestAnimationFrame(() => {
        el.classList.remove(`stx-${name}-leave-from`)
        el.classList.add(`stx-${name}-leave-to`)

        setTimeout(() => {
          el.classList.remove(`stx-${name}-leave-active`)
          el.classList.remove(`stx-${name}-leave-to`)
          el.style.display = 'none'
        }, duration)
      })
    }
  })
}

/**
 * Programmatic transition API.
 */
export const STXTransition = {
  enter(el: HTMLElement, name: string = 'fade', duration: number = 300): Promise<void> {
    injectTransitionStyles()
    el.style.setProperty('--stx-transition-duration', `${duration}ms`)
    el.style.display = ''
    el.classList.add(`stx-${name}-enter-from`, `stx-${name}-enter-active`)

    return new Promise((resolve) => {
      requestAnimationFrame(() => {
        el.classList.remove(`stx-${name}-enter-from`)
        el.classList.add(`stx-${name}-enter-to`)

        setTimeout(() => {
          el.classList.remove(`stx-${name}-enter-active`, `stx-${name}-enter-to`)
          resolve()
        }, duration)
      })
    })
  },

  leave(el: HTMLElement, name: string = 'fade', duration: number = 300): Promise<void> {
    injectTransitionStyles()
    el.style.setProperty('--stx-transition-duration', `${duration}ms`)
    el.classList.add(`stx-${name}-leave-from`, `stx-${name}-leave-active`)

    return new Promise((resolve) => {
      requestAnimationFrame(() => {
        el.classList.remove(`stx-${name}-leave-from`)
        el.classList.add(`stx-${name}-leave-to`)

        setTimeout(() => {
          el.classList.remove(`stx-${name}-leave-active`, `stx-${name}-leave-to`)
          el.style.display = 'none'
          resolve()
        }, duration)
      })
    })
  },

  async toggle(el: HTMLElement, show: boolean, name: string = 'fade', duration: number = 300): Promise<void> {
    if (show) {
      await this.enter(el, name, duration)
    }
    else {
      await this.leave(el, name, duration)
    }
  },
}
