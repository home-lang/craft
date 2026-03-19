import { cx } from '../styles'
import { h } from '../component'
import type { State, Derived } from '../runtime'

export interface CardProps {
  class?: string
  padding?: boolean
}

type Child = string | HTMLElement | State<string> | Derived<string>

export function Card(
  props: CardProps = {},
  ...children: Child[]
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
  ...children: Child[]
): HTMLElement {
  return h(
    'div',
    { class: cx('border-b border-gray-200 px-6 py-4', props.class) },
    ...children,
  )
}

export function CardBody(
  props: { class?: string } = {},
  ...children: Child[]
): HTMLElement {
  return h(
    'div',
    { class: cx('px-6 py-4', props.class) },
    ...children,
  )
}

export function CardFooter(
  props: { class?: string } = {},
  ...children: Child[]
): HTMLElement {
  return h(
    'div',
    { class: cx('border-t border-gray-200 px-6 py-4', props.class) },
    ...children,
  )
}
