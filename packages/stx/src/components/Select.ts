import { cx } from '../styles'
import { h } from '../component'

export interface SelectOption {
  value: string
  label: string
  disabled?: boolean
}

export interface SelectProps {
  options: SelectOption[]
  value?: string
  placeholder?: string
  disabled?: boolean
  size?: 'sm' | 'md' | 'lg'
  class?: string
  onChange?: (value: string) => void
}

const sizeClasses: Record<string, string> = {
  sm: 'h-8 px-3 text-sm',
  md: 'h-10 px-3 text-sm',
  lg: 'h-12 px-4 text-base',
}

export function Select(props: SelectProps): HTMLElement {
  const className = cx(
    'w-full appearance-none rounded-md border border-gray-300 bg-white text-gray-900 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50 disabled:cursor-not-allowed',
    sizeClasses[props.size ?? 'md'],
    props.class,
  )

  const select = h('select', {
    class: className,
    disabled: props.disabled,
    onChange: (e: Event) => {
      const target = e.target as HTMLSelectElement
      props.onChange?.(target.value)
    },
  })

  if (props.placeholder) {
    const placeholderOpt = h('option', { value: '', disabled: true, selected: !props.value })
    placeholderOpt.textContent = props.placeholder
    select.appendChild(placeholderOpt)
  }

  for (const opt of props.options) {
    const option = h('option', {
      value: opt.value,
      disabled: opt.disabled,
      selected: props.value === opt.value,
    })
    option.textContent = opt.label
    select.appendChild(option)
  }

  return select
}
