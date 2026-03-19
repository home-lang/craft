import { cx } from '../styles'
import { h } from '../component'
import { state, effect } from '../runtime'
import type { State } from '../runtime'

export interface ToggleProps {
  checked?: State<boolean>
  disabled?: boolean
  class?: string
  onChange?: (checked: boolean) => void
}

export function Toggle(props: ToggleProps = {}): HTMLElement {
  const isChecked = props.checked ?? state(false)

  const track = h('div', {
    class: 'relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer',
  })

  const thumb = h('span', {
    class: 'inline-block h-4 w-4 rounded-full bg-white shadow-sm transition-transform',
  })

  track.appendChild(thumb)

  effect(() => {
    if (isChecked()) {
      track.className = cx(
        'relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer bg-blue-500',
        props.disabled && 'opacity-50 cursor-not-allowed',
        props.class,
      )
      thumb.style.transform = 'translateX(20px)'
    }
    else {
      track.className = cx(
        'relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer bg-gray-300',
        props.disabled && 'opacity-50 cursor-not-allowed',
        props.class,
      )
      thumb.style.transform = 'translateX(2px)'
    }
  })

  track.addEventListener('click', () => {
    if (props.disabled) return
    isChecked.update(v => !v)
    props.onChange?.(isChecked())
  })

  return track
}
