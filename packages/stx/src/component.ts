/**
 * STX Component System
 *
 * Aligned with the stx composition API:
 * - defineProps<T>() / withDefaults()
 * - defineEmits<T>()
 * - defineExpose()
 * - provide() / inject()
 * - Lifecycle hooks: onMount, onDestroy, onUpdate
 */

import { effect, _collectLifecycleHooks, _stopCollecting } from './runtime'
import type { State, Derived } from './runtime'

export type Slot = () => string | HTMLElement | HTMLElement[]

export interface Props {
  [key: string]: unknown
}

export interface ComponentContext {
  slots: Record<string, Slot>
  emit: (event: string, ...args: unknown[]) => void
  expose: (exposed: Record<string, unknown>) => void
}

export interface ComponentDef<P extends Props = Props> {
  setup(props: P, ctx: ComponentContext): () => HTMLElement | string
}

export interface Component<P extends Props = Props> {
  (props?: P & { children?: Slot }): HTMLElement
  __exposed?: Record<string, unknown>
}

// ============================================================================
// Composition API
// ============================================================================

/**
 * Define typed props for a component.
 * In the stx runtime, this returns the props object passed in.
 *
 * @example
 * const props = defineProps<{ title: string; count: number }>()
 */
export function defineProps<T extends Props>(): T {
  // Resolved at component instantiation — returns placeholder
  return {} as T
}

/**
 * Apply defaults to defineProps result.
 *
 * @example
 * const props = withDefaults(defineProps<{ size?: string }>(), { size: 'md' })
 */
export function withDefaults<T extends Props>(
  props: T,
  defaults: Partial<T>,
): Required<T> {
  return { ...defaults, ...props } as Required<T>
}

/**
 * Define typed emits for a component.
 *
 * @example
 * const emit = defineEmits<{ click: [e: Event]; change: [value: string] }>()
 * emit('click', event)
 */
export function defineEmits<T extends Record<string, unknown[]>>(): (
  event: keyof T & string,
  ...args: T[keyof T & string]
) => void {
  // Resolved at component instantiation
  return (() => {}) as never
}

// Provide/Inject context store
const provideMap = new Map<string | symbol, unknown>()

/**
 * Provide a value for descendant components.
 */
export function provide<T>(key: string | symbol, value: T): void {
  provideMap.set(key, value)
}

/**
 * Inject a provided value from an ancestor component.
 */
export function inject<T>(key: string | symbol, defaultValue?: T): T {
  if (provideMap.has(key)) return provideMap.get(key) as T
  if (defaultValue !== undefined) return defaultValue
  throw new Error(`Injection "${String(key)}" not found`)
}

/**
 * Expose component internals for parent access.
 */
export function defineExpose(exposed: Record<string, unknown>): void {
  if (_currentExpose) {
    Object.assign(_currentExpose, exposed)
  }
}

let _currentExpose: Record<string, unknown> | null = null

// ============================================================================
// Component Definition
// ============================================================================

/**
 * Define a component with setup function.
 */
export function defineComponent<P extends Props = Props>(
  def: ComponentDef<P>,
): Component<P> {
  const comp: Component<P> = (props?: P & { children?: Slot }) => {
    const resolvedProps = (props ?? {}) as P
    const slots: Record<string, Slot> = {}
    if (props?.children) {
      slots.default = props.children
    }

    const listeners = new Map<string, Array<(...args: unknown[]) => void>>()
    const emit = (event: string, ...args: unknown[]) => {
      const handlers = listeners.get(event)
      if (handlers) {
        for (const handler of handlers) handler(...args)
      }
    }

    const exposed: Record<string, unknown> = {}
    _currentExpose = exposed
    const expose = (exp: Record<string, unknown>) => Object.assign(exposed, exp)

    // Collect lifecycle hooks during setup
    const hooks = _collectLifecycleHooks()

    const render = def.setup(resolvedProps, { slots, emit, expose })

    _stopCollecting()
    _currentExpose = null

    const result = render()
    const el = typeof result === 'string'
      ? (() => {
          const wrapper = document.createElement('div')
          wrapper.innerHTML = result
          return wrapper.firstElementChild as HTMLElement || wrapper
        })()
      : result

    // Run onMount hooks after element is created
    queueMicrotask(() => {
      for (const hook of hooks.mount) {
        const cleanup = hook()
        if (typeof cleanup === 'function') {
          hooks.destroy.push(cleanup)
        }
      }
    })

    // Store destroy hooks on element for cleanup
    ;(el as HTMLElement & { __stxDestroy?: () => void }).__stxDestroy = () => {
      for (const hook of hooks.destroy) hook()
    }

    comp.__exposed = exposed
    return el
  }

  return comp
}

