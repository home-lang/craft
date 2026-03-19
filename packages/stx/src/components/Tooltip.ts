import { cx } from '../styles'
import { h } from '../component'

export interface TooltipProps {
  text: string
  position?: 'top' | 'bottom' | 'left' | 'right'
  class?: string
}

const positionClasses: Record<string, string> = {
  top: 'bottom-full left-1/2 -translate-x-1/2 mb-2',
  bottom: 'top-full left-1/2 -translate-x-1/2 mt-2',
  left: 'right-full top-1/2 -translate-y-1/2 mr-2',
  right: 'left-full top-1/2 -translate-y-1/2 ml-2',
}

export function Tooltip(
  props: TooltipProps,
  ...children: Array<string | HTMLElement>
): HTMLElement {
  const wrapper = h('div', { class: 'relative inline-block' })

  const tooltip = h('div', {
    class: cx(
      'absolute z-50 px-2 py-1 text-xs text-white bg-gray-900 rounded shadow-lg whitespace-nowrap opacity-0 pointer-events-none transition-opacity dark:bg-gray-100 dark:text-gray-900',
      positionClasses[props.position ?? 'top'],
      props.class,
    ),
    role: 'tooltip',
  }, props.text)

  const trigger = h('div', { class: 'inline-block' }, ...children)

  trigger.addEventListener('mouseenter', () => {
    tooltip.style.opacity = '1'
  })
  trigger.addEventListener('mouseleave', () => {
    tooltip.style.opacity = '0'
  })

  wrapper.appendChild(trigger)
  wrapper.appendChild(tooltip)
  return wrapper
}
