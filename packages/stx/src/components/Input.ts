import { variants, cx } from '../styles'
import { h } from '../component'

export interface InputProps {
  type?: string
  placeholder?: string
  value?: string
  disabled?: boolean
  readonly?: boolean
  size?: 'sm' | 'md' | 'lg'
  variant?: 'default' | 'error'
  class?: string
  onInput?: (e: Event) => void
  onChange?: (e: Event) => void
  onFocus?: (e: Event) => void
  onBlur?: (e: Event) => void
}

export const inputVariants = variants({
  base: 'w-full rounded-md border bg-white text-gray-900 placeholder:text-gray-400 transition-colors focus:outline-none focus:ring-2 focus:ring-offset-1 disabled:opacity-50 disabled:cursor-not-allowed',
  variants: {
    variant: {
      default: 'border-gray-300 focus:border-blue-500 focus:ring-blue-500',
      error: 'border-red-500 focus:border-red-500 focus:ring-red-500',
    },
    size: {
      sm: 'h-8 px-3 text-sm',
      md: 'h-10 px-3 text-sm',
      lg: 'h-12 px-4 text-base',
    },
  },
  defaultVariants: {
    variant: 'default',
    size: 'md',
  },
})

export function Input(props: InputProps = {}): HTMLElement {
  const className = cx(
    inputVariants({ variant: props.variant, size: props.size }),
    props.class,
  )

  return h('input', {
    class: className,
    type: props.type ?? 'text',
    placeholder: props.placeholder,
    value: props.value,
    disabled: props.disabled,
    readonly: props.readonly,
    onInput: props.onInput,
    onChange: props.onChange,
    onFocus: props.onFocus,
    onBlur: props.onBlur,
  })
}