// ============================================================================
// h() — Element creation with @ directive support
// ============================================================================

type Child = string | HTMLElement | State<string> | Derived<string>

function isReactiveGetter(val: unknown): val is State<string> | Derived<string> {
  return typeof val === 'function' && 'subscribe' in (val as object)
}

/**
 * Create an HTML element with attributes and children.
 * Supports @ directives and callable signals.
 */
export function h(
  tag: string,
  attrs?: Record<string, unknown>,
  ...children: Child[]
): HTMLElement {
  const el = document.createElement(tag)

  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      // Event handlers: onClick or @click
      if (key.startsWith('on') && typeof value === 'function') {
        const event = key.slice(2).toLowerCase()
        el.addEventListener(event, value as EventListener)
      }
      else if (key.startsWith('@') && key !== '@class' && key !== '@show' && key !== '@text' && key !== '@model') {
        // @click, @input, etc.
        const event = key.slice(1)
        if (typeof value === 'function') {
          el.addEventListener(event, value as EventListener)
        }
      }

      // @class — reactive class binding
      else if (key === '@class' || key === 'class') {
        if (typeof value === 'string') {
          el.className = value
        }
        else if (isReactiveGetter(value)) {
          el.className = value()
          effect(() => { el.className = value() })
        }
        else if (typeof value === 'object' && value !== null) {
          // Object syntax: { active: isActive(), disabled: isDisabled() }
          const updateClasses = () => {
            const classes: string[] = []
            for (const [cls, condition] of Object.entries(value as Record<string, unknown>)) {
              const active = typeof condition === 'function' ? (condition as () => boolean)() : condition
              if (active) classes.push(cls)
            }
            el.className = classes.join(' ')
          }
          effect(updateClasses)
        }
      }

      // @show — reactive visibility
      else if (key === '@show') {
        if (isReactiveGetter(value)) {
          effect(() => { el.style.display = value() ? '' : 'none' })
        }
        else if (typeof value === 'function') {
          effect(() => { el.style.display = (value as () => boolean)() ? '' : 'none' })
        }
        else {
          el.style.display = value ? '' : 'none'
        }
      }

      // @text — reactive text content
      else if (key === '@text') {
        if (isReactiveGetter(value)) {
          effect(() => { el.textContent = String(value()) })
        }
        else if (typeof value === 'function') {
          effect(() => { el.textContent = String((value as () => unknown)()) })
        }
        else {
          el.textContent = String(value)
        }
      }

      // @model — two-way binding
      else if (key === '@model') {
        if (isReactiveGetter(value) && 'set' in (value as object)) {
          const sig = value as State<string>
          ;(el as HTMLInputElement).value = sig()
          effect(() => { (el as HTMLInputElement).value = sig() })
          el.addEventListener('input', (e) => {
            sig.set((e.target as HTMLInputElement).value)
          })
        }
      }

      // @bind:attr — reactive attribute binding
      else if (key.startsWith('@bind:')) {
        const attr = key.slice(6)
        if (isReactiveGetter(value)) {
          effect(() => {
            const v = value()
            if (typeof v === 'boolean') {
              if (v) el.setAttribute(attr, '')
              else el.removeAttribute(attr)
            }
            else {
              el.setAttribute(attr, String(v))
            }
          })
        }
        else if (typeof value === 'function') {
          effect(() => {
            const v = (value as () => unknown)()
            el.setAttribute(attr, String(v))
          })
        }
      }

      // style object
      else if (key === 'style' && typeof value === 'object') {
        Object.assign(el.style, value)
      }

      // Boolean attributes
      else if (typeof value === 'boolean') {
        if (value) el.setAttribute(key, '')
        else el.removeAttribute(key)
      }

      // Regular attributes
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
    else if (isReactiveGetter(child)) {
      const text = document.createTextNode(child())
      effect(() => { text.textContent = child() })
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
