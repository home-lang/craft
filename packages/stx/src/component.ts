/**
 * STX Component System
 *
 * Lightweight component abstraction for rendering UI in craft webviews.
 * Components use signals for state and return HTML elements.
 */

import { effect } from './runtime'
import type { Signal, Computed, ReadonlySignal } from './runtime'

export type Slot = () => string | HTMLElement | HTMLElement[]

export interface Props {
  [key: string]: unknown
}

export interface ComponentDef<P extends Props = Props> {
  setup(props: P, ctx: { slots: Record<string, Slot>; emit: (event: string, ...args: unknown[]) => void }): () => HTMLElement | string
}

export interface Component<P extends Props = Props> {
  (props?: P & { children?: Slot }): HTMLElement
}

/**
 * Define a component with setup function.
 */
export function defineComponent<P extends Props = Props>(
  def: ComponentDef<P>,
): Component<P> {
  return (props?: P & { children?: Slot }) => {
    const resolvedProps = (props ?? {}) as P
    const slots: Record<string, Slot> = {}
    if (props?.children) {
      slots.default = props.children
    }

    const listeners: Array<{ event: string; handler: (...args: unknown[]) => void }> = []
    const emit = (event: string, ...args: unknown[]) => {
      for (const l of listeners) {
        if (l.event === event) l.handler(...args)
      }
    }

    const render = def.setup(resolvedProps, { slots, emit })
    const result = render()

    if (typeof result === 'string') {
      const wrapper = document.createElement('div')
      wrapper.innerHTML = result
      return wrapper.firstElementChild as HTMLElement || wrapper
    }

    return result
  }
}

/**
 * Create an HTML element with attributes and children.
 */
export function h(
  tag: string,
  attrs?: Record<string, unknown>,
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  const el = document.createElement(tag)

  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      if (key.startsWith('on') && typeof value === 'function') {
        const event = key.slice(2).toLowerCase()
        el.addEventListener(event, value as EventListener)
      }
      else if (key === 'class') {
        if (typeof value === 'string') {
          el.className = value
        }
        else if (value && typeof (value as ReadonlySignal<string>).subscribe === 'function') {
          const sig = value as ReadonlySignal<string>
          el.className = sig.value
          effect(() => {
            el.className = sig.value
          })
        }
      }
      else if (key === 'style' && typeof value === 'object') {
        Object.assign(el.style, value)
      }
      else if (typeof value === 'boolean') {
        if (value) el.setAttribute(key, '')
        else el.removeAttribute(key)
      }
      else if (value != null) {
        el.setAttribute(key, String(value))
      }
    }
  }

  for (const child of children) {
    if (typeof child === 'string') {
      el.appendChild(document.createTextNode(child))
    }
    else if (child instanceof HTMLElement) {
      el.appendChild(child)
    }
    else if (child && typeof (child as ReadonlySignal<string>).subscribe === 'function') {
      const sig = child as ReadonlySignal<string>
      const text = document.createTextNode(sig.value)
      effect(() => {
        text.textContent = sig.value
      })
      el.appendChild(text)
    }
  }

  return el
}

/**
 * Mount a component into a DOM container.
 */
export function mount(
  component: HTMLElement | (() => HTMLElement),
  container: HTMLElement | string,
): void {
  const target = typeof container === 'string'
    ? document.querySelector(container)
    : container

  if (!target) {
    throw new Error(`Mount target not found: ${container}`)
  }

  const el = typeof component === 'function' ? component() : component
  target.appendChild(el)
}
