import { variants, cx } from '../styles'
import { h } from '../component'
import type { ReadonlySignal } from '../runtime'

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  class?: string
  type?: 'button' | 'submit' | 'reset'
  onClick?: (e: Event) => void
}

export const buttonVariants = variants({
  base: 'inline-flex items-center justify-center rounded-md font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 cursor-pointer select-none',
  variants: {
    variant: {
      primary: 'bg-blue-500 text-white hover:bg-blue-600 focus:ring-blue-500',
      secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500',
      outline: 'border border-gray-300 text-gray-700 hover:bg-gray-50 focus:ring-blue-500',
      ghost: 'text-gray-700 hover:bg-gray-100 focus:ring-gray-500',
      danger: 'bg-red-500 text-white hover:bg-red-600 focus:ring-red-500',
    },
    size: {
      sm: 'h-8 px-3 text-sm gap-1.5',
      md: 'h-10 px-4 text-sm gap-2',
      lg: 'h-12 px-6 text-base gap-2.5',
    },
  },
  defaultVariants: {
    variant: 'primary',
    size: 'md',
  },
})

export function Button(
  props: ButtonProps = {},
  ...children: Array<string | HTMLElement | ReadonlySignal<string>>
): HTMLElement {
  const className = cx(
    buttonVariants({ variant: props.variant, size: props.size }),
    props.disabled && 'opacity-50 cursor-not-allowed pointer-events-none',
    props.class,
  )

  return h(
    'button',
    {
      class: className,
      type: props.type ?? 'button',
      disabled: props.disabled,
      onClick: props.onClick,
    },
    ...children,
  )
}
