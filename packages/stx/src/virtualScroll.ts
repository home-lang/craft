/**
 * STX Virtual Scrolling
 *
 * Windowed rendering for large lists and grids.
 * Only renders items visible in the viewport + buffer.
 *
 * - createVirtualList() — windowed list
 * - createVirtualGrid() — windowed grid
 * - Infinite scroll support via onEndReached callback
 */

import { state, effect, onDestroy } from './runtime'
import { h } from './component'
import type { State } from './runtime'

export interface VirtualListOptions<T> {
  /** Fixed item height in pixels */
  itemHeight: number
  /** Number of items to render above/below viewport */
  overscan?: number
  /** Container height (px or CSS value) */
  height?: number | string
  /** Container CSS class */
  class?: string
  /** Callback when scrolled near the end */
  onEndReached?: () => void
  /** Distance from bottom to trigger onEndReached (px) */
  endReachedThreshold?: number
}

export interface VirtualGridOptions<T> {
  /** Fixed item height in pixels */
  itemHeight: number
  /** Fixed item width in pixels */
  itemWidth: number
  /** Number of rows to render above/below viewport */
  overscan?: number
  /** Container height */
  height?: number | string
  /** Container CSS class */
  class?: string
  /** Gap between items in pixels */
  gap?: number
}

export interface VirtualListInstance<T> {
  /** The container element to mount */
  element: HTMLElement
  /** Scroll to a specific index */
  scrollToIndex: (index: number, behavior?: ScrollBehavior) => void
  /** Currently visible range */
  visibleRange: State<{ start: number; end: number }>
}

/**
 * Create a virtualized list that only renders visible items.
 *
 * @example
 * const items = state(Array.from({ length: 10000 }, (_, i) => `Item ${i}`))
 *
 * const list = createVirtualList(items, {
 *   itemHeight: 40,
 *   height: 400,
 * }, (item, index) => {
 *   return h('div', { class: 'p-2 border-b' }, item)
 * })
 *
 * mount(list.element, '#app')
 */
export function createVirtualList<T>(
  items: State<T[]> | T[],
  options: VirtualListOptions<T>,
  renderItem: (item: T, index: number) => HTMLElement,
): VirtualListInstance<T> {
  const { itemHeight, overscan = 5, endReachedThreshold = 200 } = options
  const containerHeight = typeof options.height === 'number' ? `${options.height}px` : (options.height ?? '100%')
  const visibleRange = state({ start: 0, end: 0 })

  const getItems = (): T[] => typeof items === 'function' ? (items as State<T[]>)() : items

  // Container
  const container = h('div', {
    class: options.class ?? '',
    style: { height: containerHeight, overflow: 'auto', position: 'relative' },
  })

  // Spacer (full height to maintain scrollbar)
  const spacer = h('div', { style: { position: 'relative', width: '100%' } })
  container.appendChild(spacer)

  // Viewport (positioned items)
  const viewport = h('div', { style: { position: 'absolute', top: '0', left: '0', width: '100%' } })
  spacer.appendChild(viewport)

  const render = () => {
    const allItems = getItems()
    const totalHeight = allItems.length * itemHeight
    spacer.style.height = `${totalHeight}px`

    const scrollTop = container.scrollTop
    const viewHeight = container.clientHeight

    const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - overscan)
    const endIndex = Math.min(allItems.length, Math.ceil((scrollTop + viewHeight) / itemHeight) + overscan)

    visibleRange.set({ start: startIndex, end: endIndex })

    viewport.innerHTML = ''
    viewport.style.top = `${startIndex * itemHeight}px`

    for (let i = startIndex; i < endIndex; i++) {
      const el = renderItem(allItems[i], i)
      el.style.height = `${itemHeight}px`
      viewport.appendChild(el)
    }

    // End reached detection
    if (options.onEndReached && scrollTop + viewHeight >= totalHeight - endReachedThreshold) {
      options.onEndReached()
    }
  }

  container.addEventListener('scroll', render, { passive: true })

  // Re-render when items change
  if (typeof items === 'function' && 'subscribe' in items) {
    effect(() => {
      (items as State<T[]>)()
      render()
    })
  }
  else {
    queueMicrotask(render)
  }

  const scrollToIndex = (index: number, behavior: ScrollBehavior = 'smooth') => {
    container.scrollTo({ top: index * itemHeight, behavior })
  }

  return { element: container, scrollToIndex, visibleRange }
}

/**
 * Create a virtualized grid.
 *
 * @example
 * const grid = createVirtualGrid(images, {
 *   itemHeight: 200,
 *   itemWidth: 200,
 *   gap: 8,
 *   height: 600,
 * }, (item) => h('img', { src: item.url, class: 'rounded' }))
 */
export function createVirtualGrid<T>(
  items: State<T[]> | T[],
  options: VirtualGridOptions<T>,
  renderItem: (item: T, index: number) => HTMLElement,
): VirtualListInstance<T> {
  const { itemHeight, itemWidth, overscan = 2, gap = 0 } = options
  const containerHeight = typeof options.height === 'number' ? `${options.height}px` : (options.height ?? '100%')
  const visibleRange = state({ start: 0, end: 0 })

  const getItems = (): T[] => typeof items === 'function' ? (items as State<T[]>)() : items

  const container = h('div', {
    class: options.class ?? '',
    style: { height: containerHeight, overflow: 'auto', position: 'relative' },
  })

  const spacer = h('div', { style: { position: 'relative', width: '100%' } })
  container.appendChild(spacer)

  const viewport = h('div', {
    style: {
      position: 'absolute',
      top: '0',
      left: '0',
      width: '100%',
      display: 'flex',
      flexWrap: 'wrap',
      gap: `${gap}px`,
    },
  })
  spacer.appendChild(viewport)

  const render = () => {
    const allItems = getItems()
    const containerWidth = container.clientWidth
    const cols = Math.max(1, Math.floor((containerWidth + gap) / (itemWidth + gap)))
    const rows = Math.ceil(allItems.length / cols)
    const rowHeight = itemHeight + gap
    const totalHeight = rows * rowHeight

    spacer.style.height = `${totalHeight}px`

    const scrollTop = container.scrollTop
    const viewHeight = container.clientHeight

    const startRow = Math.max(0, Math.floor(scrollTop / rowHeight) - overscan)
    const endRow = Math.min(rows, Math.ceil((scrollTop + viewHeight) / rowHeight) + overscan)

    const startIndex = startRow * cols
    const endIndex = Math.min(allItems.length, endRow * cols)

    visibleRange.set({ start: startIndex, end: endIndex })

    viewport.innerHTML = ''
    viewport.style.top = `${startRow * rowHeight}px`

    for (let i = startIndex; i < endIndex; i++) {
      const el = renderItem(allItems[i], i)
      el.style.width = `${itemWidth}px`
      el.style.height = `${itemHeight}px`
      viewport.appendChild(el)
    }
  }

  container.addEventListener('scroll', render, { passive: true })

  if (typeof items === 'function' && 'subscribe' in items) {
    effect(() => {
      (items as State<T[]>)()
      render()
    })
  }
  else {
    queueMicrotask(render)
  }

  const scrollToIndex = (index: number, behavior: ScrollBehavior = 'smooth') => {
    const containerWidth = container.clientWidth
    const cols = Math.max(1, Math.floor((containerWidth + gap) / (itemWidth + gap)))
    const row = Math.floor(index / cols)
    container.scrollTo({ top: row * (itemHeight + gap), behavior })
  }

  return { element: container, scrollToIndex, visibleRange }
}
