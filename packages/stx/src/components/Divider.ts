import { cx } from '../styles'
import { h } from '../component'

export interface DividerProps {
  orientation?: 'horizontal' | 'vertical'
  class?: string
}

export function Divider(props: DividerProps = {}): HTMLElement {
  const isVertical = props.orientation === 'vertical'

  const className = cx(
    isVertical
      ? 'w-px h-full bg-gray-200 dark:bg-gray-700'
      : 'h-px w-full bg-gray-200 dark:bg-gray-700',
    props.class,
  )

  return h('div', { class: className, role: 'separator' })
}
