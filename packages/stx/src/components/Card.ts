import { cx } from '../styles'
import { h } from '../component'
import type { ReadonlySignal } from '../runtime'

export interface CardProps {
  class?: string
  padding?: boolean
}

export function Card(
  props: CardProps = {},
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  const className = cx(
    'rounded-lg border border-gray-200 bg-white shadow-sm',
    props.padding !== false && 'p-6',
    props.class,
  )

  return h('div', { class: className }, ...children)
}

export function CardHeader(
  props: { class?: string } = {},
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  return h(
    'div',
    { class: cx('border-b border-gray-200 px-6 py-4', props.class) },
    ...children,
  )
}

export function CardBody(
  props: { class?: string } = {},
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  return h(
    'div',
    { class: cx('px-6 py-4', props.class) },
    ...children,
  )
}

export function CardFooter(
  props: { class?: string } = {},
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  return h(
    'div',
    { class: cx('border-t border-gray-200 px-6 py-4', props.class) },
    ...children,
  )
}
