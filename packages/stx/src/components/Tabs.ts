import { cx } from '../styles'
import { h } from '../component'
import { state, effect } from '../runtime'
import type { State } from '../runtime'

export interface TabItem {
  id: string
  label: string
  content: () => HTMLElement | string
}

export interface TabsProps {
  items: TabItem[]
  active?: State<string>
  class?: string
  onChange?: (id: string) => void
}

export function Tabs(props: TabsProps): HTMLElement {
  const activeId = props.active ?? state(props.items[0]?.id ?? '')

  const container = h('div', { class: cx('w-full', props.class) })

  // Tab buttons
  const tabList = h('div', {
    class: 'flex border-b border-gray-200',
    role: 'tablist',
  })

  const contentArea = h('div', { class: 'py-4' })

  for (const item of props.items) {
    const tabBtn = h('button', {
      class: 'px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px',
      role: 'tab',
      onClick: () => {
        activeId.set(item.id)
        props.onChange?.(item.id)
      },
    }, item.label)

    effect(() => {
      if (activeId() === item.id) {
        tabBtn.className = 'px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px text-blue-600 border-blue-600'
      }
      else {
        tabBtn.className = 'px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px text-gray-500 border-transparent hover:text-gray-700'
      }
    })

    tabList.appendChild(tabBtn)
  }

  // Reactive content
  effect(() => {
    contentArea.innerHTML = ''
    const activeItem = props.items.find(item => item.id === activeId())
    if (activeItem) {
      const content = activeItem.content()
      if (typeof content === 'string') {
        contentArea.innerHTML = content
      }
      else {
        contentArea.appendChild(content)
      }
    }
  })

  container.appendChild(tabList)
  container.appendChild(contentArea)
  return container
}
