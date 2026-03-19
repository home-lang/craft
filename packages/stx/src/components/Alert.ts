import { variants, cx } from '../styles'
import { h } from '../component'
import type { State, Derived } from '../runtime'

export interface AlertProps {
  variant?: 'info' | 'success' | 'warning' | 'error'
  class?: string
  dismissible?: boolean
  onDismiss?: () => void
}

export const alertVariants = variants({
  base: 'relative w-full rounded-lg border p-4 text-sm',
  variants: {
    variant: {
      info: 'border-blue-200 bg-blue-50 text-blue-800',
      success: 'border-green-200 bg-green-50 text-green-800',
      warning: 'border-yellow-200 bg-yellow-50 text-yellow-800',
      error: 'border-red-200 bg-red-50 text-red-800',
    },
  },
  defaultVariants: {
    variant: 'info',
  },
})

export function Alert(
  props: AlertProps = {},
  ...children: Array<string | HTMLElement | State<string> | Derived<string>>
): HTMLElement {
  const className = cx(
    alertVariants({ variant: props.variant }),
    props.class,
  )

  const el = h('div', { class: className, role: 'alert' }, ...children)

  if (props.dismissible) {
    const closeBtn = h(
      'button',
      {
        class: 'absolute top-2 right-2 p-1 rounded-md opacity-70 hover:opacity-100 transition-opacity',
        onClick: () => {
          el.remove()
          props.onDismiss?.()
        },
      },
      '\u00d7',
    )
    el.appendChild(closeBtn)
  }

  return el
}
