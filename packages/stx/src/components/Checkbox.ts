import { cx } from '../styles'
import { h } from '../component'
import { signal, effect } from '../runtime'
import type { Signal } from '../runtime'

export interface CheckboxProps {
  checked?: Signal<boolean>
  label?: string
  disabled?: boolean
  class?: string
  onChange?: (checked: boolean) => void
}

export function Checkbox(props: CheckboxProps = {}): HTMLElement {
  const isChecked = props.checked ?? signal(false)

  const wrapper = h('label', {
    class: cx(
      'inline-flex items-center gap-2 cursor-pointer select-none',
      props.disabled && 'opacity-50 cursor-not-allowed',
      props.class,
    ),
  })

  const input = h('input', {
    type: 'checkbox',
    class: 'h-4 w-4 rounded border-gray-300 text-blue-500 focus:ring-blue-500 focus:ring-2',
    disabled: props.disabled,
    onChange: (e: Event) => {
      const target = e.target as HTMLInputElement
      isChecked.value = target.checked
      props.onChange?.(target.checked)
    },
  }) as HTMLInputElement

  effect(() => {
    input.checked = isChecked.value
  })

  wrapper.appendChild(input)

  if (props.label) {
    wrapper.appendChild(h('span', { class: 'text-sm text-gray-700' }, props.label))
  }

  return wrapper
}
