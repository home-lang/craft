import { variants, cx } from '../styles'
import { h } from '../component'
import type { State, Derived } from '../runtime'

export interface BadgeProps {
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'info'
  size?: 'sm' | 'md'
  class?: string
}

export const badgeVariants = variants({
  base: 'inline-flex items-center rounded-full font-medium',
  variants: {
    variant: {
      default: 'bg-gray-100 text-gray-800',
      success: 'bg-green-100 text-green-800',
      warning: 'bg-yellow-100 text-yellow-800',
      danger: 'bg-red-100 text-red-800',
      info: 'bg-blue-100 text-blue-800',
    },
    size: {
      sm: 'px-2 py-0.5 text-xs',
      md: 'px-2.5 py-0.5 text-sm',
    },
  },
  defaultVariants: {
    variant: 'default',
    size: 'sm',
  },
})

export function Badge(
  props: BadgeProps = {},
  ...children: Array<string | HTMLElement | State<string> | Derived<string>>
): HTMLElement {
  const className = cx(
    badgeVariants({ variant: props.variant, size: props.size }),
    props.class,
  )

  return h('span', { class: className }, ...children)
}
