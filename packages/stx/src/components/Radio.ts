import { cx } from '../styles'
import { h } from '../component'
import { state, effect } from '../runtime'
import type { State } from '../runtime'

export interface RadioOption {
  value: string
  label: string
  disabled?: boolean
}

export interface RadioProps {
  name: string
  options: RadioOption[]
  selected?: State<string>
  class?: string
  onChange?: (value: string) => void
}

export function Radio(props: RadioProps): HTMLElement {
  const selectedValue = props.selected ?? state(props.options[0]?.value ?? '')

  const group = h('div', {
    class: cx('flex flex-col gap-2', props.class),
    role: 'radiogroup',
  })

  for (const opt of props.options) {
    const label = h('label', {
      class: cx(
        'inline-flex items-center gap-2 cursor-pointer select-none',
        opt.disabled && 'opacity-50 cursor-not-allowed',
      ),
    })

    const input = h('input', {
      type: 'radio',
      name: props.name,
      value: opt.value,
      class: 'h-4 w-4 border-gray-300 text-blue-500 focus:ring-blue-500 focus:ring-2',
      disabled: opt.disabled,
      onChange: () => {
        selectedValue.set(opt.value)
        props.onChange?.(opt.value)
      },
    }) as HTMLInputElement

    effect(() => {
      input.checked = selectedValue() === opt.value
    })

    label.appendChild(input)
    label.appendChild(h('span', { class: 'text-sm text-gray-700' }, opt.label))
    group.appendChild(label)
  }

  return group
}
